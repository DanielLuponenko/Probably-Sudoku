import Foundation

public extension Game {
    /// A reorder is one inventory mutation. A scoring batch already in progress
    /// retains its own ordered snapshot; this updates the order for the next one.
    @discardableResult
    mutating func reorderBookmark(id: UUID, to destination: Int) -> Bool {
        guard run.pendingItemDecisions.isEmpty,
              !(run.shop == nil && run.puzzle?.boss == .bindery && run.puzzle?.bossState.scoring.binderyPinned == true
                && run.puzzle?.phase != .won && run.puzzle?.phase != .failed),
              run.bookmarks.indices.contains(destination),
              let origin = run.bookmarks.firstIndex(where: { $0.id == id }),
              origin != destination else { return false }
        let sleepingID = run.puzzle?.disabledBookmark.flatMap { index in
            run.bookmarks.indices.contains(index) ? run.bookmarks[index].id : nil
        }
        let owned = run.bookmarks.remove(at: origin)
        run.bookmarks.insert(owned, at: destination)
        if let sleepingID {
            run.puzzle?.bossTurn?.disabledBookmark = run.bookmarks.firstIndex { $0.id == sleepingID }
        }
        return true
    }
}
