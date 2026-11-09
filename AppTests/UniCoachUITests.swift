import XCTest

final class UniCoachUITests: XCTestCase {
  func testSyntheticOfflineFlow() throws {
    let app = XCUIApplication()
    app.launchArguments.append("-ui-smoke")
    app.launch()
    XCTAssertTrue(app.buttons["profile.save"].waitForExistence(timeout: 10))
    app.buttons["profile.save"].tap()
    app.tabBars.buttons["My Learning"].tap()
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
    for label in ["Submitted work", "Tutor feedback"] {
      let source = app.switches[label]
      XCTAssertTrue(source.waitForExistence(timeout: 5))
      XCTAssertEqual(source.value as? String, "0")
      let nested = source.switches.firstMatch
      if nested.exists {
        nested.tap()
      } else {
        source.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
      }
      let selected = XCTNSPredicateExpectation(
        predicate: NSPredicate(format: "value == %@", "1"), object: source)
      guard XCTWaiter.wait(for: [selected], timeout: 5) == .completed else {
        XCTFail("Source was not selected: \(label). UI: \(app.debugDescription)")
        return
      }
    }
    let reflection = app.switches["Reflection"]
    if reflection.exists {
      XCTAssertEqual(reflection.value as? String, "0", "Reflection must remain private")
    }
    XCTAssertTrue(app.textViews["Approved text for Submitted work"].waitForExistence(timeout: 5))
    app.swipeUp()
    app.swipeUp()
    app.buttons["mentor.engine"].tap()
    app.buttons["Contextual offline (not AI)"].tap()
    let approve = app.buttons["mentor.approve"]
    guard
      XCTWaiter.wait(
        for: [
          XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "enabled == true"), object: approve)
        ], timeout: 5) == .completed
    else {
      XCTFail("Approval did not enable. UI: \(app.debugDescription)")
      return
    }
    approve.tap()
    let saved = app.buttons["mentor.savedReport"]
    guard saved.waitForExistence(timeout: 10) else {
      XCTFail("Report not saved. UI: \(app.debugDescription)")
      return
    }
    saved.tap()
    let reportLabels = [
      "Keep doing", "Improve",
      "Community gardens can improve wellbeing. One study found participants met neighbours more often.",
      "Your example is clear. Explain how the evidence supports your claim.",
    ]
    for label in reportLabels {
      let item = app.staticTexts[label]
      for _ in 0..<6 where !item.exists { app.swipeUp() }
      guard item.exists else {
        XCTFail("Missing report text: \(label). UI: \(app.debugDescription)")
        return
      }
    }
    func focusControl() -> XCUIElement {
      app.descendants(matching: .any).matching(identifier: "focus.input").firstMatch
    }
    for _ in 0..<6 where !focusControl().isHittable { app.swipeUp() }
    let focus = focusControl()
    guard focus.isHittable else {
      XCTFail("Focus input was not reachable. UI: \(app.debugDescription)")
      return
    }
    focus.tap()
    focus.typeText("Explain the evidence in my next assignment")
    let saveFocus = app.buttons["focus.save"]
    for _ in 0..<6 where !saveFocus.isHittable { app.swipeUp() }
    guard saveFocus.isHittable else {
      XCTFail("Save focus button was not reachable. UI: \(app.debugDescription)")
      return
    }
    saveFocus.tap()
    let progress = app.descendants(matching: .any).matching(identifier: "focus.progress").firstMatch
    for _ in 0..<6 where !progress.isHittable { app.swipeUp() }
    guard progress.isHittable else {
      XCTFail("Progress link was not reachable. UI: \(app.debugDescription)")
      return
    }
    progress.tap()
    let sample = app.staticTexts["Sample practice"]
    for _ in 0..<6 where !sample.exists { app.swipeUp() }
    XCTAssertTrue(sample.waitForExistence(timeout: 5))
    let focusTitle = app.staticTexts["Explain the evidence in my next assignment"]
    for _ in 0..<4 where !focusTitle.exists { app.swipeUp() }
    XCTAssertTrue(focusTitle.exists)
  }
}
