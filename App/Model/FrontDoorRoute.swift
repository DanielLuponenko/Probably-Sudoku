import Foundation

/// Which room you are standing in before a Book is open.
enum FrontDoorRoute: Equatable {
    /// A brief studio credit before the room becomes interactive.
    case studioIntro
    /// The club room. Where the app opens.
    case mainMenu
    /// The existing shelf, unchanged.
    case bookShelf

    static func launchRoute(arguments: [String] = ProcessInfo.processInfo.arguments) -> FrontDoorRoute {
        #if DEBUG
        if arguments.contains("-mainMenu")
            || arguments.contains("-bookRack")
            || arguments.contains("-tapPlay")
            || arguments.contains("-menuSettings") {
            return .mainMenu
        }
        if arguments.contains("-shelfPage") || arguments.contains("-obstacle")
            || arguments.contains("-tapBook") || arguments.contains("-unlockAll") {
            return .bookShelf
        }
        #endif
        return .studioIntro
    }
}
