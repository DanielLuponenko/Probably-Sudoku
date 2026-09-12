import Foundation

/// Player-safe failure text, with the original error kept separately for diagnostics.
/// This type does not import or start an ad SDK, so consent failures can use it too.
struct RewardedAdFailure: LocalizedError {
    enum Kind: Equatable {
        case network
        case timeout
        case noFill
        case other
    }

    let kind: Kind
    let underlyingError: any Error
    let playerMessage: String

    var errorDescription: String? { playerMessage }

    init(kind: Kind, underlyingError: any Error,
         fallback: String = "The video could not load. Try again.") {
        self.kind = kind
        self.underlyingError = underlyingError
        switch kind {
        case .network:
            playerMessage = "Check your internet connection and try again."
        case .timeout:
            playerMessage = "The request took too long. Try again."
        case .noFill:
            playerMessage = "No video is available right now. Try again later."
        case .other:
            playerMessage = fallback
        }
    }

    static func classify(_ error: any Error, fallback: String) -> RewardedAdFailure {
        if let failure = error as? RewardedAdFailure { return failure }
        let failure = error as NSError
        // Numeric error codes are meaningful only inside their owning domain.
        guard failure.domain == NSURLErrorDomain else {
            return RewardedAdFailure(kind: .other, underlyingError: error, fallback: fallback)
        }
        let kind: Kind
        switch failure.code {
        case NSURLErrorTimedOut:
            kind = .timeout
        case NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost,
             NSURLErrorCannotFindHost, NSURLErrorCannotConnectToHost,
             NSURLErrorDNSLookupFailed, NSURLErrorInternationalRoamingOff,
             NSURLErrorCallIsActive, NSURLErrorDataNotAllowed:
            kind = .network
        default:
            kind = .other
        }
        return RewardedAdFailure(kind: kind, underlyingError: error, fallback: fallback)
    }
}
