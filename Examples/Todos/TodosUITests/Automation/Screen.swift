import XCTest

// MARK: Screen Interface

protocol Screen {
    var app: XCUIApplication { get }
    var isVisible: Bool { get }
}

// MARK: Screen Building

struct ScreenBuilder<ScreenType: Screen> {
    let name: String
    let build: (XCUIApplication) -> ScreenType
}

// MARK: Components

protocol Component {
    var element: XCUIElement { get }
}

extension Component {
    var exists: Bool {
        element.exists
    }
}

// MARK: Common Queries and Commands

extension Screen {
    func tapEnterKey() {
        app.keyboards.firstMatch.buttons["return"].tap()
    }
}
