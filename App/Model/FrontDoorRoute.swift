import Foundation

/// Which room you are standing in before a Book is open.
///
/// Deliberately not a `NavigationStack`: the game is a physical world, and a
/// navigation bar sliding in over the club room would be the one place it
/// stops being one. Nothing in here knows about the run — the moment a Book is
/// open, `ContentView` stops consulting this at all.
enum FrontDoorRoute: Equatable {
    /// The club room. Where the app opens.
    case mainMenu
    /// The existing shelf, unchanged.
    case bookShelf
    /// The permanent cosmetic shop. Never the in-run counter.
    case cosmeticShop

    /// `-mainMenu`, `-clubShop`, and the existing shelf arguments, which have
    /// to keep landing on the shelf or every QA workflow gains a tap.
    static func launchRoute() -> FrontDoorRoute {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-clubShop") { return .cosmeticShop }
        if arguments.contains("-mainMenu") { return .mainMenu }
        if arguments.contains("-shelfPage") || arguments.contains("-obstacle")
            || arguments.contains("-tapBook") || arguments.contains("-unlockAll") {
            return .bookShelf
        }
        #endif
        return .mainMenu
    }
}
