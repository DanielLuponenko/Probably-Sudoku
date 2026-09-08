import SwiftUI

/// Settings for the app, as opposed to settings for a Book.
///
/// Separate from `SettingsSlip` on purpose: that one is built round a
/// `GameModel` and offers to abandon the run, print its seed and count its
/// coins. None of that exists at the front door, and a settings screen that
/// says "Level 0 of 9" is worse than no settings screen at all.
struct AppSettingsSlip: View {
    var onClose: () -> Void

    var body: some View {
        PaperSlip(title: "Settings",
                  subtitle: nil,
                  maximumWidth: 540, maximumHeight: 740,
                  onClose: onClose) {
            SettingsCommonContent()
        }
    }
}

/// The theme chooser belongs at the front door: it changes the next Book, not
/// the one currently being played. Each sample is the real paper treatment,
/// so stock, ownership and selection can be judged without entering a run.
private struct PaperThemePicker: View {
    var onOpenShop: () -> Void

    @Environment(PlayerProfileStore.self) private var profile

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 10) {
                ForEach(CosmeticCatalog.items(in: .paper)) { item in
                    PaperThemeOption(item: item,
                                     owned: profile.owns(item),
                                     selected: profile.isEquipped(item),
                                     onChoose: {
                                         if profile.owns(item) {
                                             profile.equip(item)
                                         } else {
                                             onOpenShop()
                                         }
                                     })
                }
            }
            .padding(.vertical, 2)
        }
    }
}

private struct PaperThemeOption: View {
    let item: CosmeticItem
    let owned: Bool
    let selected: Bool
    let onChoose: () -> Void

    var body: some View {
        Button(action: onChoose) {
            VStack(alignment: .leading, spacing: 5) {
                CosmeticPreview(item: item, side: 72)
                    .overlay(alignment: .topTrailing) {
                        if !owned {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Paper.page)
                                .padding(5)
                                .background(Paper.ink.opacity(0.78), in: Circle())
                                .padding(4)
                        }
                    }
                Text(item.name)
                    .font(Print.caption(10.5))
                    .foregroundStyle(Paper.ink)
                    .lineLimit(1)
                Text(owned ? (selected ? "Using" : "Owned") : "\(item.price) Stamps")
                    .font(Print.caption(9.5))
                    .foregroundStyle(selected ? Paper.sageDeep : Paper.inkFaint)
            }
            .frame(width: 72, alignment: .leading)
            .padding(4)
            .background(selected ? Paper.sage.opacity(0.13) : .clear,
                        in: RoundedRectangle(cornerRadius: 5))
            .overlay {
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(selected ? Paper.sageDeep : Paper.rule.opacity(0.55),
                                  lineWidth: selected ? 1.5 : 1)
            }
        }
        .buttonStyle(PressedPaperStyle())
        .accessibilityLabel(item.name)
        .accessibilityValue(selected ? "Equipped" : owned ? "Owned" : "Locked, \(item.price) Stamps")
        .accessibilityHint(owned ? "Double tap to equip for the next Book." : "Double tap to open the Club Shop.")
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}
/// A printed checkbox with a pencil tick in it. A system `Toggle` here would
/// be the one iOS control in a room made of wood and paper.
struct SlipToggle: View {
    @Environment(\.cosmeticTheme) private var theme
    @ScaledMetric(relativeTo: .body) private var textScale = 1.0
    var label: String
    var note: String?
    @Binding var isOn: Bool

    var body: some View {
        Button {
            isOn.toggle()
            if isOn { Haptics.menuOpen() }
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 11) {
                box
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(Print.body(14 * textScale))
                        .foregroundStyle(theme.paper.ink)
                    if let note {
                        Text(note)
                            .font(Print.body(11.5 * textScale))
                            .foregroundStyle(theme.paper.softInk)
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.leading)
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(minHeight: 44, alignment: .center)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressedPaperStyle())
        .accessibilityLabel(label)
        .accessibilityValue(isOn ? "On" : "Off")
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
    }

    private var box: some View {
        RoundedRectangle(cornerRadius: 2)
            .strokeBorder(theme.paper.ruleInk, lineWidth: 1.2)
            .background(RoundedRectangle(cornerRadius: 2).fill(theme.paper.warm))
            .frame(width: 20, height: 20)
            .overlay {
                if isOn {
                    Tick()
                        .stroke(Paper.sageDeep,
                                style: StrokeStyle(lineWidth: 2.4, lineCap: .round,
                                                   lineJoin: .round))
                        .padding(4)
                }
            }
            .offset(y: 2)
    }
}

/// A tick, drawn the way one is drawn: down, then up and out past the box.
private struct Tick: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.36, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX + rect.width * 0.14, y: rect.minY - rect.height * 0.2))
        return path
    }
}
