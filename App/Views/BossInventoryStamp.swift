import SwiftUI

struct BossInventoryStamp: View {
    let text: String
    var body: some View {
        Text(text).font(.system(size: 9, weight: .heavy, design: .serif)).tracking(0.5)
            .foregroundStyle(GameplaySurface.ink)
            .padding(.horizontal, 4).padding(.vertical, 1)
            .background(GameplaySurface.ivory)
            .overlay(Rectangle().stroke(GameplaySurface.sage, lineWidth: 1.1))
            .rotationEffect(.degrees(-5))
            .padding(.bottom, 1)
            .allowsHitTesting(false)
            .accessibilityLabel("Flat bonus paid this Turn. Other effects stay active.")
    }
}
