import XCTest

final class UniCoachUITests: XCTestCase {
  private func element(_ app: XCUIApplication, id: String) -> XCUIElement {
    app.descendants(matching: .any).matching(identifier: id).firstMatch
  }

  @discardableResult private func reach(
    _ target: XCUIElement, in app: XCUIApplication, up: Bool = true, attempts: Int = 8,
    file: StaticString = #filePath, line: UInt = #line
  ) -> Bool {
    for _ in 0..<attempts {
      if target.exists && target.isHittable { return true }
      // Drag inside the form cell margin, outside its text editor and above any keyboard.
      let frame = app.frame
      let keyboard = app.keyboards.firstMatch
      let lower =
        keyboard.exists
        ? min(frame.height - 100, keyboard.frame.minY - frame.minY - 28)
        : frame.height - 100
      let upper = min(170, lower - 60)
      let x = 24 / frame.width
      let start = app.coordinate(
        withNormalizedOffset: CGVector(dx: x, dy: (up ? lower : upper) / frame.height))
      let end = app.coordinate(
        withNormalizedOffset: CGVector(dx: x, dy: (up ? upper : lower) / frame.height))
      start.press(forDuration: 0.05, thenDragTo: end)
    }
    if target.exists && target.isHittable { return true }
    XCTFail("Could not reach \(target). UI: \(app.debugDescription)", file: file, line: line)
    return false
  }

