import XCTest

final class UniCoachUITests: XCTestCase {
  override func setUp() {
    super.setUp()
    let previous = XCUIDevice.shared.orientation
    if previous == .landscapeLeft || previous == .landscapeRight || previous == .portraitUpsideDown {
      addTeardownBlock { XCUIDevice.shared.orientation = previous }
    }
    XCUIDevice.shared.orientation = .portrait
  }

  private func element(_ app: XCUIApplication, id: String) -> XCUIElement {
    app.descendants(matching: .any).matching(identifier: id).firstMatch
  }

  @discardableResult private func reach(
    _ target: XCUIElement, in app: XCUIApplication, scrolling scrollView: XCUIElement? = nil,
    up: Bool = true, attempts: Int = 8,
    file: StaticString = #filePath, line: UInt = #line
  ) -> Bool {
    for _ in 0..<attempts {
      if target.exists && target.isHittable { return true }
      if let scrollView, scrollView.exists {
        if up { scrollView.swipeUp() } else { scrollView.swipeDown() }
        continue
      }
      // Drag inside the form cell margin, outside its text editor and above any keyboard.
      let frame = app.frame
      let keyboard = app.keyboards.firstMatch
      let lower =
        keyboard.exists
        ? min(frame.height - 100, keyboard.frame.minY - frame.minY - 28)
        : frame.height - 100
      let upper = min(170, lower - 60)
      let x = frame.width > frame.height ? 0.12 : 24 / frame.width
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
    _ = dismissKeyboard("assignment.keyboardDone", in: app)
  }

  private func dismissKeyboard(_ buttonID: String, in app: XCUIApplication) -> Bool {
    let done = app.buttons[buttonID]
    let keyboard = app.keyboards.firstMatch
    let ready = XCTNSPredicateExpectation(
      predicate: NSPredicate { _, _ in
        guard keyboard.exists, done.exists else { return false }
        let frame = done.frame
        return !frame.isEmpty && !frame.isInfinite && frame.midX.isFinite && frame.midY.isFinite
          && app.frame.contains(CGPoint(x: frame.midX, y: frame.midY))
      }, object: nil)
    guard XCTWaiter.wait(for: [ready], timeout: 10) == .completed else {
      XCTFail("Keyboard Done button did not appear on screen: " + buttonID)
      return false
    }
    // UIKit can report an invalid activation point for the keyboard toolbar during layout.
    let frame = done.frame
    let window = app.frame
    app.coordinate(withNormalizedOffset: CGVector(
      dx: (frame.midX - window.minX) / window.width,
      dy: (frame.midY - window.minY) / window.height)).tap()
    let dismissed = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "exists == false"), object: keyboard)
    let finished = XCTWaiter.wait(for: [dismissed], timeout: 5) == .completed
    XCTAssertTrue(finished, "Keyboard did not dismiss using " + buttonID)
    return finished
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

