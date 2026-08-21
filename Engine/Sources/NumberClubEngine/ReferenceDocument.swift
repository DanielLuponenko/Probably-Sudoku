import Foundation

/// The checked-in rule catalogue. Keeping the rows derived from `Catalog`
/// makes documentation drift a test failure instead of a release surprise.
public enum ReferenceDocument {
    public static func render() -> String {
        var lines = [
            "# Probably Sudoku Reference",
            "",
            "Generated from the NumberClubEngine catalogue. Do not edit by hand.",
            "",
            "## Shop and run items",
            "",
        ]

        for kind in ItemKind.allCases {
            lines.append("### \(heading(for: kind))")
            lines.append("")
            lines.append("| Name | Price | Effect |")
            lines.append("| --- | ---: | --- |")
            for item in Catalog.items(of: kind) {
                lines.append("| \(item.name) | \(item.listedPrice) | \(item.text) |")
            }
            lines.append("")
        }

        lines += [
            "## Bosses",
            "",
            "| Boss | Effect |",
            "| --- | --- |",
        ]
        for boss in BossModifier.allCases {
            lines.append("| \(boss.name) | \(boss.attacks) |")
        }
        lines.append("")
        return lines.joined(separator: "\n")
    }

    private static func heading(for kind: ItemKind) -> String {
        switch kind {
        case .bookmark: "Bookmarks"
        case .marker: "Markers"
        case .buff: "Buffs"
        case .subscription: "Subscriptions"
        }
    }
}
