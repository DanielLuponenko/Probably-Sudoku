import MetalKit
import OSLog
@preconcurrency import QuartzCore
import SwiftUI

/// Capture a displayed page once; only its mesh and uniforms change during a turn.
@MainActor
final class PageCurlRenderer: NSObject, MTKViewDelegate {
    static let renderMargin: CGFloat = 24
    private static let log = Logger(subsystem: "com.numberclub.app", category: "PageCurl")

    private struct Uniforms {
        var size: SIMD4<Float>       // page width/height, canvas width/height
        var motion: SIMD4<Float>     // progress, margin, shadow pass, unused
        var shadow: SIMD4<Float>     // screen offset x/y, opacity, unused
        var stock = SIMD4<Float>(0.91, 0.887, 0.831, 1)
    }

    private enum Phase { case idle, priming, awaitingFirst, turning, held, awaitingLast }
    private let device: MTLDevice
    private let queue: MTLCommandQueue
    private let leafPipeline: MTLRenderPipelineState
    private let shadowPipeline: MTLRenderPipelineState
    private let depthState: MTLDepthStencilState
    private let shadowDepthState: MTLDepthStencilState
    private let vertices: MTLBuffer
    private let indices: MTLBuffer
    private let uniformBuffers: [MTLBuffer]
    private static let uniformPassStride = 256
    private var nextUniformSlot = 0
    private let indexCount: Int
    private let sampleCount: Int
    private let inFlight = DispatchSemaphore(value: 2)
    private weak var view: MTKView?
    private var texture: MTLTexture?
    private var pageSize = CGSize.zero
    private var renderScale: CGFloat = 2
    private var phase = Phase.idle
    private var progress: Float = 0
    private var duration: TimeInterval = 0.64
    private var startedAt: CFTimeInterval?
    private var expiresAt: CFTimeInterval?
    private var heldProgress: Double?
    private var displayLink: CADisplayLink?
    private var firstFrame: (@MainActor () -> Void)?
    private var completion: (@MainActor () -> Void)?
    private var generation = UUID()
    #if targetEnvironment(simulator)
    private var pendingPresentation: (token: UUID, first: Bool, time: CFTimeInterval)?
    #endif

    static func make() -> PageCurlRenderer? {
        do { return try PageCurlRenderer(preparing: ()) }
        catch {
            log.error("Metal renderer preparation failed: \(String(describing: error), privacy: .public)")
            return nil
        }
    }

    private init(preparing: Void) throws {
        guard let device = MTLCreateSystemDefaultDevice(),
              let queue = device.makeCommandQueue(),
              let library = device.makeDefaultLibrary(),
              let vertex = library.makeFunction(name: "pageLeafVertex"),
              let front = library.makeFunction(name: "pageLeafFragment"),
              let shadow = library.makeFunction(name: "pageShadowFragment") else {
            throw CocoaError(.featureUnsupported)
        }
        self.device = device
        self.queue = queue
        let samples = device.supportsTextureSampleCount(4) ? 4 : 1
        sampleCount = samples
        func pipeline(_ fragment: MTLFunction, blended: Bool) throws -> MTLRenderPipelineState {
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = vertex
            descriptor.fragmentFunction = fragment
            descriptor.rasterSampleCount = samples
            descriptor.depthAttachmentPixelFormat = .depth32Float
            let colour = descriptor.colorAttachments[0]!
            colour.pixelFormat = .bgra8Unorm_srgb
            colour.isBlendingEnabled = blended
            colour.sourceRGBBlendFactor = .one
            colour.destinationRGBBlendFactor = .oneMinusSourceAlpha
            colour.sourceAlphaBlendFactor = .one
            colour.destinationAlphaBlendFactor = .oneMinusSourceAlpha
            return try device.makeRenderPipelineState(descriptor: descriptor)
        }
        leafPipeline = try pipeline(front, blended: false)
        shadowPipeline = try pipeline(shadow, blended: true)
        let depth = MTLDepthStencilDescriptor()
        depth.depthCompareFunction = .lessEqual
        depth.isDepthWriteEnabled = true
        guard let depthState = device.makeDepthStencilState(descriptor: depth) else {
            throw CocoaError(.featureUnsupported)
        }
        self.depthState = depthState
        let shadowDepth = MTLDepthStencilDescriptor()
        shadowDepth.depthCompareFunction = .always
        shadowDepth.isDepthWriteEnabled = false
        guard let shadowDepthState = device.makeDepthStencilState(descriptor: shadowDepth) else {
            throw CocoaError(.featureUnsupported)
        }
        self.shadowDepthState = shadowDepthState

        let columns = 96, rows = 64
        var points: [SIMD2<Float>] = []
        var triangles: [UInt16] = []
        for row in 0...rows {
            for column in 0...columns {
                points.append(SIMD2(Float(column) / Float(columns), Float(row) / Float(rows)))
            }
        }
        for row in 0..<rows {
            for column in 0..<columns {
                let a = UInt16(row * (columns + 1) + column)
                let b = a + 1, c = a + UInt16(columns + 1), d = c + 1
                triangles.append(contentsOf: [a, b, c, b, d, c])
            }
        }
        guard let vertices = device.makeBuffer(bytes: points,
                length: points.count * MemoryLayout<SIMD2<Float>>.stride),
              let indices = device.makeBuffer(bytes: triangles,
                length: triangles.count * MemoryLayout<UInt16>.stride) else {
            throw CocoaError(.featureUnsupported)
        }
        self.vertices = vertices
        self.indices = indices
        indexCount = triangles.count
        var ring: [MTLBuffer] = []
        for slot in 0..<3 {
            guard let buffer = device.makeBuffer(length: Self.uniformPassStride * 8,
                                                  options: .storageModeShared) else {
                throw CocoaError(.featureUnsupported)
            }
            buffer.label = "Page turn uniforms \(slot)"
            ring.append(buffer)
        }
        uniformBuffers = ring
        super.init()
    }

