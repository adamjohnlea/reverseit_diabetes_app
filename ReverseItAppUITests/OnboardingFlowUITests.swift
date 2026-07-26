import XCTest

final class OnboardingFlowUITests: XCTestCase {
    @MainActor
    func testFreshLaunchWalksThroughProfileCreation() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest-reset"]
        app.launch()

        // Welcome page
        XCTAssertTrue(app.staticTexts["Welcome to ManageIt!"].waitForExistence(timeout: 5))
        app.buttons["Get Started"].tap()

        // Profile page
        let nameField = app.textFields["Name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 5))
        nameField.tap()
        nameField.typeText("Alex")

        let ageField = app.textFields["Age"]
        ageField.tap()
        ageField.typeText("45")

        let weightField = app.textFields["Weight (kg)"]
        weightField.tap()
        weightField.typeText("80")

        let heightField = app.textFields["Height (cm)"]
        heightField.tap()
        heightField.typeText("175")

        // Dismiss the number-pad keyboard, which covers the button.
        app.buttons["Done"].tap()

        let continueButton = app.buttons["Continue"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 3))
        XCTAssertTrue(continueButton.isEnabled)
        continueButton.tap()

        // Health access page: reaching it proves the profile was created and saved.
        XCTAssertTrue(app.staticTexts["Health Data Access"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testSeededLaunchSkipsOnboarding() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest-seeded"]
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["Dashboard"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["Glucose"].exists)
    }
}
