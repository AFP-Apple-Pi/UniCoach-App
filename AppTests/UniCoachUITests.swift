import XCTest

final class UniCoachUITests: XCTestCase {
    func testSyntheticOfflineFlow() throws {
        let app = XCUIApplication()
        app.launchArguments.append("-ui-smoke")
        app.launch()
        XCTAssertTrue(app.buttons["profile.save"].waitForExistence(timeout: 10))
        app.buttons["profile.save"].tap()
        XCTAssertTrue(app.buttons["subjects.sample"].waitForExistence(timeout: 5))
        app.buttons["subjects.sample"].tap()
        app.staticTexts["Example subject"].tap()
        app.staticTexts["Example assignment"].tap()
        for heading in ["Your approach", "Tutor feedback", "AI analysis", "Subject overview"] {
            let item = app.staticTexts[heading]
            if !item.isHittable { app.swipeUp() }
            XCTAssertTrue(item.waitForExistence(timeout: 5), "Missing \(heading)")
        }
        let mentor = app.buttons["Open mentor"]
        if !mentor.isHittable { app.swipeDown() }
        mentor.tap()
        let source = app.switches["Assignment brief"]
        XCTAssertTrue(source.waitForExistence(timeout: 5))
        XCTAssertEqual(source.value as? String, "0", "Sources must start unselected")
        let nestedSwitch = source.switches.firstMatch
        if nestedSwitch.exists {
            nestedSwitch.tap()
        } else {
            source.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        }
        let selected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "1"), object: source)
        guard XCTWaiter.wait(for: [selected], timeout: 5) == .completed else {
            XCTFail("The selected source did not turn on. UI: \(app.debugDescription)")
            return
        }
        XCTAssertTrue(app.textViews["Approved text for Assignment brief"].waitForExistence(timeout: 5), "Selected source must appear for review")
        app.swipeUp()
        app.buttons["mentor.engine"].tap()
        app.buttons["Contextual offline (not AI)"].tap()
        XCTAssertEqual(source.value as? String, "1", "Choosing an engine must preserve the selected source")
        let approve = app.buttons["mentor.approve"]
        let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: approve)
        guard XCTWaiter.wait(for: [enabled], timeout: 5) == .completed else {
            XCTFail("Approval must be enabled after selecting a source and engine. UI: \(app.debugDescription)")
            return
        }
        approve.tap()
        let savedReport = app.buttons["mentor.savedReport"]
        guard savedReport.waitForExistence(timeout: 10) else {
            XCTFail("Report was not saved. UI: \(app.debugDescription)")
            return
        }
        savedReport.tap()
        XCTAssertTrue(app.staticTexts["Contextual offline (not AI)"].waitForExistence(timeout: 5))
    }
}
