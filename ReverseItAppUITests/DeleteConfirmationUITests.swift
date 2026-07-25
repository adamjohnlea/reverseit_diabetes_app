import XCTest

final class DeleteConfirmationUITests: XCTestCase {
    @MainActor
    func testSwipeToDeleteRequiresConfirmation() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest-seeded"]
        app.launch()

        app.tabBars.buttons["Glucose"].tap()

        // The seeded reading is the only "Fasting" row; the value text alone is
        // ambiguous because the Statistics section repeats it.
        let readingCell = app.cells.containing(.staticText, identifier: "Fasting").firstMatch
        XCTAssertTrue(readingCell.waitForExistence(timeout: 5))

        let dialogTitle = app.staticTexts["Delete this glucose reading?"]

        // Dismissing the confirmation keeps the reading. On current iOS the
        // dialog adapts to a popover without a Cancel button; cancelling is
        // tapping outside it.
        presentDeleteConfirmation(cell: readingCell, dialogTitle: dialogTitle, in: app)
        if app.buttons["Cancel"].exists {
            app.buttons["Cancel"].tap()
        } else {
            app.otherElements["PopoverDismissRegion"].tap()
        }
        XCTAssertTrue(dialogTitle.waitForNonExistence(timeout: 3))
        XCTAssertTrue(readingCell.exists)

        // Confirming deletes it.
        presentDeleteConfirmation(cell: readingCell, dialogTitle: dialogTitle, in: app)
        app.sheets.buttons["Delete"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Fasting"].waitForNonExistence(timeout: 5))
    }

    /// Swipes the cell and ensures the confirmation dialog is on screen.
    /// A full swipe triggers the destructive action (and therefore the dialog)
    /// directly; a partial swipe reveals the action button to tap first.
    @MainActor
    private func presentDeleteConfirmation(cell: XCUIElement, dialogTitle: XCUIElement, in app: XCUIApplication) {
        cell.swipeLeft()
        if !dialogTitle.waitForExistence(timeout: 2) {
            app.buttons["Delete"].firstMatch.tap()
            XCTAssertTrue(dialogTitle.waitForExistence(timeout: 3))
        }
    }
}
