import XCTest

class UITestRunner {
    let application: XCUIApplication
    var initialLaunchState: XCUIApplication.State = .runningForeground
    var launchTimeout: TimeInterval = 5.0

    init(application: XCUIApplication) {
        self.application = application
    }

    convenience init() {
        self.init(application: XCUIApplication())
    }

    func run(_ steps: TestStep..., file: StaticString = #file, line: UInt = #line) {
        application.launch()

        precondition(
            application.wait(for: initialLaunchState, timeout: launchTimeout),
            "Application did not finish launching within timeout."
        )

        for step in steps {
            XCTContext.runActivity(named: step.description) {
                step.run(application, activity: $0)
            }
        }
    }

    struct TestStep {
        let description: String
        let file: StaticString
        let line: UInt

        private let run: (XCUIApplication, XCTActivity) -> Void

        func run(_ application: XCUIApplication, activity: XCTActivity) {
            run(application, activity)
        }
    }
}

// MARK: Activities

struct UIAppActivity {
    let description: String
    let run: (XCUIApplication) -> Void
}

struct UIScreenActivity<ScreenType: Screen> {
    let description: String
    let run: (ScreenType) -> Void
}

// MARK: Built-in Steps

extension UITestRunner.TestStep {
    /// Performs a general test step, providing access to the entire XCUIApplication instance.
    ///
    /// Where possible, prefer to use higher-level steps that run on specific screens or self-contained activities.
    ///
    /// - Parameters:
    ///     - description: A descriptive name for this step - will be displayed in the Xcode test runner output.
    ///     - work: A closure that performs the interactions for this step. Receives the XCUIApplication instance as its only parameter.
    ///
    static func perform(
        _ description: String,
        file: StaticString = #filePath,
        line: UInt = #line,
        work: @escaping (XCUIApplication, XCTActivity) -> Void
    ) -> Self {
        .init(description: description, file: file, line: line, run: work)
    }

    /// Performs a step on a specific screen.
    ///
    /// This step allows you to perform actions on a specific screen in your app and provides access to just the
    /// screen object representing that screen.
    ///
    /// - Parameters:
    ///     - description: A descriptive name for this step - will be displayed in the Xcode test runner output.
    ///     - onScreen: A ScreenBuilder that returns an instance of the screen you want to interact with.
    ///     - work: A closure that performs the interactions for this step. Receives the instance of your screen built by the screen builder.
    ///
    static func perform<S: Screen>(
        _ description: String,
        onScreen screenBuilder: ScreenBuilder<S>,
        work: @escaping (S) -> Void,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> Self {
        .init(description: description, file: file, line: line) { app, activity in
            let screen = screenBuilder.build(app)
            XCTAssert(
                screen.isVisible,
                "Could not perform step on screen while it isn't visible.",
                file: file,
                line: line
            )
            work(screen)
            let screenshot = XCUIScreen.main.screenshot()
            let attachment = XCTAttachment(screenshot: screenshot)
            activity.add(attachment)
        }
    }

    /// Performs a screen activity.
    ///
    /// Activities are self-contained steps that can be used to provide repeatable and re-usable activities in your tests.
    ///
    /// A screen activity runs on a single screen within your app.
    ///
    /// - Parameters:
    ///     - activity: The activity you want to perform.
    ///     - onScreen: A screen builder that builds the screen the activity should be performed on.
    ///
    static func perform<S: Screen>(
        _ activity: UIScreenActivity<S>,
        onScreen screenBuilder: ScreenBuilder<S>,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> Self {
        .init(description: activity.description, file: file, line: line) {
            let screen = screenBuilder.build($0)
            XCTAssert(
                screen.isVisible,
                "Could not perform activity on screen while it isn't visible.",
                file: file,
                line: line
            )
            activity.run(screen)
            let screenshot = XCUIScreen.main.screenshot()
            let attachment = XCTAttachment(screenshot: screenshot)
            $1.add(attachment)
        }
    }

    static func perform(
        _ activity: UIAppActivity,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> Self {
        .init(description: activity.description, file: file, line: line) {
            activity.run($0)
            let screenshot = XCUIScreen.main.screenshot()
            let attachment = XCTAttachment(screenshot: screenshot)
            $1.add(attachment)
        }
    }

    static func assert<S: Screen>(
        onScreen screenBuilder: ScreenBuilder<S>,
        _ message: String = "",
        predicate: @escaping (S) -> Bool,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> Self {
        .init(description: "Assert: \(message)", file: file, line: line) {
            let screen = screenBuilder.build($0)
            XCTAssert(
                screen.isVisible,
                "Could not perform assertion on screen while it isn't visible.",
                file: file,
                line: line
            )
            XCTAssert(
                predicate(screen),
                message,
                file: file,
                line: line
            )
            let screenshot = XCUIScreen.main.screenshot()
            let attachment = XCTAttachment(screenshot: screenshot)
            $1.add(attachment)
        }
    }

    struct OnScreen<S: Screen> {
        let screen: ScreenBuilder<S>
        var steps: [UITestRunner.TestStep] = []

        mutating func perform(
            _ description: String,
            work: @escaping (S) -> Void,
            file: StaticString = #filePath,
            line: UInt = #line
        ) {
            steps.append(.perform(description, onScreen: screen, work: work, file: file, line: line))
        }

        mutating func perform(
            _ activity: UIScreenActivity<S>,
            file: StaticString = #filePath,
            line: UInt = #line
        ) {
            steps.append(.perform(activity, onScreen: screen, file: file, line: line))
        }
    }

    static func onScreen<S: Screen>(
        _ screenBuilder: ScreenBuilder<S>,
        perform: @escaping (inout OnScreen<S>) -> Void,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> Self {
        .init(description: "On screen: \(screenBuilder.name)", file: file, line: line) { app, activity in
            let screen = screenBuilder.build(app)
            XCTAssert(
                screen.isVisible,
                "Could not perform steps on screen while it isn't visible.",
                file: file,
                line: line
            )
            var onScreen = OnScreen(screen: screenBuilder)
            perform(&onScreen)
            for step in onScreen.steps {
                XCTContext.runActivity(named: step.description) {
                    step.run(app, activity: $0)
                }
            }
            let screenshot = XCUIScreen.main.screenshot()
            let attachment = XCTAttachment(screenshot: screenshot)
            activity.add(attachment)
        }
    }
}
