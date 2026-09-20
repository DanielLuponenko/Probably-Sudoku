import Foundation

/// The checked-in rule catalogue. Keeping the rows derived from `Catalog`
/// makes documentation drift a test failure instead of a release surprise.
public enum ReferenceDocument {
    public static func render() -> String {
        var lines = [
            "# Probably Sudoku Reference",
            "",
            "Generated from the ProbablySudokuEngine catalogue. Do not edit by hand.",
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
            "New Books use 22 active encounters: 16 regular bosses and 6 final bosses. Encounter history prevents repeats while unused eligible bosses remain and avoids consecutive mechanical families when possible. Bosses requiring Markers or triggered Bookmarks appear only when that build can interact with them.",
            "",
            "Previously saved Books retain the original 39-boss selection pool. Saved announcements and active encounters keep their exact identity and rules. Retired bosses remain available for legacy saves and QA replays.",
            "",
            "| Boss | Stage | Rule | Attacks |",
            "| --- | --- | --- | --- |",
        ]
        for boss in BossModifier.activeBosses + BossModifier.allCases.filter({ !$0.isActiveEncounter }) {
            let stage = !boss.isActiveEncounter ? "Legacy saves / QA only"
                : boss.isFinalBoss ? "Level 9, Puzzle 3 only" : "Levels 1–8, Puzzle 3"
            lines.append("| \(boss.name) | \(stage) | \(boss.text) | \(boss.attacks) |")
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
