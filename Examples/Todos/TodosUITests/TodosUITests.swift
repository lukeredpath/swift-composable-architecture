//
//  TodosUITests.swift
//  TodosUITests
//
//  Created by Luke Redpath on 18/01/2021.
//  Copyright © 2021 Point-Free. All rights reserved.
//

import XCTest

class TodosUITests: XCTestCase {
    var testRunner = UITestRunner()

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testAddingAndCompletingTodo() throws {
        testRunner.run(
            .perform(.addTodoItem("This is a todo"), onScreen: .todos),
            .perform(.completeTodoItem("This is a todo"), onScreen: .todos),
            .perform("Check completed todos", onScreen: .todos) {
                $0.selectFilter(.completed)
                XCTAssert($0.todoItem("This is a todo").exists)
            }
        )
    }

    func testClearingCompletedTodos() {
        testRunner.run(
            .onScreen(.todos) {
                $0.perform(.addTodoItem("Todo One"))
                $0.perform(.addTodoItem("Todo Two"))
                $0.perform(.addTodoItem("Todo Three"))
                $0.perform(.completeTodoItem("Todo One"))
                $0.perform(.completeTodoItem("Todo Two"))
                $0.perform("Clear completed todos") {
                    $0.selectFilter(.completed)
                    XCTAssertEqual(2, $0.numberOfTodos)

                    $0.clearCompletedButton.tap()
                    XCTAssertEqual(0, $0.numberOfTodos)
                }
            }
        )
    }
}