  func testSyntheticLearningFlow() throws {
    let app = XCUIApplication()
    app.launchArguments.append("-ui-smoke")
    app.launch()
    let continueButton = app.buttons["profile.save"]
    XCTAssertTrue(continueButton.waitForExistence(timeout: 10))
    continueButton.tap()
    let subjectsCard = app.buttons["home.catalogue.subjects"]
    guard reach(subjectsCard, in: app) else { return }
    subjectsCard.tap()
    XCTAssertTrue(app.segmentedControls.buttons["Subjects"].isSelected)
    let addSubject = app.buttons["subject.add"]
    guard reach(addSubject, in: app) else { return }
    addSubject.tap()
    enter("Synthetic Design", id: "subject.name", in: app)
    enter("DES101", id: "subject.code", in: app)
    app.buttons["editor.save"].tap()
    let subject = app.staticTexts["Synthetic Design"].firstMatch
    guard reach(subject, in: app) else { return }
    subject.tap()
    let editSubject = app.buttons["subject.edit"]
    XCTAssertTrue(editSubject.waitForExistence(timeout: 5))
    editSubject.tap()
    let subjectDescription = "Synthetic subject about community design research."
    let description = element(app, id: "subject.description")
    guard reach(description, in: app) else { return }
    description.tap()
    description.typeText(subjectDescription)
    enter("Sem 2, 2026", id: "subject.semester", in: app)
    app.buttons["editor.save"].tap()
    XCTAssertTrue(app.staticTexts["Sem 2, 2026"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts[subjectDescription].exists)

    let addAssignment = app.buttons["subject.addAssignment"]
    guard reach(addAssignment, in: app) else { return }
    addAssignment.tap()
    let brief = "Explain how a community project supports wellbeing."
    let stageAnswer = "I have completed a first draft."
    let reflection = "I want to make my reasoning easier to follow."
    enter("Synthetic essay", id: "assignment.title", in: app)
    enter("25", id: "assignment.weighting", in: app)
    guard enterAssignmentText(brief, label: "Assignment brief", in: app),
      advanceAssignment(in: app)
    else { return }

    let guided = app.buttons["Current stage & progress"]
    guard reach(guided, in: app) else { return }
    guided.tap()
    guard enterAssignmentText(stageAnswer, label: "Current stage & progress", in: app) else { return }
    let allInOne = app.segmentedControls.buttons["All-in-one reflection"]
    guard reach(allInOne, in: app, up: false) else { return }
    allInOne.tap()
    guard enterAssignmentText(reflection, label: "Your reflection", in: app),
      enterAssignmentText(
        "Community gardens can improve wellbeing. One study found participants met neighbours more often.",
        label: "Submitted work", in: app),
      advanceAssignment(in: app)
    else { return }

    guard enterAssignmentText(
      "Your example is clear. You should explain how the evidence supports your claim.",
      label: "Tutor feedback", in: app)
    else { return }
    enter("12.35", id: "assignment.score", in: app)
    enter("20", id: "assignment.outOf", in: app)
    guard advanceAssignment(in: app) else { return }
    guard reach(app.staticTexts["Review assignment"], in: app, up: false) else { return }
    attachScreenshot("Assignment wizard review", app: app)
    app.buttons["editor.save"].tap()

    guard reach(addAssignment, in: app) else { return }
    addAssignment.tap()
    enter("Second synthetic assignment", id: "assignment.title", in: app)
    guard advanceAssignment(in: app), advanceAssignment(in: app) else { return }
    enter("35.8", id: "assignment.score", in: app)
    enter("40", id: "assignment.outOf", in: app)
    guard advanceAssignment(in: app) else { return }
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
    for label in [stageAnswer, reflection, brief] {
      guard reach(app.staticTexts[label], in: app) else { return }
    }
    app.buttons["assignment.actions"].tap()
    app.buttons["assignment.edit"].tap()
    let weighting = element(app, id: "assignment.weighting")
    guard reach(weighting, in: app) else { return }
    XCTAssertEqual(Double(weighting.value as? String ?? ""), 25)
    let savedBrief = app.textViews["Assignment brief"]
    guard reach(savedBrief, in: app) else { return }
    XCTAssertEqual(savedBrief.value as? String, brief)
    let title = element(app, id: "assignment.title")
    guard reach(title, in: app, up: false) else { return }
    title.tap()
    title.typeText(" unsaved edit")
    app.navigationBars.buttons["Cancel"].tap()
    XCTAssertTrue(app.navigationBars["Synthetic essay"].waitForExistence(timeout: 5))
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
    let availability = element(app, id: "mentor.availability")
    guard reach(availability, in: app) else { return }
    let available = availability.label == "Apple on-device model is available."
    let approve = app.buttons["mentor.approve"]
    guard reach(approve, in: app) else { return }
    XCTAssertTrue(approve.label.contains("Apple AI"))
    XCTAssertEqual(approve.isEnabled, available)
    XCTAssertFalse(element(app, id: "mentor.engine").exists)
    XCTAssertFalse(app.buttons["Contextual offline (not AI)"].exists)
    app.navigationBars.buttons["Close"].tap()
    back("Subject", in: app)

    let linkedGoalTitle = "Explain the evidence in my next assignment"
    let subjectAddGoal = app.buttons["Add goal"]
    guard reach(subjectAddGoal, in: app) else { return }
    subjectAddGoal.tap()
    enter(linkedGoalTitle, id: "goal.title", in: app)
    app.buttons["goal.save"].tap()
    let subjectGoal = app.buttons.matching(NSPredicate(
      format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "subject.goal.", linkedGoalTitle
    )).firstMatch
    guard reach(subjectGoal, in: app) else { return }
    XCTAssertEqual(subjectGoal.value as? String, "Not completed")

    app.tabBars.buttons["Home"].tap()
    attachScreenshot("Home", app: app)
    let goalsCard = app.buttons["home.catalogue.goals"]
    guard reach(goalsCard, in: app) else { return }
    goalsCard.tap()
    XCTAssertTrue(app.segmentedControls.buttons["Goals"].isSelected)
    let addGoal = app.buttons["goals.add"]
    guard reach(addGoal, in: app) else { return }
    addGoal.tap()
    let generalGoal = "Plan a weekly study session"
    enter(generalGoal, id: "goal.title", in: app)
    app.buttons["goal.save"].tap()
    let actions = app.buttons.matching(NSPredicate(
      format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "learning.goal.actions.", generalGoal
    )).firstMatch
    guard reach(actions, in: app) else { return }
    actions.tap()
    app.buttons["Edit goal"].tap()
    XCTAssertEqual(element(app, id: "goal.title").value as? String, generalGoal)
    app.navigationBars.buttons["Cancel"].tap()
    let learningGoal = app.buttons.matching(NSPredicate(
      format: "identifier BEGINSWITH %@ AND NOT (identifier BEGINSWITH %@) AND label CONTAINS %@",
      "learning.goal.", "learning.goal.actions.", linkedGoalTitle
    )).firstMatch
    guard reach(learningGoal, in: app, up: false) else { return }
    XCTAssertEqual(learningGoal.value as? String, "Not completed")
    learningGoal.tap()
    XCTAssertEqual(learningGoal.value as? String, "Completed")
    attachScreenshot("Learning Goals", app: app)

    app.tabBars.buttons["My Progress"].tap()
    let progressGoal = app.buttons.matching(NSPredicate(
      format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "progress.goal.", linkedGoalTitle
    )).firstMatch
    guard reach(progressGoal, in: app) else { return }
    XCTAssertEqual(progressGoal.value as? String, "Completed")
    guard reach(app.staticTexts["Learning pathway status"], in: app, up: false) else { return }
    XCTAssertTrue(app.staticTexts["Graded assignments"].exists)
    attachScreenshot("Progress learning pathway metrics", app: app)

    app.tabBars.buttons["Home"].tap()
    let feedbackCard = app.buttons["home.catalogue.feedback"]
    guard reach(feedbackCard, in: app) else { return }
    feedbackCard.tap()
    XCTAssertTrue(app.segmentedControls.buttons["Assignments"].isSelected)
    let feedbackFilter = element(app, id: "assignments.feedbackFilter")
    guard reach(feedbackFilter, in: app) else { return }
    XCTAssertTrue(feedbackFilter.label.contains("With feedback"))
    guard reach(app.staticTexts["Assignments with feedback (1)"], in: app) else { return }

    app.tabBars.buttons["Home"].tap()
    let assignmentsCard = app.buttons["home.catalogue.assignments"]
    guard reach(assignmentsCard, in: app) else { return }
    assignmentsCard.tap()
    XCTAssertTrue(app.segmentedControls.buttons["Assignments"].isSelected)
    guard reach(feedbackFilter, in: app) else { return }
    XCTAssertTrue(feedbackFilter.label.contains("All assignments"))
    let assignmentsBanner = app.staticTexts["Your assignments"]
    guard reach(assignmentsBanner, in: app) else { return }
    attachScreenshot("Learning Assignments dashboard", app: app)
    let subjectFilter = element(app, id: "assignments.subjectFilter")
    guard reach(subjectFilter, in: app, up: false) else { return }
    subjectFilter.tap()
    app.buttons["Synthetic Design"].tap()
    XCTAssertTrue((subjectFilter.label + " " + (subjectFilter.value as? String ?? "")).contains("Synthetic Design"))
    guard reach(app.staticTexts["Subject assignments"], in: app) else { return }
    attachScreenshot("Learning Assignments filtered by subject", app: app)

    let month = element(app, id: "assignments.calendar")
    guard reach(month, in: app) else { return }
    let originalMonth = month.label
    let nextMonth = app.buttons["assignments.calendar.next"]
    let previousMonth = app.buttons["assignments.calendar.previous"]
    nextMonth.tap()
    XCTAssertNotEqual(month.label, originalMonth)
    previousMonth.tap()
    XCTAssertEqual(month.label, originalMonth)

    let markedDay = app.buttons.matching(NSPredicate(
      format: "identifier BEGINSWITH %@ AND value == %@",
      "assignments.calendar.day.", "2 assignments due")).firstMatch
    guard reach(markedDay, in: app) else { return }
    markedDay.tap()
    let dueLinks = app.buttons.matching(NSPredicate(
      format: "identifier BEGINSWITH %@", "assignments.calendar.assignment."))
    XCTAssertEqual(dueLinks.count, 2)
    let essayDue = dueLinks.matching(NSPredicate(format: "label == %@", "Synthetic essay")).firstMatch
    guard reach(essayDue, in: app) else { return }
    attachScreenshot("Marked assignment dates and selected day", app: app)
    XCTAssertFalse(app.staticTexts["Upcoming (next 7 days)"].exists)
    essayDue.tap()
    XCTAssertTrue(app.navigationBars["Synthetic essay"].waitForExistence(timeout: 5))
    back("My Learning", in: app)

    let assignmentRow = app.buttons.matching(NSPredicate(
      format: "label BEGINSWITH %@ AND label CONTAINS %@ AND label CONTAINS %@",
      "Synthetic essay,", "Synthetic Design", "Graded")).firstMatch
    guard reach(app.staticTexts["All assignments (2)"], in: app),
      reach(assignmentRow, in: app)
    else { return }
  }

  private func enterAssignmentText(_ text: String, label: String, in app: XCUIApplication) -> Bool {
    let editor = app.textViews[label]
    guard reach(editor, in: app) else { return false }
    editor.tap()
    editor.typeText(text)
    return dismissKeyboard("assignment.keyboardDone", in: app)
  }

  private func advanceAssignment(in app: XCUIApplication) -> Bool {
    let next = app.buttons["assignment.next"]
    guard reach(next, in: app) else { return false }
    next.tap()
    return true
  }

  func testLearningSectionLayoutAndMentorBrand() {
    continueAfterFailure = false
    let app = XCUIApplication()
    app.launchArguments = ["-ui-smoke"]
    app.launch()
    let onboarding = app.buttons["profile.save"]
    XCTAssertTrue(onboarding.waitForExistence(timeout: 10))
    onboarding.tap()
    let home = app.tabBars.buttons["Home"]

    let subjectsCard = app.buttons["home.catalogue.subjects"]
    guard reach(subjectsCard, in: app) else { return }
    subjectsCard.tap()
    XCTAssertTrue(app.segmentedControls.buttons["Subjects"].isSelected)
    let addSubject = app.buttons["subject.add"]
    let subjectsBanner = app.staticTexts["Your subjects"]
    let subjectPerformance = app.staticTexts["Your subject performance"]
    guard reach(addSubject, in: app), reach(subjectsBanner, in: app) else { return }
    XCTAssertLessThan(addSubject.frame.midY, subjectsBanner.frame.midY)
    XCTAssertTrue(subjectPerformance.exists)
    XCTAssertLessThan(subjectsBanner.frame.midY, subjectPerformance.frame.midY)
    attachScreenshot("Subjects banner at the top of Learning", app: app)
    addSubject.tap()
    XCTAssertTrue(element(app, id: "subject.name").waitForExistence(timeout: 5))
    app.navigationBars.buttons["Cancel"].tap()
    XCTAssertTrue(addSubject.waitForExistence(timeout: 5))
    addSubject.tap()
    let subjectName = "Layout test subject"
    enter(subjectName, id: "subject.name", in: app)
    app.buttons["editor.save"].tap()
    XCTAssertTrue(addSubject.waitForExistence(timeout: 5))

    home.tap()
    let assignmentsCard = app.buttons["home.catalogue.assignments"]
    guard reach(assignmentsCard, in: app) else { return }
    assignmentsCard.tap()
    XCTAssertTrue(app.segmentedControls.buttons["Assignments"].isSelected)
    let assignmentBanner = app.staticTexts["Your assignments"]
    let progress = app.staticTexts["Assignment progress"]
    let subjectFilter = element(app, id: "assignments.subjectFilter")
    guard reach(assignmentBanner, in: app), reach(progress, in: app) else { return }
    XCTAssertLessThan(assignmentBanner.frame.midY, progress.frame.midY)
    XCTAssertFalse(app.staticTexts["Overall insights"].exists)
    XCTAssertTrue(subjectFilter.exists)
    XCTAssertLessThan(progress.frame.midY, subjectFilter.frame.midY)
    attachScreenshot("Assignment progress near the top of Learning", app: app)
    guard reach(subjectFilter, in: app) else { return }
    subjectFilter.tap()
    app.buttons[subjectName].tap()
    let filteredBanner = app.staticTexts["Subject assignments"]
    guard reach(filteredBanner, in: app, up: false) else { return }
    XCTAssertFalse(app.staticTexts["Subject insights"].exists)
    XCTAssertLessThan(filteredBanner.frame.midY, progress.frame.midY)

    home.tap()
    let goalsCard = app.buttons["home.catalogue.goals"]
    guard reach(goalsCard, in: app) else { return }
    goalsCard.tap()
    XCTAssertTrue(app.segmentedControls.buttons["Goals"].isSelected)
    let addGoal = app.buttons["goals.add"]
    let goalsBanner = app.staticTexts["Your goals"]
    let goalList = app.staticTexts["Learning goals"]
    guard reach(addGoal, in: app), reach(goalsBanner, in: app) else { return }
    XCTAssertLessThan(addGoal.frame.midY, goalsBanner.frame.midY)
    XCTAssertTrue(goalList.exists)
    XCTAssertLessThan(goalsBanner.frame.midY, goalList.frame.midY)
    attachScreenshot("Goals banner at the top of Learning", app: app)
    addGoal.tap()
    XCTAssertTrue(element(app, id: "goal.title").waitForExistence(timeout: 5))
    app.navigationBars.buttons["Cancel"].tap()
    guard reach(app.staticTexts["No learning goals in this selection."], in: app) else { return }

    app.tabBars.buttons["AI Mentor"].tap()
    app.buttons["mentor.ask"].tap()
    let brand = app.images["conversation.brandIcon"]
    let transcript = app.scrollViews["conversation.transcript"]
    guard reach(brand, in: app, scrolling: transcript) else { return }
    XCTAssertEqual(brand.label, "UniCoach app icon")
    XCTAssertFalse(app.buttons["conversation.send"].isEnabled)
    attachScreenshot("UniCoach app icon in Mentor welcome", app: app)
  }

  func testMentorQuestionConsentResets() {
    let app = XCUIApplication()
    app.launchArguments.append("-ui-smoke")
    app.launch()
    let continueButton = app.buttons["profile.save"]
    XCTAssertTrue(continueButton.waitForExistence(timeout: 10))
    continueButton.tap()
    app.tabBars.buttons["AI Mentor"].tap()
    app.buttons["mentor.ask"].tap()

    let input = element(app, id: "conversation.input")
    let send = app.buttons["conversation.send"]
    let sources = app.buttons["conversation.sources"]
    let useSources = app.buttons["conversation.useSources"]
    let progress = element(app, id: "question.source.progress")
    let approved = app.textViews["Approved text for Progress overview"]
    XCTAssertTrue(input.waitForExistence(timeout: 5))
    XCTAssertFalse(send.isEnabled)
    XCTAssertEqual(sources.label, "Add context")
    attachScreenshot("Mentor chat welcome", app: app)

    app.buttons["question.starter"].tap()
    XCTAssertEqual(input.value as? String, "How can I plan my study time?")
    sources.tap()
    chooseSwitch(progress, in: app)
    guard reach(approved, in: app) else { return }
    approved.tap()
    approved.typeText(" synthetic edit")
    guard dismissKeyboard("question.keyboardDone", in: app) else { return }
    XCTAssertTrue((approved.value as? String ?? "").contains("synthetic edit"))
    useSources.tap()
    XCTAssertEqual(sources.label, "1 source selected")
    XCTAssertFalse(element(app, id: "conversation.question.0").exists, "Reviewing context must not send a request")

    sources.tap()
    XCTAssertEqual(progress.value as? String, "1")
    guard reach(approved, in: app) else { return }
    approved.tap()
    approved.typeText(" discard this edit")
    guard dismissKeyboard("question.keyboardDone", in: app) else { return }
    app.navigationBars.buttons["Cancel"].tap()
    sources.tap()
    guard reach(approved, in: app) else { return }
    let kept = approved.value as? String ?? ""
    XCTAssertTrue(kept.contains("synthetic edit"))
    XCTAssertFalse(kept.contains("discard this edit"))
    app.navigationBars.buttons["Cancel"].tap()

    app.navigationBars.buttons["Close"].tap()
    app.buttons["mentor.ask"].tap()
    XCTAssertTrue(input.waitForExistence(timeout: 5))
    XCTAssertFalse((input.value as? String ?? "").contains("How can I plan"))
    XCTAssertFalse(send.isEnabled)
    XCTAssertEqual(sources.label, "Add context")
    sources.tap()
    XCTAssertEqual(progress.value as? String, "0")
    app.navigationBars.buttons["Cancel"].tap()
  }

  func testSyntheticAppleConversation() throws {
    let app = XCUIApplication()
    app.launchArguments.append("-ui-smoke")
    app.launch()
    let continueButton = app.buttons["profile.save"]
    XCTAssertTrue(continueButton.waitForExistence(timeout: 10))
    continueButton.tap()
    app.tabBars.buttons["AI Mentor"].tap()
    app.buttons["mentor.ask"].tap()

    let input = element(app, id: "conversation.input")
    XCTAssertTrue(input.waitForExistence(timeout: 5))
    let availability = element(app, id: "conversation.availability")
    if availability.exists { throw XCTSkip(availability.label) }

    let firstQuestion = "Give me one practical way to make my study notes easier to review."
    input.tap()
    input.typeText(firstQuestion)
    let send = app.buttons["conversation.send"]
    XCTAssertTrue(send.isHittable, "The composer stays visible above the keyboard")
    guard dismissKeyboard("conversation.keyboardDone", in: app) else { return }
    let sources = app.buttons["conversation.sources"]
    sources.tap()
    let progress = element(app, id: "question.source.progress")
    chooseSwitch(progress, in: app)
    let approved = app.textViews["Approved text for Progress overview"]
    guard reach(approved, in: app) else { return }
    approved.tap()
    let marker = "Synthetic source marker ZEBRA42."
    approved.typeText(" " + marker)
    guard dismissKeyboard("question.keyboardDone", in: app) else { return }
    app.buttons["conversation.useSources"].tap()
    XCTAssertEqual(sources.label, "1 source selected")
    XCTAssertTrue(send.isEnabled)
    send.tap()

    let conversation = app.navigationBars["Conversation"]
    let transcript = app.scrollViews["conversation.transcript"]
    let first = element(app, id: "conversation.question.0")
    XCTAssertTrue(first.waitForExistence(timeout: 90), "Apple request did not save: \(app.debugDescription)")
    XCTAssertFalse(send.isEnabled)
    XCTAssertEqual(sources.label, "Add context", "Every request starts with fresh source consent")
    guard reach(first, in: app, scrolling: transcript, up: false) else { return }
    XCTAssertEqual(first.label, firstQuestion)
    attachScreenshot("First saved Apple mentor turn", app: app)

    let firstDetails = element(app, id: "conversation.request.0")
    guard reach(firstDetails, in: app, scrolling: transcript) else { return }
    firstDetails.tap()
    let answer = element(app, id: "answer.text")
    guard reach(answer, in: app) else { return }
    let firstAnswer = answer.label
    XCTAssertFalse(firstAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    XCTAssertFalse(firstAnswer.contains(where: { "?？؟".contains($0) }))
    let engine = element(app, id: "answer.engine")
    guard reach(engine, in: app) else { return }
    let engineDescription = engine.label + " " + (engine.value as? String ?? "")
    XCTAssertTrue(engineDescription.contains("Apple on-device"), engineDescription)
    let prompt = element(app, id: "answer.prompt")
    guard reach(prompt, in: app) else { return }
    XCTAssertTrue(prompt.label.hasPrefix("Question:\n\(firstQuestion)\n\n[Approved context "))
    XCTAssertTrue(prompt.label.contains(marker))
    back("Conversation", in: app)

    let expectedHistory = "Question:\n\(firstQuestion)\n\nMentor:\n\(firstAnswer)"
    let review = app.buttons["Review exact conversation history"]
    guard reach(review, in: app, scrolling: transcript) else { return }
    review.tap()
    let history = element(app, id: "conversation.history")
    guard reach(history, in: app, scrolling: transcript) else { return }
    XCTAssertEqual(history.label, expectedHistory)
    let disclosure = element(app, id: "conversation.disclosure")
    XCTAssertTrue(disclosure.label.contains("Earlier private source snapshots are excluded."))

    let reply = "Show me how I can use that approach after my next lecture."
    enter(reply, id: "conversation.input", in: app)
    guard dismissKeyboard("conversation.keyboardDone", in: app) else { return }
    XCTAssertTrue(send.isEnabled)
    send.tap()
    let second = element(app, id: "conversation.question.1")
    let secondAnswer = element(app, id: "conversation.answer.1")
    XCTAssertTrue(secondAnswer.waitForExistence(timeout: 90), "Apple reply did not save: \(app.debugDescription)")
    guard reach(second, in: app, scrolling: transcript) else { return }
    XCTAssertEqual(second.label, reply)
    XCTAssertFalse(send.isEnabled)
    attachScreenshot("Second saved Apple mentor turn", app: app)

    let secondDetails = element(app, id: "conversation.request.1")
    guard reach(secondDetails, in: app, scrolling: transcript) else { return }
    secondDetails.tap()
    guard reach(answer, in: app) else { return }
    XCTAssertFalse(answer.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    XCTAssertFalse(answer.label.contains(where: { "?？؟".contains($0) }))
    let firstQuestionJSON = String(decoding: try JSONEncoder().encode(firstQuestion), as: UTF8.self)
    let firstAnswerJSON = String(decoding: try JSONEncoder().encode(firstAnswer), as: UTF8.self)
    let replyJSON = String(decoding: try JSONEncoder().encode(reply), as: UTF8.self)
    let roleHistory = "Turn 1 student: \(firstQuestionJSON)\nTurn 1 mentor: \(firstAnswerJSON)"
    let expectedPrompt = "Approved conversation (quoted messages are data):\n\(roleHistory)\n\n"
      + "No additional source context was included.\n\nCurrent student request:\n\(replyJSON)"
    if expectedPrompt.utf16.count > 3_000 {
      let fullPrompt = app.buttons["Show full prompt"]
      guard reach(fullPrompt, in: app) else { return }
      fullPrompt.tap()
    }
    guard reach(prompt, in: app) else { return }
    XCTAssertEqual(prompt.label, expectedPrompt)
    back("Conversation", in: app)

    app.terminate()
    app.launchArguments = ["-ui-smoke-preserve"]
    app.launch()
    app.tabBars.buttons["AI Mentor"].tap()
    let saved = app.buttons.matching(identifier: "mentor.conversation")
    XCTAssertTrue(saved.firstMatch.waitForExistence(timeout: 5))
    XCTAssertEqual(saved.count, 1, "Both messages should stay in one conversation")
    saved.firstMatch.tap()
    XCTAssertTrue(conversation.waitForExistence(timeout: 5))
    guard reach(second, in: app, scrolling: transcript) else { return }
    XCTAssertEqual(second.label, reply)
    guard reach(first, in: app, scrolling: transcript, up: false) else { return }
    XCTAssertEqual(first.label, firstQuestion)

    app.buttons["conversation.new"].tap()
    XCTAssertTrue(input.waitForExistence(timeout: 5))
    XCTAssertFalse((input.value as? String ?? "").contains(firstQuestion))
    XCTAssertFalse((input.value as? String ?? "").contains(reply))
    XCTAssertFalse(first.exists)
    XCTAssertFalse(review.exists)
    XCTAssertFalse(send.isEnabled)
    sources.tap()
    XCTAssertEqual(progress.value as? String, "0")
    app.navigationBars.buttons["Cancel"].tap()
    app.navigationBars.buttons["Close"].tap()

    saved.firstMatch.swipeLeft()
    app.buttons["Delete"].tap()
    app.buttons["Delete conversation"].tap()
    XCTAssertTrue(app.staticTexts["Your saved conversations will appear here."].waitForExistence(timeout: 5))
    XCTAssertEqual(saved.count, 0)
  }

  func testMentorComposerAccessibility() {
    continueAfterFailure = false
    let previousAppearance = XCUIDevice.shared.appearance
    addTeardownBlock { XCUIDevice.shared.appearance = previousAppearance }
    XCUIDevice.shared.appearance = .dark

    let app = XCUIApplication()
    app.launchArguments = ["-ui-smoke", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
    app.launch()
    let continueButton = app.buttons["profile.save"]
    XCTAssertTrue(continueButton.waitForExistence(timeout: 10))
    continueButton.tap()
    app.tabBars.buttons["AI Mentor"].tap()
    let newConversation = app.buttons["mentor.ask"]
    newConversation.tap()
    let input = element(app, id: "conversation.input")
    XCTAssertTrue(input.waitForExistence(timeout: 10))
    let standardInputHeight = input.frame.height
    XCTAssertGreaterThan(standardInputHeight, 0)

    app.terminate()
    app.launchArguments = [
      "-ui-smoke-preserve", "-UIPreferredContentSizeCategoryName",
      "UICTContentSizeCategoryAccessibilityXXXL",
    ]
    app.launch()
    app.tabBars.buttons["AI Mentor"].tap()
    guard reach(newConversation, in: app) else { return }
    newConversation.tap()
    XCTAssertTrue(input.waitForExistence(timeout: 10))
    XCTAssertGreaterThan(
      input.frame.height, standardInputHeight * 1.25,
      "The largest Dynamic Type launch must make the same input measurably taller")
    let welcome = app.staticTexts["How can I help you learn?"].firstMatch
    let transcript = app.scrollViews["conversation.transcript"]
    let brand = app.images["conversation.brandIcon"]
    guard reach(brand, in: app, scrolling: transcript, up: false) else { return }
    XCTAssertEqual(brand.label, "UniCoach app icon")
    guard reach(welcome, in: app, scrolling: transcript) else { return }
    let send = app.buttons["conversation.send"]
    let sources = app.buttons["conversation.sources"]
    XCTAssertTrue(input.isHittable)
    XCTAssertTrue(send.isHittable)
    XCTAssertFalse(send.isEnabled)
    attachScreenshot("Dark Mentor chat, largest Dynamic Type", app: app)

    let draft = "Study plan"
    input.tap()
    input.typeText(draft)
    XCTAssertTrue(app.keyboards.firstMatch.exists)
    XCTAssertTrue(input.isHittable)
    XCTAssertTrue(send.isHittable, "Approval must remain reachable above the keyboard")
    XCTAssertTrue(sources.isHittable)
    let review = app.buttons["conversation.reviewRequest"]
    XCTAssertTrue(review.isHittable)
    XCTAssertEqual(send.isEnabled, !element(app, id: "conversation.availability").exists)
    let keyboardScreenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    keyboardScreenshot.name = "Dark Mentor composer with keyboard, largest Dynamic Type"
    keyboardScreenshot.lifetime = .keepAlways
    add(keyboardScreenshot)

    sources.tap()
    XCTAssertTrue(app.navigationBars["Add context"].waitForExistence(timeout: 5))
    let progress = element(app, id: "question.source.progress")
    guard reach(progress, in: app) else { return }
    XCTAssertEqual(progress.value as? String, "0")
    attachScreenshot("Dark Mentor context sheet, largest Dynamic Type", app: app)
    app.navigationBars.buttons["Cancel"].tap()
    XCTAssertTrue(input.waitForExistence(timeout: 5))
    XCTAssertEqual(input.value as? String, draft)

    review.tap()
    XCTAssertTrue(app.navigationBars["Review request"].waitForExistence(timeout: 5))
    guard reach(app.staticTexts["Apple on-device AI uses this message and any selected text."], in: app) else { return }
    attachScreenshot("Dark Mentor exact request review, largest Dynamic Type", app: app)
    app.navigationBars.buttons["Done"].tap()
    XCTAssertEqual(input.value as? String, draft)
    XCTAssertFalse(element(app, id: "conversation.question.0").exists)
  }

  func testAlphaProfileAndGoalLifecycle() {
    continueAfterFailure = false
    let app = XCUIApplication()
    app.launchArguments = ["-ui-smoke"]
    app.launch()
    let name = app.textFields.matching(NSPredicate(format: "placeholderValue == %@", "Name")).firstMatch
    let university = app.textFields.matching(NSPredicate(format: "placeholderValue == %@", "University")).firstMatch
    let course = app.textFields.matching(NSPredicate(format: "placeholderValue == %@", "Course")).firstMatch
    XCTAssertTrue(name.waitForExistence(timeout: 10))
    name.tap()
    name.typeText("Quinn Example")
    university.tap()
    university.typeText("Example University")
    course.tap()
    course.typeText("Design Studies")
    app.buttons["profile.save"].tap()
    XCTAssertTrue(app.staticTexts["Greetings, Quinn Example"].waitForExistence(timeout: 5))

    app.navigationBars.buttons["Profile"].tap()
    let privacy = app.staticTexts["Your data and mentor requests stay on this device. Imported files are reviewed before use."]
    guard reach(privacy, in: app) else { return }
    guard reach(app.staticTexts["No reports yet."], in: app) else { return }
    app.navigationBars.buttons["Edit"].tap()
    name.tap()
    name.typeText(" Unsaved")
    app.navigationBars.buttons["Cancel"].tap()
    XCTAssertTrue(app.staticTexts["Quinn Example"].exists)
    XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Unsaved")).firstMatch.exists)
    app.navigationBars.buttons["Edit"].tap()
    replaceText(in: course, with: "Interaction Design")
    app.buttons["profile.save"].tap()
    XCTAssertTrue(app.staticTexts["Interaction Design"].waitForExistence(timeout: 5))
    app.terminate()
    app.launchArguments = ["-ui-smoke-preserve"]
    app.launch()
    XCTAssertTrue(app.staticTexts["Greetings, Quinn Example"].waitForExistence(timeout: 10))
    app.navigationBars.buttons["Profile"].tap()
    XCTAssertTrue(app.staticTexts["Example University"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["Interaction Design"].exists)
    back("Home", in: app)

    let goals = app.buttons["home.catalogue.goals"]
    guard reach(goals, in: app) else { return }
    goals.tap()
    let add = app.buttons["goals.add"]
    guard reach(add, in: app) else { return }
    add.tap()
    let save = app.buttons["goal.save"]
    XCTAssertFalse(save.isEnabled, "A blank goal cannot be saved")
    enter("Discarded goal", id: "goal.title", in: app)
    app.navigationBars.buttons["Cancel"].tap()
    XCTAssertTrue(app.staticTexts["No learning goals in this selection."].exists)

    add.tap()
    enter("Draft a weekly reading plan", id: "goal.title", in: app)
    save.tap()
    let actions = app.buttons.matching(NSPredicate(
      format: "identifier BEGINSWITH %@", "learning.goal.actions."
    )).firstMatch
    guard reach(actions, in: app) else { return }
    actions.tap()
    app.buttons["Edit goal"].tap()
    let editedTitle = "Review a weekly reading plan"
    replaceText(in: element(app, id: "goal.title"), with: editedTitle)
    save.tap()
    let goal = app.buttons.matching(NSPredicate(
      format: "identifier BEGINSWITH %@ AND label == %@", "learning.goal.", editedTitle
    )).firstMatch
    guard reach(goal, in: app) else { return }
    XCTAssertEqual(goal.value as? String, "Not completed")
    goal.tap()
    XCTAssertEqual(goal.value as? String, "Completed")
    actions.tap()
    app.buttons["Delete goal"].tap()
    cancelConfirmation("Delete this goal?", in: app)
    XCTAssertTrue(goal.exists, "Cancel must keep the completed goal")
    actions.tap()
    app.buttons["Delete goal"].tap()
    app.sheets["Delete this goal?"].buttons["Delete goal"].tap()
    XCTAssertTrue(app.staticTexts["No learning goals in this selection."].waitForExistence(timeout: 5))
    XCTAssertFalse(goal.exists)
  }

  func testAlphaAssignmentValidationAndDeletion() {
    continueAfterFailure = false
    let app = XCUIApplication()
    app.launchArguments = ["-ui-smoke"]
    app.launch()
    let continueButton = app.buttons["profile.save"]
    XCTAssertTrue(continueButton.waitForExistence(timeout: 10))
    continueButton.tap()
    let subjects = app.buttons["home.catalogue.subjects"]
    guard reach(subjects, in: app) else { return }
    subjects.tap()
    let addSubject = app.buttons["subject.add"]
    guard reach(addSubject, in: app) else { return }
    addSubject.tap()
    let save = app.buttons["editor.save"]
    XCTAssertFalse(save.isEnabled, "A blank subject cannot be saved")
    enter("Discarded subject", id: "subject.name", in: app)
    app.navigationBars.buttons["Cancel"].tap()
    XCTAssertFalse(app.staticTexts["Discarded subject"].exists)

    let sample = app.buttons["subjects.sample"]
    guard reach(sample, in: app) else { return }
    sample.tap()
    let subject = app.staticTexts["Example subject"].firstMatch
    app.swipeDown()
    guard reach(subject, in: app) else { return }
    subject.tap()
    let editSubject = app.buttons["subject.edit"]
    let credits = element(app, id: "subject.credits")
    editSubject.tap()
    guard reach(credits, in: app) else { return }
    let invalidCredits = app.alerts["Invalid credits"]
    for invalid in ["-1", "12abc"] {
      credits.tap()
      credits.typeKey("a", modifierFlags: .command)
      for character in invalid { credits.typeKey(String(character), modifierFlags: []) }
      XCTAssertEqual(credits.value as? String, invalid)
      save.tap()
      XCTAssertTrue(invalidCredits.waitForExistence(timeout: 5))
      XCTAssertTrue(invalidCredits.staticTexts["Enter a valid nonnegative number of credits."].exists)
      invalidCredits.buttons["OK"].tap()
    }
    let decimalSeparator = Locale.current.decimalSeparator ?? "."
    let fractional = "6" + decimalSeparator + "5"
    replaceText(in: credits, with: fractional)
    save.tap()
    let fractionalCredits = app.staticTexts.matching(NSPredicate(
      format: "label BEGINSWITH %@", fractional + " credits")).firstMatch
    XCTAssertTrue(fractionalCredits.waitForExistence(timeout: 5))
    editSubject.tap()
    guard reach(credits, in: app) else { return }
    replaceText(in: credits, with: "0")
    save.tap()
    XCTAssertTrue(app.staticTexts.matching(NSPredicate(
      format: "label BEGINSWITH %@", "0 credits")).firstMatch.waitForExistence(timeout: 5))

    let addAssignment = app.buttons["subject.addAssignment"]
    guard reach(addAssignment, in: app) else { return }
    addAssignment.tap()
    XCTAssertFalse(save.isEnabled, "Only the final review can save")
    let next = app.buttons["assignment.next"]
    guard reach(next, in: app) else { return }
    XCTAssertFalse(next.isEnabled, "Details require an assignment title")
    let title = "Validation exercise"
    let titleField = element(app, id: "assignment.title")
    guard reach(titleField, in: app, up: false) else { return }
    enter(title, id: "assignment.title", in: app)
    enter("101", id: "assignment.weighting", in: app)
    guard advanceAssignment(in: app), advanceAssignment(in: app) else { return }
    enter("90", id: "assignment.score", in: app)
    enter("20", id: "assignment.outOf", in: app)
    guard advanceAssignment(in: app) else { return }
    save.tap()
    let alert = app.alerts.firstMatch
    XCTAssertTrue(alert.waitForExistence(timeout: 5))
    XCTAssertTrue(alert.staticTexts["Enter a weighting between 0 and 100."].exists)
    alert.buttons["OK"].tap()

    guard selectAssignmentStep("Details", in: app) else { return }
    let weighting = element(app, id: "assignment.weighting")
    guard reach(weighting, in: app) else { return }
    replaceText(in: weighting, with: "25")
    guard dismissKeyboard("assignment.keyboardDone", in: app),
      selectAssignmentStep("Review", in: app)
    else { return }
    save.tap()
    XCTAssertTrue(alert.waitForExistence(timeout: 5))
    XCTAssertTrue(alert.staticTexts["Enter a positive total. If you enter a score, it must be between zero and the total."].exists)
    alert.buttons["OK"].tap()

    guard selectAssignmentStep("Feedback", in: app) else { return }
    let score = element(app, id: "assignment.score")
    guard reach(score, in: app) else { return }
    replaceText(in: score, with: "18")
    guard dismissKeyboard("assignment.keyboardDone", in: app),
      selectAssignmentStep("Review", in: app)
    else { return }
    save.tap()
    let savedAssignment = app.staticTexts[title].firstMatch
    guard reach(savedAssignment, in: app) else { return }
    savedAssignment.tap()
    guard reach(app.staticTexts["Grade: 18 / 20"], in: app) else { return }
    let actions = app.buttons["assignment.actions"]
    actions.tap()
    app.buttons["Delete assignment"].tap()
    cancelConfirmation("Delete this assignment?", in: app)
    XCTAssertTrue(app.navigationBars[title].exists)
    actions.tap()
    app.buttons["Delete assignment"].tap()
    app.sheets["Delete this assignment?"].buttons["Delete assignment"].tap()
    XCTAssertTrue(app.navigationBars["Subject"].waitForExistence(timeout: 5))
    XCTAssertFalse(savedAssignment.exists)

    let deleteSubject = app.buttons["Delete subject"]
    guard reach(deleteSubject, in: app) else { return }
    deleteSubject.tap()
    cancelConfirmation("Delete this subject and its assignments?", in: app)
    XCTAssertTrue(app.navigationBars["Subject"].exists)
    let sampleAssignment = app.staticTexts["Example assignment"]
    guard reach(sampleAssignment, in: app, up: false) else { return }
    guard reach(deleteSubject, in: app) else { return }
    deleteSubject.tap()
    app.sheets["Delete this subject and its assignments?"].buttons["Delete subject"].tap()
    XCTAssertTrue(app.navigationBars["My Learning"].waitForExistence(timeout: 5))
    XCTAssertFalse(subject.exists)
    app.tabBars.buttons["AI Mentor"].tap()
    XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Example assignment")).firstMatch.exists)
  }

  private func cancelConfirmation(_ title: String, in app: XCUIApplication) {
    let confirmation = app.sheets[title]
    XCTAssertTrue(confirmation.waitForExistence(timeout: 5))
    let cancel = app.buttons["Cancel"].firstMatch
    if cancel.exists && cancel.isHittable {
      cancel.tap()
    } else {
      // Anchored confirmation popovers on iOS can omit a Cancel button.
      let outside = app.otherElements["PopoverDismissRegion"]
      XCTAssertTrue(outside.exists)
      outside.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.5)).tap()
    }
    let dismissed = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "exists == false"), object: confirmation)
    XCTAssertEqual(XCTWaiter.wait(for: [dismissed], timeout: 5), .completed)
  }

  private func replaceText(in field: XCUIElement, with text: String) {
    field.tap()
    field.typeKey("a", modifierFlags: .command)
    field.typeText(text)
  }

  private func selectAssignmentStep(_ label: String, in app: XCUIApplication) -> Bool {
    let step = app.segmentedControls.buttons[label]
    guard reach(step, in: app, up: false) else { return false }
    step.tap()
    XCTAssertTrue(step.isSelected)
    return true
  }

  func testAlphaLandscapeNavigationAndComposer() {
    continueAfterFailure = false
    XCUIDevice.shared.orientation = .landscapeLeft
    defer { XCUIDevice.shared.orientation = .portrait }
    let app = XCUIApplication()
    app.launchArguments = ["-ui-smoke"]
    app.launch()
    let continueButton = app.buttons["profile.save"]
    XCTAssertTrue(continueButton.waitForExistence(timeout: 10))
    continueButton.tap()
    XCTAssertGreaterThan(app.frame.width, app.frame.height)
    let subjects = app.buttons["home.catalogue.subjects"]
    guard reach(subjects, in: app) else { return }
    subjects.tap()
    XCTAssertTrue(app.segmentedControls.buttons["Subjects"].isSelected)
    let addSubject = app.buttons["subject.add"]
    guard reach(addSubject, in: app) else { return }
    app.tabBars.buttons["AI Mentor"].tap()
    let newConversation = app.buttons["mentor.ask"]
    guard reach(newConversation, in: app) else { return }
    newConversation.tap()
    let input = element(app, id: "conversation.input")
    let send = app.buttons["conversation.send"]
    XCTAssertTrue(input.waitForExistence(timeout: 5))
    XCTAssertTrue(input.isHittable)
    XCTAssertFalse(send.isEnabled)
    input.tap()
    input.typeText("Study")
    XCTAssertTrue(app.keyboards.firstMatch.exists)
    XCTAssertTrue(input.isHittable)
    XCTAssertTrue(send.isHittable)
    let sources = app.buttons["conversation.sources"]
    XCTAssertTrue(sources.isHittable)
    let keyboard = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    keyboard.name = "Landscape Mentor composer and keyboard"
    keyboard.lifetime = .keepAlways
    add(keyboard)
    sources.tap()
    XCTAssertTrue(app.navigationBars["Add context"].waitForExistence(timeout: 5))
    let context = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    context.name = "Landscape Mentor source sheet"
    context.lifetime = .keepAlways
    add(context)
    app.navigationBars.buttons["Cancel"].tap()
    XCTAssertEqual(input.value as? String, "Study")
    XCTAssertFalse(element(app, id: "conversation.question.0").exists)
  }

  func testDocumentImportPDFAndScreenshots() throws {
    guard ProcessInfo.processInfo.environment["UNICOACH_RUN_DOCUMENT_IMPORT"] == "1" else {
      throw XCTSkip("Requires the three academic document fixtures copied to the app container.")
    }
    continueAfterFailure = false
    let app = XCUIApplication()
    let pdf = "Subject outline.pdf"
    let jpeg = "Canvas assessment.jpg"
    let png = "Subject screenshot.png"
    let subject = "Human-Centred Design Research Methods"
    let start = ProcessInfo.processInfo.environment["UNICOACH_DOCUMENT_IMPORT_START"] ?? "pdf"
    XCTAssertTrue(["pdf", "jpg", "png"].contains(start))
    let addSubject = app.buttons["subject.add"]
    let name = element(app, id: "documentImport.subject.name")

    if start == "pdf" {
      launchDocumentFixture(pdf, reset: true, in: app)
      let onboarding = app.buttons["profile.save"]
      XCTAssertTrue(onboarding.waitForExistence(timeout: 10))
      onboarding.tap()
      guard openDocumentImportSubjects(in: app) else { return }
      guard reach(addSubject, in: app) else { return }
      addSubject.tap()
      guard openDocumentReview(pdf, entry: "subject.importDocument", in: app) else { return }
      guard reach(name, in: app) else { return }
      XCTAssertEqual(name.value as? String, subject)
      XCTAssertEqual(element(app, id: "documentImport.subject.code").value as? String, "32405")
      XCTAssertEqual(element(app, id: "documentImport.subject.credits").value as? String, "6")
      XCTAssertEqual(element(app, id: "documentImport.subject.session").value as? String, "Spring Session 2026")
      for (title, weight) in [
        ("Quiz on subject", "10"), ("Poster on interviews", "30"),
        ("Short report on probe design", "10"), ("Presentation of analysis, short paper and video", "50"),
      ] {
        guard checkDocumentAssignment(title, weight: weight, due: "No due date", in: app) else { return }
      }
      attachScreenshot("PDF import review", app: app)
      app.buttons["documentImport.save"].tap()
      guard reach(app.staticTexts[subject].firstMatch, in: app) else { return }
    }

    if start != "png" {
      launchDocumentFixture(jpeg, reset: false, in: app)
      guard openDocumentImportSubjects(in: app) else { return }
      let savedSubject = app.staticTexts[subject].firstMatch
      guard reach(savedSubject, in: app) else { return }
      savedSubject.tap()
      let addAssignment = app.buttons["subject.addAssignment"]
      guard reach(addAssignment, in: app) else { return }
      addAssignment.tap()
      guard openDocumentReview(jpeg, entry: "assignment.importDocument", in: app) else { return }
      let apple = app.buttons["documentImport.appleSuggestions"]
      guard reach(apple, in: app) else { return }
      apple.tap()
      let approval = app.navigationBars["Approve source text"]
      XCTAssertTrue(approval.waitForExistence(timeout: 5))
      let text = element(app, id: "documentImport.appleText")
      XCTAssertTrue((text.value as? String ?? "").contains("Research synthesis memo"))
      let approve = app.buttons["documentImport.approveApple"]
      XCTAssertTrue(approve.isEnabled)
      approve.tap()
      let error = app.alerts["Apple suggestions"]
      let outcome = XCTNSPredicateExpectation(
        predicate: NSPredicate { _, _ in !approval.exists || error.exists }, object: nil)
      XCTAssertEqual(XCTWaiter.wait(for: [outcome], timeout: 90), .completed)
      if error.exists {
        XCTFail(error.staticTexts.allElementsBoundByIndex.map(\.label).joined(separator: " "))
        return
      }
      XCTAssertTrue(app.navigationBars["Review document"].exists)
      guard checkDocumentAssignment("Research synthesis memo", weight: "20", due: "20", in: app) else { return }
      let destination = element(app, id: "documentImport.destination")
      guard reach(destination, in: app, up: false) else { return }
      XCTAssertTrue((destination.label + " " + (destination.value as? String ?? "")).contains("32405"))
      XCTAssertEqual(element(app, id: "documentImport.updateSubject").value as? String, "0")
      attachScreenshot("JPG import review", app: app)
      app.buttons["documentImport.save"].tap()
      guard reach(app.staticTexts["Research synthesis memo"].firstMatch, in: app) else { return }
    }

    launchDocumentFixture(png, reset: false, in: app)
    guard openDocumentImportSubjects(in: app), reach(addSubject, in: app) else { return }
    addSubject.tap()
    guard openDocumentReview(png, entry: "subject.importDocument", in: app) else { return }
    guard reach(name, in: app) else { return }
    XCTAssertEqual(name.value as? String, "Interaction Prototyping")
    XCTAssertEqual(element(app, id: "documentImport.subject.code").value as? String, "55501")
    guard checkDocumentAssignment("Prototype walkthrough", weight: "40", due: "27", in: app) else { return }
    attachScreenshot("PNG import review", app: app)
    app.buttons["documentImport.save"].tap()
    let prototypeSubject = app.staticTexts["Interaction Prototyping"].firstMatch
    guard reach(prototypeSubject, in: app) else { return }
    prototypeSubject.tap()
    guard reach(app.staticTexts["Prototype walkthrough"].firstMatch, in: app) else { return }
  }

  private func launchDocumentFixture(_ filename: String, reset: Bool, in app: XCUIApplication) {
    if !reset { app.terminate() }
    app.launchArguments = [reset ? "-ui-smoke" : "-ui-smoke-preserve"]
    app.launchEnvironment["UNICOACH_DOCUMENT_FIXTURE"] = filename
    app.launch()
  }

  private func openDocumentImportSubjects(in app: XCUIApplication) -> Bool {
    let card = app.buttons["home.catalogue.subjects"]
    guard reach(card, in: app) else { return false }
    card.tap()
    XCTAssertTrue(app.segmentedControls.buttons["Subjects"].isSelected)
    return true
  }

  private func openDocumentReview(_ filename: String, entry: String, in app: XCUIApplication) -> Bool {
    let button = app.buttons[entry]
    guard reach(button, in: app) else { return false }
    button.tap()
    let files = app.buttons["documentImport.files"]
    XCTAssertTrue(files.waitForExistence(timeout: 5))
    files.tap()
    XCTAssertTrue(app.navigationBars["Review document"].waitForExistence(timeout: 20))
    let source = element(app, id: "documentImport.filename")
    guard reach(source, in: app) else { return false }
    XCTAssertTrue((source.label + " " + (source.value as? String ?? "")).contains(filename))
    return true
  }

  private func checkDocumentAssignment(
    _ title: String, weight: String, due: String, in app: XCUIApplication
  ) -> Bool {
    let row = app.buttons.matching(NSPredicate(
      format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "documentImport.assignment.", title
    )).firstMatch
    guard reach(row, in: app) else { return false }
    let summary = row.label + " " + (row.value as? String ?? "")
    XCTAssertTrue(summary.contains(weight + "% weighting"), summary)
    XCTAssertTrue(summary.contains(due), summary)
    if due != "No due date" { XCTAssertFalse(summary.contains("No due date"), summary) }
    return true
  }

  func testAlphaFileImport() throws {
    guard ProcessInfo.processInfo.environment["UNICOACH_ALPHA_IMPORT_FIXTURES"] == "1" else {
      throw XCTSkip("Requires the alpha Files fixtures and temporary file-sharing test build.")
    }
    continueAfterFailure = false
    let app = XCUIApplication()
    app.launchArguments = ["-ui-smoke"]
    app.launch()
    let continueButton = app.buttons["profile.save"]
    XCTAssertTrue(continueButton.waitForExistence(timeout: 10))
    continueButton.tap()
    app.tabBars.buttons["My Learning"].tap()
    let sample = app.buttons["subjects.sample"]
    guard reach(sample, in: app) else { return }
    sample.tap()
    app.swipeDown()
    let subject = app.staticTexts["Example subject"].firstMatch
    guard reach(subject, in: app) else { return }
    subject.tap()
    let assignment = app.staticTexts["Example assignment"].firstMatch
    guard reach(assignment, in: app) else { return }
    assignment.tap()
    app.buttons["assignment.actions"].tap()
    app.buttons["assignment.edit"].tap()

    let brief = app.textViews["Assignment brief"]
    guard reach(brief, in: app) else { return }
    let originalBrief = try XCTUnwrap(brief.value as? String)
    guard openAlphaImport("Import brief", in: app) else { return }
    cancelAlphaPicker(in: app)
    XCTAssertEqual(brief.value as? String, originalBrief)
    guard openAlphaImport("Import brief", in: app),
      selectAlphaFile("Alpha brief", in: app)
    else { return }
    let review = app.navigationBars["Review import"]
    let preview = try alphaImportPreview(containing: "Review marker: before edit.", in: app)
    replaceText(in: preview, with: "Discarded imported revision.")
    review.buttons["Cancel"].tap()
    XCTAssertEqual(brief.value as? String, originalBrief)

    guard openAlphaImport("Import brief", in: app),
      selectAlphaFile("Alpha brief", in: app)
    else { return }
    let reopenedPreview = try alphaImportPreview(containing: "Review marker: before edit.", in: app)
    let acceptedBrief = "Accepted revised brief about library study spaces."
    replaceText(in: reopenedPreview, with: acceptedBrief)
    review.buttons["Use text"].tap()
    XCTAssertEqual(brief.value as? String, acceptedBrief)

    for file in ["Alpha empty", "Alpha invalid UTF8", "Alpha oversized bytes", "Alpha oversized text", "Alpha scanned"] {
      guard openAlphaImport("Import brief", in: app), selectAlphaFile(file, in: app) else { return }
      let alert = app.alerts["Import"]
      XCTAssertTrue(alert.waitForExistence(timeout: 8), "Import should reject " + file)
      let message = alert.staticTexts.allElementsBoundByIndex.map(\.label)
        .filter { $0 != "Import" }.joined(separator: " ")
      if file.contains("oversized") {
        XCTAssertTrue(message.contains("too large"))
      } else if file == "Alpha empty" || file == "Alpha scanned" {
        XCTAssertTrue(message.contains("No selectable text was found"))
      } else {
        XCTAssertFalse(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      }
      XCTAssertFalse(review.exists)
      alert.buttons["OK"].tap()
      XCTAssertEqual(brief.value as? String, acceptedBrief)
    }

    guard openAlphaImport("Import brief", in: app) else { return }
    let unsupported = alphaPickerItem("Alpha unsupported", in: app)
    if unsupported.exists && unsupported.isEnabled {
      let scrolled = scrollToAlphaFile(unsupported, in: app)
      guard tapAlphaFile(unsupported, in: app, scrolled: scrolled) else { return }
      let alert = app.alerts["Import"]
      XCTAssertTrue(alert.waitForExistence(timeout: 8))
      XCTAssertTrue(alert.staticTexts["Choose a UTF-8 text file or selectable-text PDF."].exists)
      alert.buttons["OK"].tap()
      print("alpha_unsupported_file=rejected_by_app")
    } else {
      XCTAssertTrue(isInAlphaFixtureFolder(app))
      cancelAlphaPicker(in: app)
      print("alpha_unsupported_file=filtered_by_picker")
    }
    XCTAssertEqual(brief.value as? String, acceptedBrief)

    guard advanceAssignment(in: app),
      openAlphaImport("Import submitted work", in: app),
      selectAlphaFile("Alpha work", in: app)
    else { return }
    let workText = "Selectable PDF work fixture."
    _ = try alphaImportPreview(containing: workText, in: app)
    review.buttons["Use text"].tap()
    XCTAssertTrue((app.textViews["Submitted work"].value as? String ?? "").contains(workText))

    let reflectionMode = app.segmentedControls.buttons["All-in-one reflection"]
    guard reach(reflectionMode, in: app, up: false) else { return }
    reflectionMode.tap()
    guard openAlphaImport("Import reflection", in: app), selectAlphaFile("Alpha reflection", in: app) else { return }
    let reflectionText = "I will check for confounders before making a claim."
    let importedReflectionText = try alphaImportPreview(containing: reflectionText, in: app)
    XCTAssertEqual(importedReflectionText.value as? String, reflectionText)
    review.buttons["Use text"].tap()

    guard advanceAssignment(in: app),
      openAlphaImport("Import feedback", in: app),
      selectAlphaFile("Alpha feedback", in: app)
    else { return }
    let feedbackText = "Explain how your sample supports the claim."
    let importedFeedbackText = try alphaImportPreview(containing: feedbackText, in: app)
    XCTAssertEqual(importedFeedbackText.value as? String, feedbackText)
    review.buttons["Use text"].tap()
    guard advanceAssignment(in: app) else { return }
    app.buttons["editor.save"].tap()
    XCTAssertTrue(app.navigationBars["Example assignment"].waitForExistence(timeout: 5))
    for text in [reflectionText, workText, acceptedBrief, feedbackText] {
      let saved = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
      guard reach(saved, in: app) else { return }
    }
  }

  private func alphaImportPreview(containing text: String, in app: XCUIApplication) throws -> XCUIElement {
    XCTAssertTrue(app.navigationBars["Review import"].waitForExistence(timeout: 8))
    return try XCTUnwrap(app.textViews.allElementsBoundByIndex.first {
      ($0.value as? String ?? "").contains(text) && $0.isHittable
    }, "The import preview did not show the expected fixture text")
  }

  private func alphaPickerItem(_ name: String, in app: XCUIApplication) -> XCUIElement {
    app.cells.matching(NSPredicate(
      format: "label == %@ OR label BEGINSWITH %@ OR label BEGINSWITH %@",
      name, name + ",", name + "."
    )).firstMatch
  }

  private func isInAlphaFixtureFolder(_ app: XCUIApplication) -> Bool {
    app.otherElements["DOC.browsingRoot Source: com.apple.FileProvider.LocalStorage, Title: Alpha Fixtures"].exists
      || app.navigationBars["Alpha Fixtures"].exists
  }

  private func waitForAlphaFixtureFolder(_ app: XCUIApplication, timeout: TimeInterval) -> Bool {
    let visible = XCTNSPredicateExpectation(
      predicate: NSPredicate { _, _ in self.isInAlphaFixtureFolder(app) }, object: nil)
    return XCTWaiter.wait(for: [visible], timeout: timeout) == .completed
  }

  private func openAlphaImport(_ buttonName: String, in app: XCUIApplication) -> Bool {
    let button = app.buttons[buttonName]
    guard reach(button, in: app) else { return false }
    button.tap()
    if waitForAlphaFixtureFolder(app, timeout: 2) { return true }
    let browse = app.tabBars.buttons["Browse"].firstMatch
    if browse.exists && browse.isHittable { browse.tap() }
    let phone = alphaPickerItem("On My iPhone", in: app)
    if !phone.exists {
      let backToBrowse = app.navigationBars.buttons["Browse"].firstMatch
      if backToBrowse.exists && backToBrowse.isHittable { backToBrowse.tap() }
    }
    guard phone.waitForExistence(timeout: 8), phone.isHittable else {
      XCTFail("Could not open the local Files provider for the alpha fixtures")
      return false
    }
    phone.tap()
    for label in ["UniCoach", "Alpha Fixtures"] {
      let item = alphaPickerItem(label, in: app)
      guard item.waitForExistence(timeout: 5), item.isHittable else {
        XCTFail("Could not reach the temporary alpha fixture folder component " + label)
        return false
      }
      item.tap()
    }
    let visible = waitForAlphaFixtureFolder(app, timeout: 5)
    XCTAssertTrue(visible, "Could not open the local Alpha Fixtures directory")
    return visible
  }

  private func selectAlphaFile(_ filename: String, in app: XCUIApplication) -> Bool {
    XCTAssertTrue(isInAlphaFixtureFolder(app))
    let file = alphaPickerItem(filename, in: app)
    guard file.waitForExistence(timeout: 5) else {
      XCTFail("Synthetic fixture is not listed: " + filename)
      return false
    }
    let scrolled = scrollToAlphaFile(file, in: app)
    return tapAlphaFile(file, in: app, scrolled: scrolled)
  }

  private func tapAlphaFile(_ file: XCUIElement, in app: XCUIApplication, scrolled: Bool) -> Bool {
    guard isInAlphaFixtureFolder(app), file.isHittable, file.isEnabled else {
      XCTFail("The local synthetic fixture is not selectable")
      return false
    }
    let fileView = app.collectionViews["File View"]
    let thumbnail = file.images.firstMatch
    let navigationBar = app.navigationBars["FullDocumentManagerViewControllerNavigationBar"]
    let tabs = app.tabBars["DOC.browsingModeTabBar"]
    if scrolled, fileView.exists, fileView.value as? String == "Icon Mode", thumbnail.exists,
      navigationBar.exists, tabs.exists
    {
      let frame = thumbnail.frame
      let center = CGPoint(x: frame.midX, y: frame.midY)
      // In the Files grid the cell includes metadata and can extend under floating controls.
      if !frame.isEmpty && app.frame.contains(center)
        && center.y > navigationBar.frame.maxY && center.y < tabs.frame.minY
      {
        thumbnail.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        return assertAlphaPickerDismissed(in: app)
      }
    }
    file.tap()
    return assertAlphaPickerDismissed(in: app)
  }

  private func assertAlphaPickerDismissed(in app: XCUIApplication) -> Bool {
    let dismissed = XCTNSPredicateExpectation(
      predicate: NSPredicate { _, _ in !self.isInAlphaFixtureFolder(app) }, object: nil)
    let completed = XCTWaiter.wait(for: [dismissed], timeout: 5) == .completed
    XCTAssertTrue(completed, "The Files picker stayed open after the selected action")
    return completed
  }

  private func scrollToAlphaFile(_ file: XCUIElement, in app: XCUIApplication) -> Bool {
    guard !file.isHittable else { return false }
    let fileView = app.collectionViews["File View"]
    let list = fileView.exists ? fileView : app.collectionViews.firstMatch
    for _ in 0..<4 where !file.isHittable { list.swipeUp() }
    for _ in 0..<4 where !file.isHittable { list.swipeDown() }
    return true
  }

  private func cancelAlphaPicker(in app: XCUIApplication) {
    let currentPicker = app.navigationBars["FullDocumentManagerViewControllerNavigationBar"]
    let picker = currentPicker.exists ? currentPicker : app.navigationBars["Alpha Fixtures"]
    let cancel = picker.buttons["Cancel"]
    XCTAssertTrue(cancel.waitForExistence(timeout: 5))
    cancel.tap()
    guard assertAlphaPickerDismissed(in: app) else { return }
    XCTAssertTrue(app.navigationBars["Assignment"].exists)
  }

  func testMentorEvaluationReview() throws {
    guard ProcessInfo.processInfo.environment["UNICOACH_MENTOR_EVAL"] == "review" else {
      throw XCTSkip("Requires an isolated synthetic review fixture and the review evaluation mode.")
    }
    continueAfterFailure = false
    let app = alphaFixtureApp()
    try checkAlphaAssignmentReview(in: app, feedbackPrefix: nil, retainGoal: false)
  }

  func testMentorEvaluationChat() throws {
    let environment = ProcessInfo.processInfo.environment
    guard environment["UNICOACH_MENTOR_EVAL"] == "chat" else {
      throw XCTSkip("Requires an isolated synthetic chat fixture and the chat evaluation mode.")
    }
    continueAfterFailure = false
    let question = try XCTUnwrap(environment["UNICOACH_MENTOR_EVAL_QUESTION"])
    XCTAssertFalse(question.isEmpty)
    let followup = environment["UNICOACH_MENTOR_EVAL_FOLLOWUP"].flatMap { $0.isEmpty ? nil : $0 }
    let sourceKinds = environment["UNICOACH_MENTOR_EVAL_SOURCES"].map {
      $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    } ?? (environment["UNICOACH_MENTOR_EVAL_PAIR"] == "1" ? ["work", "feedback"] : [])
    let supportedSources = Set(["work", "feedback", "brief", "reflection", "guided-reflection"])
    XCTAssertEqual(Set(sourceKinds).count, sourceKinds.count)
    XCTAssertTrue(Set(sourceKinds).isSubset(of: supportedSources))
    let app = alphaFixtureApp()
    app.tabBars.buttons["AI Mentor"].tap()
    app.buttons["mentor.ask"].tap()
    try checkMentorEvaluationChat(
      messages: [question] + (followup.map { [$0] } ?? []), sourceKinds: sourceKinds,
      firstTurnIndex: 0, in: app)
  }

  func testMentorSemanticFollowups() throws {
    let mode = ProcessInfo.processInfo.environment["UNICOACH_MENTOR_FOLLOWUP_EVAL"]
    guard mode == "legacy" || mode == "live" else {
      throw XCTSkip("Requires the matching fictional follow-up fixture in the isolated smoke store.")
    }
    continueAfterFailure = false
    let app = alphaFixtureApp()
    app.tabBars.buttons["AI Mentor"].tap()
    let saved = app.buttons.matching(identifier: "mentor.conversation")
    if mode == "legacy" {
      guard reach(saved.firstMatch, in: app) else { return }
      XCTAssertEqual(saved.count, 1)
      saved.firstMatch.tap()
      let first = element(app, id: "conversation.question.0")
      guard reach(first, in: app, scrolling: app.scrollViews["conversation.transcript"], up: false) else { return }
      XCTAssertEqual(first.label, "My tutor liked my themes and ethics, but wants clearer evidence for each design requirement and a clearer distinction between participant observations and my interpretations. How should I improve?")
      let priorAnswer = element(app, id: "conversation.answer.0")
      XCTAssertEqual(priorAnswer.label, "Keep the clear themes and careful handling of participant notes. For the next revision, connect each proposed feature to an anonymised observation, label your interpretations separately, and explain how stale availability data could mislead students. Would you like a concrete sequence of revision steps?")
      XCTAssertFalse(element(app, id: "conversation.answer.1").exists)
      try checkMentorEvaluationChat(messages: ["Yes"], sourceKinds: [], firstTurnIndex: 1, in: app)
    } else {
      XCTAssertEqual(saved.count, 0, "Use a fresh copy of the fictional student fixture")
      app.buttons["mentor.ask"].tap()
      let messages = [
        "How did I do on this campus study-spaces report, and what should I improve for my next assignment?",
        "Turn that advice into three practical revision steps I can follow.",
        "Should I use the same approach for a statistics assignment about transport delays? Explain what I should keep and what I should change.",
        "Back to the campus report: I now have only 20 minutes in one session. Give me a revision plan that fits, prioritising the evidence behind the power-access requirement."
      ]
      try checkMentorEvaluationChat(
        messages: messages, sourceKinds: ["brief", "work", "feedback"], firstTurnIndex: 0, in: app)
    }
  }

  private func checkMentorEvaluationChat(
    messages: [String], sourceKinds: [String], firstTurnIndex: Int, in app: XCUIApplication
  ) throws {
    let availability = element(app, id: "conversation.availability")
    if availability.exists { throw XCTSkip(availability.label) }

    let sources = app.buttons["conversation.sources"]
    let input = element(app, id: "conversation.input")
    let send = app.buttons["conversation.send"]
    let transcript = app.scrollViews["conversation.transcript"]
    for (offset, message) in messages.enumerated() {
      let index = firstTurnIndex + offset
      XCTAssertEqual(sources.label, "Add context")
      enter(message, id: "conversation.input", in: app)
      guard dismissKeyboard("conversation.keyboardDone", in: app) else { return }
      XCTAssertEqual(input.value as? String, message)
      if offset == 0 && !sourceKinds.isEmpty {
        sources.tap()
        for kind in sourceKinds {
          chooseSwitch(element(app, id: "question.source.assignment:" + alphaAssignmentID + ":" + kind), in: app)
        }
        app.buttons["conversation.useSources"].tap()
        let selectionLabel = sourceKinds.count == 1 ? "1 source selected" : "\(sourceKinds.count) sources selected"
        XCTAssertEqual(sources.label, selectionLabel)
      }
      XCTAssertTrue(send.isEnabled)
      send.tap()
      let savedQuestion = element(app, id: "conversation.question.\(index)")
      let answer = element(app, id: "conversation.answer.\(index)")
      let alert = app.alerts["Mentor"]
      let outcome = XCTNSPredicateExpectation(
        predicate: NSPredicate { _, _ in answer.exists || alert.exists }, object: nil)
      XCTAssertEqual(XCTWaiter.wait(for: [outcome], timeout: 240), .completed)
      if alert.exists {
        let error = alert.staticTexts.allElementsBoundByIndex.map(\.label).joined(separator: "\n")
        let evidence = XCTAttachment(string: error)
        evidence.name = "Mentor evaluation chat turn \(index + 1) first attempt error"
        evidence.lifetime = .keepAlways
        add(evidence)
        print("mentor_eval_chat_turn_\(index + 1)=single_attempt_error")
        return
      }
      XCTAssertEqual(savedQuestion.label, message)
      let savedAnswer = answer.label
      XCTAssertFalse(savedAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      XCTAssertFalse(savedAnswer.contains(where: { "?？؟".contains($0) }), savedAnswer)
      XCTAssertFalse(send.isEnabled)
      print("mentor_eval_chat_turn_\(index + 1)=single_attempt_saved")
      attachScreenshot("Mentor evaluation chat turn \(index + 1)", app: app)
    }
    app.terminate()
    app.launch()
    app.tabBars.buttons["AI Mentor"].tap()
    let saved = app.buttons["mentor.conversation"]
    guard reach(saved, in: app) else { return }
    saved.tap()
    for (offset, message) in messages.enumerated().reversed() {
      let index = firstTurnIndex + offset
      let savedQuestion = element(app, id: "conversation.question.\(index)")
      guard reach(savedQuestion, in: app, scrolling: transcript, up: false) else { return }
      XCTAssertEqual(savedQuestion.label, message)
    }
  }

  func testAlphaBlindUnrelatedFeedback() throws {
    guard ProcessInfo.processInfo.environment["UNICOACH_ALPHA_MODEL_FIXTURE"] == "blind" else {
      throw XCTSkip("Requires the blind alpha fixture in the isolated smoke store.")
    }
    continueAfterFailure = false
    let app = alphaFixtureApp()
    let expected = "Calibrate the spectrophotometer before recording the titration volumes."
    try checkAlphaAssignmentReview(in: app, feedbackPrefix: expected, retainGoal: false)
  }

  func testAlphaGroundedAssignmentReview() throws {
    guard ProcessInfo.processInfo.environment["UNICOACH_ALPHA_MODEL_FIXTURE"] == "student" else {
      throw XCTSkip("Requires the student alpha fixture in the isolated smoke store.")
    }
    continueAfterFailure = false
    let app = alphaFixtureApp()
    let expected = "Your themes are clearly organised and your ethical handling"
    try checkAlphaAssignmentReview(in: app, feedbackPrefix: expected, retainGoal: true)
  }

  func testAlphaRetainedAppleConversation() throws {
    guard ProcessInfo.processInfo.environment["UNICOACH_ALPHA_MODEL_FIXTURE"] == "student" else {
      throw XCTSkip("Requires the student alpha fixture in the isolated smoke store.")
    }
    continueAfterFailure = false
    let app = alphaFixtureApp()
    app.tabBars.buttons["AI Mentor"].tap()
    app.buttons["mentor.ask"].tap()
    let availability = element(app, id: "conversation.availability")
    if availability.exists { throw XCTSkip(availability.label) }
    let question = "How can I turn my tutor’s comments on the campus study-space report into a practical revision plan before the prototype review?"
    let reply = "I have two 45-minute study sessions available. What should I prioritise in each, and what should I check at the end?"
    let input = element(app, id: "conversation.input")
    let sources = app.buttons["conversation.sources"]
    let send = app.buttons["conversation.send"]
    enter(question, id: "conversation.input", in: app)
    guard dismissKeyboard("conversation.keyboardDone", in: app) else { return }
    XCTAssertEqual(input.value as? String, question)
    sources.tap()
    for kind in ["work", "brief", "feedback", "reflection", "guided-reflection"] {
      chooseSwitch(element(app, id: "question.source.assignment:" + alphaAssignmentID + ":" + kind), in: app)
    }
    app.buttons["conversation.useSources"].tap()
    XCTAssertEqual(sources.label, "5 sources selected")
    send.tap()
    let first = element(app, id: "conversation.question.0")
    XCTAssertTrue(first.waitForExistence(timeout: 120), "The first approved Apple request did not save")
    XCTAssertEqual(first.label, question)
    XCTAssertEqual(sources.label, "Add context")
    XCTAssertFalse(send.isEnabled)

    enter(reply, id: "conversation.input", in: app)
    guard dismissKeyboard("conversation.keyboardDone", in: app) else { return }
    XCTAssertEqual(input.value as? String, reply)
    send.tap()
    let second = element(app, id: "conversation.question.1")
    XCTAssertTrue(second.waitForExistence(timeout: 120), "The approved Apple reply did not save")
    XCTAssertEqual(second.label, reply)
    XCTAssertFalse(send.isEnabled)
    attachScreenshot("Alpha student retained Apple conversation", app: app)

    app.terminate()
    app.launch()
    app.tabBars.buttons["AI Mentor"].tap()
    let saved = app.buttons["mentor.conversation"]
    XCTAssertTrue(saved.waitForExistence(timeout: 5))
    saved.tap()
    let transcript = app.scrollViews["conversation.transcript"]
    guard reach(second, in: app, scrolling: transcript) else { return }
    XCTAssertEqual(second.label, reply)
    guard reach(first, in: app, scrolling: transcript, up: false) else { return }
    XCTAssertEqual(first.label, question)
  }

  func testAlphaCalendarAcrossMonths() throws {
    guard ProcessInfo.processInfo.environment["UNICOACH_ALPHA_MODEL_FIXTURE"] == "student" else {
      throw XCTSkip("Requires the student alpha fixture in the isolated smoke store.")
    }
    continueAfterFailure = false
    let calendar = Calendar.current
    guard calendar.identifier == .gregorian else {
      throw XCTSkip("The calendar fixture uses Gregorian due dates.")
    }
    let fixtureMonth = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 11, day: 1)))
    let currentMonth = try XCTUnwrap(calendar.dateInterval(of: .month, for: Date())?.start)
    let offset = try XCTUnwrap(calendar.dateComponents([.month], from: currentMonth, to: fixtureMonth).month)
    guard abs(offset) <= 36 else {
      throw XCTSkip("Calendar fixture is more than 36 months from the device date.")
    }
    let app = alphaFixtureApp()
    let card = app.buttons["home.catalogue.assignments"]
    guard reach(card, in: app) else { return }
    card.tap()
    let heading = element(app, id: "assignments.calendar")
    guard reach(heading, in: app) else { return }
    let monthFormat = Date.FormatStyle(
      locale: .current, calendar: calendar, timeZone: calendar.timeZone
    ).month(.wide).year()
    XCTAssertEqual(heading.label, currentMonth.formatted(monthFormat))
    if offset != 0 {
      let direction = offset < 0 ? "previous" : "next"
      let move = app.buttons["assignments.calendar." + direction]
      guard reach(move, in: app) else { return }
      for _ in 0..<abs(offset) { move.tap() }
    }
    XCTAssertEqual(heading.label, fixtureMonth.formatted(monthFormat))
    let past = app.buttons["assignments.calendar.day.3"]
    guard reach(past, in: app) else { return }
    XCTAssertEqual(past.value as? String, "1 assignment due")
    let far = app.buttons["assignments.calendar.day.25"]
    guard reach(far, in: app) else { return }
    XCTAssertEqual(far.value as? String, "1 assignment due")
    let next = app.buttons["assignments.calendar.next"]
    guard reach(next, in: app, up: false) else { return }
    next.tap()
    let followingMonth = try XCTUnwrap(calendar.date(byAdding: .month, value: 1, to: fixtureMonth))
    XCTAssertEqual(heading.label, followingMonth.formatted(monthFormat))
    let december = app.buttons["assignments.calendar.day.2"]
    guard reach(december, in: app) else { return }
    XCTAssertEqual(december.value as? String, "1 assignment due")
    attachScreenshot("Alpha calendar dates beyond seven days", app: app)
    december.tap()
    let deadline = app.buttons.matching(NSPredicate(
      format: "identifier BEGINSWITH %@ AND label == %@",
      "assignments.calendar.assignment.", "Professional practice: individual reflection"
    )).firstMatch
    guard reach(deadline, in: app) else { return }
    deadline.tap()
    XCTAssertTrue(app.navigationBars["Professional practice: individual reflection"].waitForExistence(timeout: 5))
  }

