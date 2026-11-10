import XCTest

final class UniCoachUITests: XCTestCase {
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

    let firstQuestion = "Can you help me plan my study time? Please ask me one question about my schedule."
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

    let reply = "I can study for 30 minutes on weekdays. Can you make the plan fit?"
    enter(reply, id: "conversation.input", in: app)
    guard dismissKeyboard("conversation.keyboardDone", in: app) else { return }
    XCTAssertTrue(send.isEnabled)
    send.tap()
    let second = element(app, id: "conversation.question.1")
    XCTAssertTrue(send.waitForExistence(timeout: 90), "Apple reply did not save: \(app.debugDescription)")
    guard reach(second, in: app, scrolling: transcript) else { return }
    XCTAssertEqual(second.label, reply)
    XCTAssertFalse(send.isEnabled)
    attachScreenshot("Second saved Apple mentor turn", app: app)

    let secondDetails = element(app, id: "conversation.request.1")
    guard reach(secondDetails, in: app, scrolling: transcript) else { return }
    secondDetails.tap()
    guard reach(answer, in: app) else { return }
    XCTAssertFalse(answer.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    guard reach(prompt, in: app) else { return }
    XCTAssertEqual(
      prompt.label,
      "Approved conversation:\n\(expectedHistory)\n\nQuestion:\n\(reply)\n\nNo additional source context was included.")
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

}