  private func chooseSwitch(_ control: XCUIElement, in app: XCUIApplication) {
    guard reach(control, in: app) else { return }
    XCTAssertEqual(control.value as? String, "0", "Context must start unselected")
    let nested = control.switches.firstMatch
    if nested.exists {
      nested.tap()
    } else {
      control.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
    }
    let selected = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "value == %@", "1"), object: control)
    XCTAssertEqual(XCTWaiter.wait(for: [selected], timeout: 5), .completed)
  }

  private func enter(_ value: String, id: String, in app: XCUIApplication) {
    let input = element(app, id: id)
    guard reach(input, in: app) else { return }
    input.tap()
    input.typeText(value)
    if id.hasPrefix("assignment.") { dismissAssignmentKeyboard(in: app) }
  }

  private func dismissAssignmentKeyboard(in app: XCUIApplication) {
    let done = app.buttons["assignment.keyboardDone"]
    guard done.waitForExistence(timeout: 5) && done.isHittable else {
      XCTFail("Assignment keyboard Done button not available: \(app.debugDescription)")
      return
    }
    done.tap()
    let dismissed = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "exists == false"), object: app.keyboards.firstMatch)
    XCTAssertEqual(
      XCTWaiter.wait(for: [dismissed], timeout: 5), .completed, "Keyboard did not dismiss")
  }

  private func back(_ label: String, in app: XCUIApplication) {
    let button = app.navigationBars.buttons[label].firstMatch
    XCTAssertTrue(
      button.waitForExistence(timeout: 5), "Missing back button \(label): \(app.debugDescription)")
    if button.exists { button.tap() }
  }

  private func attachScreenshot(_ name: String, app: XCUIApplication) {
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }

  func testSyntheticOfflineFlow() throws {
    let app = XCUIApplication()
    app.launchArguments.append("-ui-smoke")
    app.launch()
    let continueButton = app.buttons["profile.save"]
    XCTAssertTrue(continueButton.waitForExistence(timeout: 10))
    continueButton.tap()
    app.tabBars.buttons["My Learning"].tap()
    app.buttons["subject.add"].tap()
    enter("Synthetic Design", id: "subject.name", in: app)
    enter("DES101", id: "subject.code", in: app)
    app.buttons["editor.save"].tap()
    let subjectsTab = app.segmentedControls.buttons["Subjects"]
    guard reach(subjectsTab, in: app, up: false) else { return }
    subjectsTab.tap()
    let subject = app.staticTexts["Synthetic Design"].firstMatch
    guard reach(subject, in: app) else { return }
    subject.tap()
    let editSubject = app.buttons["subject.edit"]
    XCTAssertTrue(editSubject.waitForExistence(timeout: 5))
    editSubject.tap()
    enter("Sem 2, 2026", id: "subject.semester", in: app)
    app.buttons["editor.save"].tap()
    XCTAssertTrue(app.staticTexts["Sem 2, 2026"].waitForExistence(timeout: 5))

    let addAssignment = app.buttons["subject.addAssignment"]
    guard reach(addAssignment, in: app) else { return }
    addAssignment.tap()
    enter("Synthetic essay", id: "assignment.title", in: app)
    enter("12.35", id: "assignment.score", in: app)
    enter("20", id: "assignment.outOf", in: app)
    let work = app.textViews["Submitted work"]
    guard reach(work, in: app) else { return }
    work.tap()
    work.typeText(
      "Community gardens can improve wellbeing. One study found participants met neighbours more often."
    )
    dismissAssignmentKeyboard(in: app)
    let feedback = app.textViews["Tutor feedback"]
    guard reach(feedback, in: app) else { return }
    feedback.tap()
    feedback.typeText(
      "Your example is clear. You should explain how the evidence supports your claim.")
    dismissAssignmentKeyboard(in: app)
    let reflection = app.textViews["Your reflection"]
    guard reach(reflection, in: app) else { return }
    reflection.tap()
    reflection.typeText("I want to make my reasoning easier to follow.")
    dismissAssignmentKeyboard(in: app)
    app.buttons["editor.save"].tap()
    guard reach(addAssignment, in: app) else { return }
    addAssignment.tap()
    enter("Second synthetic assignment", id: "assignment.title", in: app)
    enter("35.8", id: "assignment.score", in: app)
    enter("40", id: "assignment.outOf", in: app)
    app.buttons["editor.save"].tap()
    let first = app.staticTexts["Synthetic essay"].firstMatch
    let marks = element(app, id: "subject.marks")
    guard reach(marks, in: app, up: false) else { return }
    let markLabel = marks.label
    XCTAssertTrue(markLabel.contains("80.25"), markLabel)
    XCTAssertTrue(markLabel.contains("48.15"), markLabel)
    XCTAssertTrue(markLabel.contains("60"), markLabel)

    guard reach(first, in: app) else { return }
    first.tap()
    let mentor = app.buttons["Open mentor"]
    guard reach(mentor, in: app) else { return }
    mentor.tap()
    chooseSwitch(app.switches["Submitted work"], in: app)
    chooseSwitch(app.switches["Tutor feedback"], in: app)
    let reflectionSwitch = app.switches["Reflection"]
    guard reach(reflectionSwitch, in: app) else { return }
    XCTAssertEqual(reflectionSwitch.value as? String, "0", "Reflection must remain private")
    let approvedWork = app.textViews["Approved text for Submitted work"]
    guard reach(approvedWork, in: app) else { return }
    let engine = element(app, id: "mentor.engine")
    guard reach(engine, in: app) else { return }
    engine.tap()
    app.buttons["Contextual offline (not AI)"].tap()
    let approve = app.buttons["mentor.approve"]
    guard reach(approve, in: app) else { return }
    XCTAssertTrue(approve.isEnabled)
    approve.tap()
    let saved = app.buttons["mentor.savedReport"]
    guard reach(saved, in: app) else { return }
    saved.tap()
    let expected = "You should explain how the evidence supports your claim."
    for label in ["Keep doing", "Improve", expected, "Next step"] {
      let item = app.staticTexts[label].firstMatch
      guard reach(item, in: app) else { return }
    }
    let create = app.buttons["goal.fromReport"]
    guard reach(create, in: app) else { return }
    create.tap()
    let progressLink = app.buttons["focus.progress"]
    guard reach(progressLink, in: app) else { return }
    back("Review feedback", in: app)
    app.buttons["Close"].tap()
    back("Subject", in: app)
    let subjectGoal = app.buttons.matching(
      NSPredicate(
        format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "subject.goal.", expected)
    ).firstMatch
    guard reach(subjectGoal, in: app) else { return }
    XCTAssertEqual(subjectGoal.value as? String, "Not completed")
    app.tabBars.buttons["My Progress"].tap()
    let goalsSection = app.staticTexts["Learning goals"]
    guard reach(goalsSection, in: app) else { return }
    let goal = app.buttons.matching(
      NSPredicate(
        format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "progress.goal.", expected)
    ).firstMatch
    guard reach(goal, in: app) else { return }
    XCTAssertEqual(goal.value as? String, "Not completed")
    goal.tap()
    XCTAssertEqual(goal.value as? String, "Completed")
    app.tabBars.buttons["My Learning"].tap()
    for _ in 0..<6 where subjectGoal.exists { app.swipeUp() }
    XCTAssertFalse(subjectGoal.exists, "Completed goal should leave subject open-goal list")
    back("My Learning", in: app)
    app.tabBars.buttons["Home"].tap()
    attachScreenshot("Home", app: app)
    app.tabBars.buttons["My Learning"].tap()
    let overview = app.segmentedControls.buttons["Overview"]
    guard reach(overview, in: app, up: false) else { return }
    overview.tap()
    attachScreenshot("Learning Overview", app: app)
    let subjects = app.segmentedControls.buttons["Subjects"]
    subjects.tap()
    attachScreenshot("Learning Subjects", app: app)
  }
}