  func testAlphaAdoptSavedReviewGoal() throws {
    guard ProcessInfo.processInfo.environment["UNICOACH_ALPHA_MODEL_FIXTURE"] == "student-saved-review" else {
      throw XCTSkip("Requires the isolated student fixture with a saved Apple review and an unadopted next step.")
    }
    continueAfterFailure = false
    let app = alphaFixtureApp()
    app.navigationBars.buttons["Profile"].tap()
    let history = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Study review")).firstMatch
    guard reach(history, in: app) else { return }
    history.tap()
    XCTAssertTrue(app.navigationBars["Your feedback review"].waitForExistence(timeout: 5))
    let create = app.buttons["goal.fromReport"]
    guard reach(create, in: app, attempts: 14) else { return }
    guard adoptAlphaReviewGoal(in: app, button: create) else { return }
    attachScreenshot("Alpha adopted goal linked to Apple review", app: app)

    app.terminate()
    app.launch()
    app.tabBars.buttons["My Progress"].tap()
    guard reach(alphaLinkedGoal(in: app), in: app, attempts: 14) else { return }
  }

  private func alphaLinkedGoal(in app: XCUIApplication) -> XCUIElement {
    app.buttons.matching(NSPredicate(
      format: "identifier BEGINSWITH %@ AND label CONTAINS %@",
      "progress.goal.", "From: " + alphaAssignmentTitle
    )).firstMatch
  }

