import XCTest

// MARK: Screen

extension Screens {
    struct Todos: Screen {
        let app: XCUIApplication

        var isVisible: Bool {
            app.navigationBars.firstMatch.staticTexts["Todos"].exists
        }

        var addTodoButton: XCUIElement {
            app.buttons["Add Todo"]
        }

        var clearCompletedButton: XCUIElement {
            app.buttons["Clear Completed"]
        }

        var newTodoItem: TodoItem {
            TodoItem(
                element: app.otherElements
                    .matching(identifier: "todo-item")
                    .containing(.init(format: "placeholderValue == 'Untitled Todo'"))
                    .firstMatch
            )
        }

        var numberOfTodos: Int {
            app.otherElements
                .matching(identifier: "todo-item")
                .count
        }

        func selectFilter(_ filter: Filter) {
            app.buttons[filter.rawValue].tap()
        }

        func todoItem(_ text: String) -> TodoItem {
            TodoItem(
                element: app.otherElements
                    .matching(identifier: "todo-item")
                    .containing(.init(format: "value == '\(text)'"))
                    .firstMatch
            )
        }

        enum Filter: String {
            case all = "All"
            case active = "Active"
            case completed = "Completed"
        }

        struct TodoItem: Component {
            let element: XCUIElement

            var checkbox: XCUIElement {
                element.buttons["checkbox"]
            }

            var input: XCUIElement {
                element.textFields.firstMatch
            }

            var value: String? {
                input.value as? String
            }

            func enterText(_ text: String) {
                input.tap()
                input.typeText(text)
            }
        }
    }
}

extension ScreenBuilder {
    static var todos: ScreenBuilder<Screens.Todos> {
        .init(name: "Todos") { Screens.Todos(app: $0) }
    }
}

// MARK: Activities

extension UIScreenActivity where ScreenType == Screens.Todos {
    static func addTodoItem(
        _ title: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> UIScreenActivity {
        .init(description: "Entering todo item '\(title)'") {
            $0.addTodoButton.tap()
            $0.newTodoItem.enterText(title)
            $0.tapEnterKey()
            XCTAssert($0.todoItem(title).exists,
                "Expected todo item '\(title)' to exist",
                file: file,
                line: line
            )
        }
    }

    static func completeTodoItem(
        _ title: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> UIScreenActivity {
        .init(description: "Completing todo item '\(title)'") {
            XCTAssert($0.todoItem(title).exists,
                "Todo item '\(title)' does not exist",
                file: file,
                line: line
            )
            $0.todoItem(title).checkbox.tap()
        }
    }
}