    /// Resource preparation precedes all model changes and animation timing.
    func prepare(image: CGImage, pageSize: CGSize, scale: CGFloat) -> Bool {
        guard pageSize.width > 1, pageSize.height > 1,
              let view, view.window != nil, view.bounds.width > 1 else {
            Self.log.error("Leaf preparation has no attached canvas: page=\(String(describing: pageSize), privacy: .public), canvas=\(String(describing: self.view?.bounds), privacy: .public), window=\(self.view?.window != nil)")
            return false
        }
        cancel()
        do {
            texture = try makeFrontTexture(image)
            self.pageSize = pageSize
            renderScale = min(max(scale, 1), 2)
            updateDrawableSize(view)
            Self.log.notice("Leaf prepared: pixels=\(image.width)x\(image.height), canvas=\(String(describing: view.bounds), privacy: .public)")
            return true
        } catch {
            Self.log.error("Leaf texture upload failed: \(String(describing: error), privacy: .public)")
            texture = nil
            return false
        }
    }

    /// Normalize explicitly instead of asking MTKTextureLoader to infer a pixel
    /// format from UIKit's potentially wide-colour/HDR bitmap representation.
    /// This upload finishes before the animation clock starts.
    private func makeFrontTexture(_ image: CGImage) throws -> MTLTexture {
        let width = image.width, height = image.height
        let rowBytes = (width * 4 + 255) & ~255
        guard width > 0, height > 0,
              let space = CGColorSpace(name: CGColorSpace.sRGB),
              let bitmap = CGContext(data: nil, width: width, height: height,
                    bitsPerComponent: 8, bytesPerRow: rowBytes, space: space,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                        | CGBitmapInfo.byteOrder32Big.rawValue),
              let pixels = bitmap.data else { throw CocoaError(.coderInvalidValue) }
        bitmap.setBlendMode(.copy)
        bitmap.interpolationQuality = .none
        bitmap.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm_srgb, width: width, height: height, mipmapped: false)
        descriptor.storageMode = .shared
        descriptor.usage = .shaderRead
        guard let result = device.makeTexture(descriptor: descriptor) else {
            throw CocoaError(.featureUnsupported)
        }
        result.label = "Captured page front: RGBA8 sRGB"
        result.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0,
                       withBytes: pixels, bytesPerRow: rowBytes)
        return result
    }

    func attach(to view: MTKView) {
        Self.log.notice("Canvas attached: \(String(describing: ObjectIdentifier(view)), privacy: .public)")
        self.view = view
        view.device = device
        view.delegate = self
        view.colorPixelFormat = .bgra8Unorm_srgb
        view.depthStencilPixelFormat = .depth32Float
        view.sampleCount = sampleCount
        view.clearColor = MTLClearColorMake(0, 0, 0, 0)
        view.clearDepth = 1
        view.isOpaque = false
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        view.isHidden = true
        view.isPaused = true
        view.enableSetNeedsDisplay = false
        view.autoResizeDrawable = false
        updateDrawableSize(view)
    }

    func detach(from view: MTKView) {
        Self.log.notice("Canvas dismantled: \(String(describing: ObjectIdentifier(view)), privacy: .public), current=\(self.view === view)")
        if self.view === view {
            cancel()
            self.view = nil
        }
        view.delegate = nil
    }

    /// Present the flat captured frame before changing the page underneath it.
    func start(duration: TimeInterval, heldProgress: Double? = nil,
               onFirstFrame: @escaping @MainActor () -> Void = {},
               completion: @escaping @MainActor () -> Void) {
        guard texture != nil, view != nil else { onFirstFrame(); completion(); return }
        generation = UUID()
        self.duration = max(duration, 0.2)
        self.heldProgress = heldProgress.map { min(max($0, 0), 1) }
        firstFrame = onFirstFrame
        self.completion = completion
        startedAt = nil
        expiresAt = CACurrentMediaTime() + self.duration + 2
        progress = 0
        phase = .priming
        displayLink?.invalidate()
        let link = CADisplayLink(target: self, selector: #selector(displayTick(_:)))
        link.preferredFramesPerSecond = 60
        link.add(to: .main, forMode: .common)
        displayLink = link
        view?.draw()
    }

    func cancel() {
        Self.log.notice("Canvas cancel: phase=\(String(describing: self.phase), privacy: .public)")
        generation = UUID()
        displayLink?.invalidate()
        displayLink = nil
        phase = .idle
        texture = nil
        firstFrame = nil
        completion = nil
        startedAt = nil
        expiresAt = nil
        // Cancellation must work even with no drawable or a full GPU queue.
        view?.isHidden = true
        #if targetEnvironment(simulator)
        pendingPresentation = nil
        #endif
    }

    @objc private func displayTick(_ link: CADisplayLink) {
        // A missing drawable/presentation callback must not leave navigation
        // locked forever. Normal progress still comes only from display time.
        if let expiresAt, link.timestamp > expiresAt {
            Self.log.error("Page turn presentation timed out")
            failedFrame(token: generation)
            return
        }
        #if targetEnvironment(simulator)
        // The Simulator SDK has no drawable-presented callback. A GPU-complete
        // frame plus a following display timestamp is the available boundary.
        if let pending = pendingPresentation, link.timestamp >= pending.time {
            pendingPresentation = nil
            didPresent(token: pending.token, first: pending.first)
        }
        #endif
        if phase == .priming { view?.draw(); return }
        guard phase == .turning else { return }
        if startedAt == nil { startedAt = link.targetTimestamp }
        let elapsed = max(0, link.targetTimestamp - (startedAt ?? link.targetTimestamp))
        let time = Float(min(elapsed / duration, 1))
        // Smooth endpoints, with travel distributed through the whole turn.
        progress = time * time * (3 - 2 * time)
        view?.draw()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        updateDrawableSize(view)
        guard inFlight.wait(timeout: .now()) == .success else { return }
        guard let descriptor = view.currentRenderPassDescriptor,
              let drawable = view.currentDrawable,
              let command = queue.makeCommandBuffer(),
              let encoder = command.makeRenderCommandEncoder(descriptor: descriptor) else {
            inFlight.signal()
            return
        }
        // Three persistent slots and at most two queued commands keep CPU
        // writes away from uniforms still in use by this serial GPU queue.
        let uniformBuffer = uniformBuffers[nextUniformSlot]
        nextUniformSlot = (nextUniformSlot + 1) % uniformBuffers.count
        let token = generation
        let isFirst = phase == .priming
        let isLast = phase == .turning && progress >= 1
        if phase != .idle, let texture {
            var uniforms = Uniforms(
                size: SIMD4(Float(pageSize.width), Float(pageSize.height),
                            Float(pageSize.width + 2 * Self.renderMargin),
                            Float(pageSize.height + 2 * Self.renderMargin)),
                motion: SIMD4(progress, Float(Self.renderMargin), 1, 0),
                shadow: SIMD4(0, 0, 0.045, 0))
            encoder.setVertexBuffer(vertices, offset: 0, index: 0)
            encoder.setFragmentTexture(texture, index: 0)
            encoder.setCullMode(.none)
            encoder.setFrontFacing(.clockwise)
            // Distributed silhouette samples soften the height-dependent shadow.
            encoder.setRenderPipelineState(shadowPipeline)
            encoder.setDepthStencilState(shadowDepthState)
            for sample in 0..<7 {
                let angle = Float(sample) * .pi / 3
                let spread: Float = sample == 0 ? 0 : 3
                uniforms.shadow.x = cos(angle) * spread
                uniforms.shadow.y = sin(angle) * spread
                setUniforms(&uniforms, buffer: uniformBuffer, pass: sample, encoder: encoder)
                drawMesh(encoder)
            }
            uniforms.motion.z = 0
            encoder.setRenderPipelineState(leafPipeline)
            encoder.setDepthStencilState(depthState)
            setUniforms(&uniforms, buffer: uniformBuffer, pass: 7, encoder: encoder)
            drawMesh(encoder)
        }
        encoder.endEncoding()
        if isFirst || isLast {
            if isFirst { phase = .awaitingFirst }
            if isLast { phase = .awaitingLast }
            #if !targetEnvironment(simulator)
            drawable.addPresentedHandler { [weak self] _ in
                Task { @MainActor in self?.didPresent(token: token, first: isFirst) }
            }
            #endif
        }
        let gate = inFlight
        command.addCompletedHandler { [weak self] completed in
            gate.signal()
            if completed.status == .error {
                let failure = String(describing: completed.error)
                Task { @MainActor in
                    Self.log.error("Leaf GPU command failed: \(failure, privacy: .public)")
                    self?.failedFrame(token: token)
                }
            } else if isFirst {
                Task { @MainActor in self?.presentPrepared(drawable, token: token) }
            } else if isLast {
                #if targetEnvironment(simulator)
                Task { @MainActor in
                    guard let self, self.generation == token else { return }
                    self.pendingPresentation = (token, false, CACurrentMediaTime())
                }
                #endif
            }
        }
        if !isFirst { command.present(drawable) }
        command.commit()
    }

    private func presentPrepared(_ drawable: CAMetalDrawable, token: UUID) {
        guard token == generation, phase == .awaitingFirst, let view else { return }
        Self.log.notice("Flat leaf rendered: hidden=\(view.isHidden), bounds=\(String(describing: view.bounds), privacy: .public)")
        // The fresh drawable is fully rendered before the layer can become
        // visible, preventing an old cancelled frame from flashing on restart.
        drawable.layer.presentsWithTransaction = true
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        view.isHidden = false
        drawable.present()
        CATransaction.commit()
        #if targetEnvironment(simulator)
        pendingPresentation = (token, true, CACurrentMediaTime())
        #endif
    }

    private func didPresent(token: UUID, first: Bool) {
        guard token == generation else { return }
        Self.log.notice("Leaf boundary: first=\(first), hidden=\(self.view?.isHidden ?? true), phase=\(String(describing: self.phase), privacy: .public)")
        if first {
            (view?.layer as? CAMetalLayer)?.presentsWithTransaction = false
            let ready = firstFrame
            firstFrame = nil
            ready?()
            guard token == generation else { return }
            if let heldProgress {
                progress = Float(heldProgress)
                phase = .held
                Self.log.notice("Drawing held leaf at \(heldProgress), canvas=\(String(describing: self.view?.bounds), privacy: .public), hidden=\(self.view?.isHidden ?? true)")
                displayLink?.invalidate()
                displayLink = nil
                view?.draw()
            } else {
                phase = .turning
            }
        } else {
            let finished = completion
            cancel()
            finished?()
        }
    }

    private func failedFrame(token: UUID) {
        guard token == generation else { return }
        let ready = firstFrame, finished = completion
        cancel()
        ready?()
        finished?()
    }

    private func updateDrawableSize(_ view: MTKView) {
        let width = pageSize.width > 0 ? pageSize.width + 2 * Self.renderMargin : view.bounds.width
        let height = pageSize.height > 0 ? pageSize.height + 2 * Self.renderMargin : view.bounds.height
        let size = CGSize(width: max(1, width * renderScale), height: max(1, height * renderScale))
        if view.drawableSize != size { view.drawableSize = size }
    }

    private func setUniforms(_ value: inout Uniforms, buffer: MTLBuffer, pass: Int,
                             encoder: MTLRenderCommandEncoder) {
        let offset = pass * Self.uniformPassStride
        withUnsafeBytes(of: &value) { bytes in
            buffer.contents().advanced(by: offset)
                .copyMemory(from: bytes.baseAddress!, byteCount: bytes.count)
        }
        encoder.setVertexBuffer(buffer, offset: offset, index: 1)
        encoder.setFragmentBuffer(buffer, offset: offset, index: 1)
    }

    private func drawMesh(_ encoder: MTLRenderCommandEncoder) {
        encoder.drawIndexedPrimitives(type: .triangle, indexCount: indexCount,
                                      indexType: .uint16, indexBuffer: indices, indexBufferOffset: 0)
    }
}

/// Keep mounted over the physical page, expanded by renderMargin on every side.
struct PageCurlCanvas: UIViewRepresentable {
    let renderer: PageCurlRenderer
    func makeUIView(context: Context) -> MTKView {
        let view = MTKView(frame: .zero)
        renderer.attach(to: view)
        return view
    }
    func updateUIView(_ uiView: MTKView, context: Context) {}
    static func dismantleUIView(_ uiView: MTKView, coordinator: ()) {
        (uiView.delegate as? PageCurlRenderer)?.detach(from: uiView)
    }
}