  private func adoptAlphaReviewGoal(in app: XCUIApplication, button: XCUIElement) -> Bool {
    XCTAssertTrue(button.isEnabled, "The saved review must have an unadopted next step")
    button.tap()
    let created = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "label == %@", "Learning goal created"), object: button)
    XCTAssertEqual(XCTWaiter.wait(for: [created], timeout: 5), .completed)
    XCTAssertFalse(button.isEnabled)
    let progress = app.buttons["focus.progress"]
    guard reach(progress, in: app) else { return false }
    progress.tap()
    return reach(alphaLinkedGoal(in: app), in: app, attempts: 14)
  }

  func testAlphaPopulatedNormalLaunch() throws {
    guard ProcessInfo.processInfo.environment["UNICOACH_ALPHA_NORMAL_FIXTURE"] == "student" else {
      throw XCTSkip("Requires the populated fictional student fixture in the normal app store.")
    }
    continueAfterFailure = false
    let app = XCUIApplication()
    app.launch()
    XCTAssertTrue(app.staticTexts["Greetings, Jordan Lee"].waitForExistence(timeout: 10))
    XCTAssertFalse(app.buttons["profile.save"].exists)
    attachScreenshot("Populated student Home", app: app)

    app.navigationBars.buttons["Profile"].tap()
    XCTAssertTrue(app.staticTexts["Jordan Lee"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["University of Technology Sydney"].exists)
    XCTAssertTrue(app.staticTexts["Bachelor of Information Technology"].exists)
    let history = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Study review")).firstMatch
    guard reach(history, in: app) else { return }
    history.tap()
    XCTAssertTrue(app.navigationBars["Your feedback review"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["Apple on-device"].firstMatch.exists)
    attachScreenshot("Populated student saved feedback review", app: app)
    back("Profile", in: app)
    back("Home", in: app)

    let home = app.tabBars.buttons["Home"]
    let homeSearch = app.buttons.matching(NSPredicate(
      format: "label CONTAINS %@", "Search subjects and assignments"
    )).firstMatch
    guard reach(homeSearch, in: app) else { return }
    homeSearch.tap()
    XCTAssertTrue(app.segmentedControls.buttons["Subjects"].isSelected)
    let search = app.searchFields.firstMatch
    let searchButton = app.buttons["Search"].firstMatch
    if !search.exists && searchButton.exists && searchButton.isHittable { searchButton.tap() }
    guard reach(search, in: app, up: false, attempts: 4) else { return }
    search.tap()
    search.typeText("DAT202\n")
    let analytics = app.staticTexts["Applied Data Analytics"].firstMatch
    guard reach(analytics, in: app) else { return }
    XCTAssertFalse(app.staticTexts["Human-Centred Design"].exists)
    attachScreenshot("Populated student subject search by code", app: app)

    guard reach(search, in: app, up: false) else { return }
    replaceText(in: search, with: "no matching alpha subject\n")
    let noMatch = app.staticTexts["No matching subjects."]
    guard reach(noMatch, in: app) else { return }
    XCTAssertFalse(analytics.exists)
    guard reach(search, in: app, up: false) else { return }
    search.tap()
    let clearSearch = search.buttons["Clear text"]
    XCTAssertTrue(clearSearch.waitForExistence(timeout: 5))
    clearSearch.tap()
    let closeSearch = app.navigationBars["My Learning"].buttons.matching(NSPredicate(
      format: "label == %@ OR label == %@", "Close", "Cancel"
    )).firstMatch
    XCTAssertTrue(closeSearch.waitForExistence(timeout: 5))
    closeSearch.tap()
    let keyboardDismissed = XCTNSPredicateExpectation(
      predicate: NSPredicate(format: "exists == false"), object: app.keyboards.firstMatch)
    XCTAssertEqual(XCTWaiter.wait(for: [keyboardDismissed], timeout: 5), .completed)
    XCTAssertFalse(noMatch.exists)
    for name in ["Human-Centred Design", "Applied Data Analytics", "Software Engineering Practice"] {
      guard reach(app.staticTexts[name].firstMatch, in: app) else { return }
    }
    attachScreenshot("Populated student subjects", app: app)

    home.tap()
    let assignments = app.buttons["home.catalogue.assignments"]
    guard reach(assignments, in: app) else { return }
    assignments.tap()
    guard reach(app.staticTexts["All assignments (5)"], in: app) else { return }
    attachScreenshot("Populated student assignments", app: app)

    home.tap()
    let goals = app.buttons["home.catalogue.goals"]
    guard reach(goals, in: app) else { return }
    goals.tap()
    let studyGoal = app.buttons.matching(NSPredicate(
      format: "identifier BEGINSWITH %@ AND label CONTAINS %@",
      "learning.goal.", "Before the 18 November prototype review"
    )).firstMatch
    guard reach(studyGoal, in: app) else { return }
    attachScreenshot("Populated student goals", app: app)

    app.tabBars.buttons["My Progress"].tap()
    guard reach(app.staticTexts["Learning pathway status"], in: app) else { return }
    attachScreenshot("Populated student progress", app: app)

    app.tabBars.buttons["AI Mentor"].tap()
    let conversation = app.buttons["mentor.conversation"]
    guard reach(conversation, in: app) else { return }
    XCTAssertTrue(conversation.label.contains("campus study-space report"))
    conversation.tap()
    let transcript = app.scrollViews["conversation.transcript"]
    let second = element(app, id: "conversation.question.1")
    guard reach(second, in: app, scrolling: transcript) else { return }
    XCTAssertTrue(second.label.hasPrefix("I have two 45-minute study sessions available."))
    attachScreenshot("Populated student saved Mentor conversation", app: app)
  }

  private var alphaAssignmentID: String { "0C343040-899E-5F36-9F98-6DA2C86A6027" }
  private var alphaAssignmentTitle: String { "Campus study spaces: research report" }

  private func alphaFixtureApp() -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = ["-ui-smoke-preserve"]
    app.launch()
    XCTAssertTrue(app.tabBars.buttons["AI Mentor"].waitForExistence(timeout: 10))
    return app
  }

  private func checkAlphaAssignmentReview(
    in app: XCUIApplication, feedbackPrefix: String?, retainGoal: Bool
  ) throws {
    app.tabBars.buttons["AI Mentor"].tap()
    let assignment = app.buttons.matching(NSPredicate(
      format: "label CONTAINS %@", alphaAssignmentTitle
    )).firstMatch
    guard reach(assignment, in: app) else { return }
    assignment.tap()
    let sourcePrefix = "source.assignment:" + alphaAssignmentID + ":"
    chooseSwitch(element(app, id: sourcePrefix + "work"), in: app)
    chooseSwitch(element(app, id: sourcePrefix + "feedback"), in: app)
    XCTAssertEqual(element(app, id: sourcePrefix + "reflection").value as? String, "0")
    let work = app.textViews["Approved text for Submitted work"]
    let feedback = app.textViews["Approved text for Tutor feedback"]
    guard reach(work, in: app) else { return }
    let exactWork = try XCTUnwrap(work.value as? String)
    XCTAssertFalse(exactWork.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    if feedbackPrefix != nil {
      XCTAssertTrue(exactWork.hasPrefix("I interviewed three commuting students"))
    }
    guard reach(feedback, in: app) else { return }
    let exactFeedback = try XCTUnwrap(feedback.value as? String)
    XCTAssertFalse(exactFeedback.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    if let feedbackPrefix { XCTAssertTrue(exactFeedback.hasPrefix(feedbackPrefix)) }

    let availability = element(app, id: "mentor.availability")
    guard reach(availability, in: app) else { return }
    let approve = app.buttons["mentor.approve"]
    guard reach(approve, in: app) else { return }
    if availability.label != "Apple on-device model is available." {
      XCTAssertFalse(approve.isEnabled)
      throw XCTSkip(availability.label)
    }
    XCTAssertTrue(approve.isEnabled)
    approve.tap()
    let saved = app.buttons["mentor.savedReport"]
    let alert = app.alerts["Mentor"]
    let outcome = XCTNSPredicateExpectation(
      predicate: NSPredicate { _, _ in
        alert.exists || saved.exists
      }, object: nil)
    XCTAssertEqual(XCTWaiter.wait(for: [outcome], timeout: 240), .completed)
    if alert.exists {
      let message = alert.staticTexts.allElementsBoundByIndex.map(\.label).joined(separator: "\n")
      let result = XCTAttachment(string: message)
      result.name = "Single Apple assignment review result"
      result.lifetime = .keepAlways
      add(result)
      print("alpha_review_outcome=single_attempt_error")
      if retainGoal { XCTFail("Grounded Apple review did not save: " + message) }
      return
    }
    guard reach(saved, in: app) else { return }
    saved.tap()
    XCTAssertTrue(app.navigationBars["Your feedback review"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.staticTexts["Apple on-device"].firstMatch.exists)
    print("alpha_review_outcome=single_attempt_saved")
    attachScreenshot("Alpha Apple assignment review", app: app)

    if retainGoal {
      let nextStepOutcome = app.descendants(matching: .any).matching(NSPredicate(
        format: "identifier == %@ OR label == %@ OR label == %@",
        "goal.fromReport", "No specific next step was identified from the feedback.",
        "No supported keep doing finding in this review."
      )).firstMatch
      guard reach(nextStepOutcome, in: app, attempts: 14) else { return }
      if nextStepOutcome.identifier == "goal.fromReport" {
        guard adoptAlphaReviewGoal(in: app, button: nextStepOutcome) else { return }
        back("Your feedback review", in: app)
      }
    }

    let workSnapshot = element(app, id: "report.source.assignment:" + alphaAssignmentID + ":work")
    let feedbackSnapshot = element(app, id: "report.source.assignment:" + alphaAssignmentID + ":feedback")
    guard reach(workSnapshot, in: app, attempts: 14) else { return }
    XCTAssertEqual(workSnapshot.label, exactWork)
    guard reach(feedbackSnapshot, in: app) else { return }
    XCTAssertEqual(feedbackSnapshot.label, exactFeedback)
    let audit = element(app, id: "model.call.0")
    guard reach(audit, in: app) else { return }

    back("Review feedback", in: app)
    app.navigationBars.buttons["Close"].tap()
    app.navigationBars.buttons["Profile"].tap()
    guard reach(app.staticTexts["Report history"], in: app) else { return }
    let history = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Study review")).firstMatch
    guard reach(history, in: app) else { return }
    history.tap()
    XCTAssertTrue(app.navigationBars["Your feedback review"].waitForExistence(timeout: 5))
  }

}
