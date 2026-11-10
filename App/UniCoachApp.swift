import PDFKit
import SwiftUI
import UniCoachCore
import UniformTypeIdentifiers

let teal = Color(
  uiColor: UIColor { traits in
    traits.userInterfaceStyle == .dark
      ? UIColor(red: 0.66, green: 0.84, blue: 0.75, alpha: 1)
      : UIColor(red: 0.09, green: 0.24, blue: 0.20, alpha: 1)
  })
let lavender = Color(
  uiColor: UIColor { traits in
    traits.userInterfaceStyle == .dark
      ? UIColor(red: 0.14, green: 0.22, blue: 0.19, alpha: 1)
      : UIColor(red: 0.92, green: 0.96, blue: 0.94, alpha: 1)
  })
let canvasColor = Color(
  uiColor: UIColor { traits in
    traits.userInterfaceStyle == .dark
      ? UIColor.systemGroupedBackground : UIColor(red: 0.965, green: 0.969, blue: 0.961, alpha: 1)
  })

@main struct UniCoachApp: App {
  @State private var app = AppState()
  var body: some Scene { WindowGroup { RootView().environment(app).tint(teal) } }
}

@MainActor @Observable final class AppState {
  var store: UniCoachStore = {
    if ProcessInfo.processInfo.arguments.contains("-ui-smoke")
      || ProcessInfo.processInfo.arguments.contains("-ui-smoke-preserve")
    {
      let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("UniCoach/ui-smoke.json")
      if ProcessInfo.processInfo.arguments.contains("-ui-smoke") {
        try? FileManager.default.removeItem(at: url)
      }
      return UniCoachStore(fileURL: url)
    }
    return UniCoachStore()
  }()
  var error: String?
  init() { error = store.loadingError }
  var data: AppData { store.data }
  func perform(_ action: () throws -> Void) {
    do { try action() } catch { self.error = error.localizedDescription }
  }
}

enum LearningSection: String, CaseIterable {
  case overview = "Overview"
  case subjects = "Subjects"
  case assignments = "Assignments"
  case goals = "Goals"
}

enum AssignmentFeedbackFilter: String, CaseIterable {
  case all = "All assignments"
  case withFeedback = "With feedback"
}

enum LearningDestination: String {
  case subjects, assignments, feedback, goals

  var section: LearningSection {
    switch self {
    case .subjects: return .subjects
    case .assignments, .feedback: return .assignments
    case .goals: return .goals
    }
  }
}

struct RootView: View {
  private enum AppTab { case home, learning, progress, mentor }

  @Environment(AppState.self) private var app
  @State private var selectedTab: AppTab = .home
  @State private var learningSection: LearningSection = .overview
  @State private var assignmentFilter: AssignmentFeedbackFilter = .all
  @State private var learningStackID = UUID()

  var body: some View {
    TabView(selection: $selectedTab) {
      NavigationStack { HomeScreen(openLearning: openLearning).profileToolbar() }.tabItem {
        Label {
          Text("Home")
        } icon: {
          Image("NavHome").renderingMode(.template)
        }
      }.tag(AppTab.home)
      NavigationStack {
        SubjectsView(mode: $learningSection, assignmentFilter: $assignmentFilter).profileToolbar()
      }.id(learningStackID).tabItem {
        Label {
          Text("My Learning")
        } icon: {
          Image("NavLearning").renderingMode(.template)
        }
      }.tag(AppTab.learning)
      NavigationStack { ProgressScreen().profileToolbar() }.tabItem {
        Label {
          Text("My Progress")
        } icon: {
          Image("NavProgress").renderingMode(.template)
        }
      }.tag(AppTab.progress)
      NavigationStack { MentorLanding().profileToolbar() }.tabItem {
        Label {
          Text("AI Mentor")
        } icon: {
          Image("NavCoach").renderingMode(.template)
        }
      }.tag(AppTab.mentor)
    }
    .sheet(isPresented: Binding(get: { !app.data.profile.onboardingComplete }, set: { _ in })) {
      ProfileEditor(profile: app.data.profile, onboarding: true).interactiveDismissDisabled()
    }
    .alert(
      "Could not save",
      isPresented: Binding(get: { app.error != nil }, set: { if !$0 { app.error = nil } })
    ) {
      Button("OK") { app.error = nil }
    } message: {
      Text(app.error ?? "")
    }
  }

  private func openLearning(_ destination: LearningDestination) {
    learningSection = destination.section
    assignmentFilter = destination == .feedback ? .withFeedback : .all
    // Home cards always open the named catalogue from its root and across all semesters.
    learningStackID = UUID()
    selectedTab = .learning
  }
}

struct SubjectsView: View {
  @Environment(AppState.self) private var app
  @Environment(\.horizontalSizeClass) private var sizeClass
  @State private var editing: Subject?
  @State private var newAssignment: Assignment?
  @State private var query = ""
  @State private var filter = "All"
  @Binding var mode: LearningSection
  @Binding var assignmentFilter: AssignmentFeedbackFilter
  @State private var semester = "All semesters"
  private var semesters: [String] {
    Array(Set(app.data.subjects.compactMap(\.semester).filter { !$0.isEmpty })).sorted()
  }
  private var scoped: [Subject] {
    app.data.subjects.filter { semester == "All semesters" || $0.semester == semester }
  }
  private var realSubjects: [Subject] { scoped.filter { !$0.isDemo } }
  private var assignments: [Assignment] {
    app.data.assignments.filter { item in
      !item.isDemo && realSubjects.contains { $0.id == item.subjectID }
    }
  }
  private var goals: [LearningGoal] {
    app.data.goals.filter { goal in
      !goal.isDemo
        && (goal.subjectID.map { id in realSubjects.contains { $0.id == id } }
          ?? (semester == "All semesters"))
    }
  }
  private var catalogueGoals: [LearningGoal] {
    app.data.goals.filter { goal in
      !goal.isDemo && (semester == "All semesters"
        || goal.subjectID == nil
        || realSubjects.contains { $0.id == goal.subjectID })
    }
  }
  private var filtered: [Subject] {
    scoped.filter { subject in
      let matches =
        query.isEmpty || subject.name.localizedStandardContains(query)
        || subject.code.localizedStandardContains(query)
        || app.data.assignments.contains {
          $0.subjectID == subject.id && $0.title.localizedStandardContains(query)
        }
      let fits =
        filter == "All"
        || (filter == "With feedback"
          ? app.data.assignments.contains {
            $0.subjectID == subject.id && !$0.tutorFeedback.isEmpty
          } : app.data.goals.contains { $0.subjectID == subject.id })
      return matches && fits
    }
  }
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        VStack(alignment: .leading, spacing: 6) {
          Text(app.data.profile.course.isEmpty ? "Your degree" : app.data.profile.course).font(
            .title2.bold())
          Text(
            app.data.profile.university.isEmpty
              ? "Add your university in Profile" : app.data.profile.university
          ).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(20).background(
          lavender, in: RoundedRectangle(cornerRadius: 24))
        Picker("Learning view", selection: $mode) {
          ForEach(LearningSection.allCases, id: \.self) { section in
            Text(section.rawValue).tag(section)
          }
        }.pickerStyle(.segmented)
        Picker("Semester", selection: $semester) {
          Text("All semesters").tag("All semesters")
          ForEach(semesters, id: \.self) { Text($0).tag($0) }
        }.pickerStyle(.menu)
        switch mode {
        case .overview:
          LearningOverview(realSubjects: realSubjects, assignments: assignments, goals: goals)
        case .subjects:
          LearningSubjectList(
            realSubjects: realSubjects, assignments: assignments, filtered: filtered, filter: $filter,
            addSubject: { editing = Subject(colorHex: "#287C76") })
        case .assignments:
          AssignmentsDashboard(
            subjects: realSubjects, assignments: assignments, query: query, feedbackFilter: $assignmentFilter
          ) { selectedID in
            if let id = selectedID ?? realSubjects.first?.id {
              newAssignment = Assignment(subjectID: id, dueDate: nil)
            }
          }
        case .goals:
          LearningGoalsDashboard(goals: catalogueGoals)
        }
        if app.data.subjects.isEmpty && (mode == .overview || mode == .subjects) {
          ContentUnavailableView(
            "No subjects yet", systemImage: "books.vertical",
            description: Text("Add a subject to start organising your work."))
          if mode == .overview {
            Button("Add subject", systemImage: "plus") {
              editing = Subject(colorHex: "#287C76")
            }.buttonStyle(.borderedProminent).accessibilityIdentifier("subject.add")
          }
          Button("Add sample subject") {
            app.perform {
              _ = try app.store.addSampleSubject()
              mode = .subjects
            }
          }.accessibilityIdentifier("subjects.sample").accessibilityHint(
            "Creates clearly labelled synthetic sample data")
        }
      }.padding().frame(maxWidth: 1200)
    }.background(canvasColor).searchable(text: $query, prompt: "Search subjects or assignments")
      .onChange(of: query) { _, value in if !value.isEmpty && mode == .overview { mode = .subjects } }
      .navigationTitle("My Learning")
      .sheet(item: $editing) { SubjectEditor(subject: $0) }
      .sheet(item: $newAssignment) { AssignmentEditor(assignment: $0) }
  }

}

func subjectColor(_ hex: String) -> Color {
  let value =
    UInt64(hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted), radix: 16) ?? 0x287C76
  return Color(
    red: Double((value >> 16) & 255) / 255, green: Double((value >> 8) & 255) / 255,
    blue: Double(value & 255) / 255)
}

struct SubjectEditor: View {
  @Environment(AppState.self) private var app
  @Environment(\.dismiss) private var dismiss
  @Environment(\.locale) private var locale
  @State private var subject: Subject
  @State private var creditsDraft: String?
  @State private var invalidCredits = false
  let colors = ["#287C76", "#526EA3", "#A3664C", "#806395", "#A58435"]
  init(subject: Subject) {
    _subject = State(initialValue: subject)
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Subject") {
          Image("SubjectBookHero").resizable().scaledToFit().frame(maxWidth: .infinity, maxHeight: 130).accessibilityHidden(true)
          TextField("Name", text: $subject.name).accessibilityIdentifier("subject.name")
          TextField("Code", text: $subject.code).accessibilityIdentifier("subject.code")
          TextField("Credits", text: Binding(
            get: { creditsDraft ?? subject.credits.formatted(.number.locale(locale)) },
            set: { creditsDraft = $0 }
          )).keyboardType(.decimalPad).accessibilityIdentifier("subject.credits")
          TextField("Tutor", text: $subject.tutor)
        }
        Section("Subject description") {
          TextEditor(text: $subject.description).frame(minHeight: 90)
            .accessibilityLabel("Subject description")
            .accessibilityIdentifier("subject.description")
        }
        Section("Semester") {
          TextField(
            "Semester (optional)",
            text: Binding(
              get: { subject.semester ?? "" }, set: { subject.semester = $0.isEmpty ? nil : $0 })
          ).accessibilityIdentifier("subject.semester")
        }
        Section("Colour") {
          Picker("Colour", selection: $subject.colorHex) {
            ForEach(colors, id: \.self) { color in
              HStack {
                Circle().fill(subjectColor(color)).frame(width: 20, height: 20)
                Text(
                  [
                    "#287C76": "Teal", "#526EA3": "Blue", "#A3664C": "Terracotta",
                    "#806395": "Lavender", "#A58435": "Gold",
                  ][color] ?? "Colour")
              }.tag(color)
            }
          }
        }
      }.navigationTitle(subject.name.isEmpty ? "New subject" : "Edit subject")
        .navigationBarTitleDisplayMode(.inline).toolbar {
          ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
          ToolbarItem(placement: .confirmationAction) {
            Button("Save", action: saveSubject)
              .accessibilityIdentifier("editor.save").disabled(
              subject.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
          }
        }
        .alert("Invalid credits", isPresented: $invalidCredits) {
          Button("OK", role: .cancel) {}
        } message: {
          Text(UniCoachError.invalidCredits.localizedDescription)
        }
    }
  }

  private func saveSubject() {
    let credits: Double?
    if let creditsDraft {
      credits = parseCredits(creditsDraft)
    } else {
      credits = subject.credits
    }
    guard let credits, credits.isFinite, credits >= 0 else {
      invalidCredits = true
      return
    }
    subject.credits = credits
    app.perform {
      try app.store.upsertSubject(subject)
      dismiss()
    }
  }

  private func parseCredits(_ input: String) -> Double? {
    let value = input.trimmingCharacters(in: .whitespacesAndNewlines)
    if value.isEmpty { return 0 }

    // Foundation can parse a valid numeric prefix and ignore invalid trailing text.
    // Check the full input before using the locale's grouping and decimal rules.
    let parts = value.components(separatedBy: locale.decimalSeparator ?? ".")
    guard parts.count <= 2 else { return nil }
    let groups = parts[0].components(separatedBy: locale.groupingSeparator ?? ",")
    guard groups.count == 1 || groups.allSatisfy({ !$0.isEmpty }) else { return nil }
    let digits = (groups + Array(parts.dropFirst())).joined()
    guard !digits.isEmpty, digits.allSatisfy({ digit in
      digit.wholeNumberValue.map { (0...9).contains($0) } == true
    }) else { return nil }

    let format = FloatingPointFormatStyle<Double>.number.locale(locale)
    return try? FloatingPointParseStrategy(format: format, lenient: false).parse(value)
  }
}

struct SubjectDetail: View {
  @Environment(AppState.self) private var app
  @Environment(\.dismiss) private var dismiss
  let subjectID: UUID
  @State private var editing: Subject?
  @State private var assignment: Assignment?
  @State private var gradeFilter = "All"
  @State private var goal: LearningGoal?
  @State private var deletingGoal: LearningGoal?
  @State private var deleting = false
  var subject: Subject? { app.data.subjects.first { $0.id == subjectID } }
  var body: some View {
    Group {
      if let subject {
        List {
          Section {
            VStack(alignment: .leading, spacing: 6) {
              Text(subject.code).font(.caption.bold()).foregroundStyle(teal)
              Text(subject.name).font(.title2.bold())
              if !subject.description.isEmpty { Text(subject.description).foregroundStyle(.secondary) }
              if subject.isDemo {
                Text("Synthetic sample").font(.caption).foregroundStyle(.secondary)
              }
              Text(
                "\(subject.credits.formatted()) credits  •  \(subject.tutor.isEmpty ? "No tutor added" : subject.tutor)"
              ).foregroundStyle(.secondary)
              if let semester = subject.semester, !semester.isEmpty {
                Text(semester).foregroundStyle(.secondary)
              }
              let marks = app.store.subjectMarks(subjectID: subjectID, includeDemo: subject.isDemo)
              if let percentage = marks.percentage {
                Text(
                  "\(percentage.formatted(.number.precision(.fractionLength(2))))% • \(marks.score.formatted()) of \(marks.outOf.formatted()) marks graded"
                ).accessibilityIdentifier("subject.marks")
              }
            }.padding(.vertical, 8)
          }
          Section {
            Picker("Assignments", selection: $gradeFilter) {
              Text("All").tag("All")
              Text("Graded").tag("Graded")
              Text("With feedback").tag("With feedback")
            }.pickerStyle(.segmented)
            ForEach(
              app.data.assignments.filter {
                $0.subjectID == subjectID
                  && (gradeFilter == "All"
                    || (gradeFilter == "Graded"
                      ? $0.grade != nil
                      : !$0.tutorFeedback.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
              }
            ) { item in
              NavigationLink {
                AssignmentDetail(assignmentID: item.id)
              } label: {
                VStack(alignment: .leading) {
                  Text(item.title).font(.headline)
                  Text(
                    (item.dueDate.map { "Due \($0.formatted(date: .abbreviated, time: .omitted))" }
                      ?? "No due date")
                      + (item.grade.map { "  •  \($0.formatted())%" } ?? "")
                  ).font(.subheadline).foregroundStyle(.secondary)
                }
              }
            }
            Button {
              assignment = Assignment(subjectID: subjectID, isDemo: subject.isDemo)
            } label: {
              Label("Add assignment", systemImage: "plus")
            }.accessibilityIdentifier("subject.addAssignment")
          } header: {
            Text("Assignments")
          }
          Section("Goals") {
            ForEach(app.data.goals.filter { $0.subjectID == subjectID && !$0.isCompleted }) {
              item in
              Button {
                var updated = item
                updated.isCompleted.toggle()
                app.perform { try app.store.upsertGoal(updated) }
              } label: {
                Label(
                  item.title, systemImage: item.isCompleted ? "checkmark.circle.fill" : "circle")
              }.accessibilityIdentifier("subject.goal." + item.id.uuidString).accessibilityValue(
                item.isCompleted ? "Completed" : "Not completed"
              ).swipeActions {
                Button("Delete", role: .destructive) { deletingGoal = item }
                Button("Edit") { goal = item }.tint(.blue)
              }
            }
            Button {
              goal = LearningGoal(subjectID: subjectID, isDemo: subject.isDemo)
            } label: {
              Label("Add goal", systemImage: "plus")
            }
          }
          Section { Button("Delete subject", role: .destructive) { deleting = true } }
        }.navigationTitle("Subject").navigationBarTitleDisplayMode(.inline).toolbar {
          Button("Edit") { editing = subject }.accessibilityIdentifier("subject.edit")
        }.sheet(item: $editing) { SubjectEditor(subject: $0) }.sheet(item: $assignment) {
          AssignmentEditor(assignment: $0)
        }.sheet(item: $goal) { GoalEditor(goal: $0) }.confirmationDialog(
          "Delete this subject and its assignments?", isPresented: $deleting,
          titleVisibility: .visible
        ) {
          Button("Delete subject", role: .destructive) {
            app.perform {
              try app.store.deleteSubject(id: subjectID)
              dismiss()
            }
          }
        }.confirmationDialog(
          "Delete this goal?",
          isPresented: Binding(
            get: { deletingGoal != nil }, set: { if !$0 { deletingGoal = nil } }),
          titleVisibility: .visible
        ) {
          Button("Delete goal", role: .destructive) {
            if let deletingGoal {
              app.perform { try app.store.deleteGoal(id: deletingGoal.id) }
              self.deletingGoal = nil
            }
          }
        }
      } else {
        ContentUnavailableView("Subject unavailable", systemImage: "books.vertical")
      }
    }
  }
}

struct GoalEditor: View {
  @Environment(AppState.self) private var app
  @Environment(\.dismiss) private var dismiss
  @State var goal: LearningGoal
  var body: some View {
    NavigationStack {
      Form {
        TextField("Goal", text: $goal.title).accessibilityIdentifier("goal.title")
        Toggle("Completed", isOn: $goal.isCompleted)
      }.navigationTitle("Learning goal").toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
            app.perform {
              try app.store.upsertGoal(goal)
              dismiss()
            }
          }.accessibilityIdentifier("goal.save")
            .disabled(goal.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
      }
    }
  }
}

struct LearningActionsCard: View {
  @Environment(AppState.self) private var app
  let goals: [LearningGoal]
  var body: some View {
    DashboardCard(title: "Key actions") {
      let open = goals.filter { !$0.isCompleted }
      if open.isEmpty { Text("No open learning goals.").foregroundStyle(.secondary) }
      ForEach(open.prefix(3)) { goal in
        Button {
          var updated = goal
          updated.isCompleted = true
          app.perform { try app.store.upsertGoal(updated) }
        } label: {
          Label(goal.title, systemImage: "circle")
        }.buttonStyle(.plain)
      }
    }
  }
}

struct LearningDeadlinesCard: View {
  let assignments: [Assignment]
  var body: some View {
    DashboardCard(title: "Upcoming deadlines") {
      let upcoming = assignments.filter { ($0.dueDate ?? .distantPast) >= Date() }.sorted {
        ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture)
      }
      if upcoming.isEmpty { Text("No upcoming deadlines entered.").foregroundStyle(.secondary) }
      ForEach(upcoming.prefix(3)) { item in
        NavigationLink {
          AssignmentDetail(assignmentID: item.id)
        } label: {
          HStack(spacing: 12) {
            if let date = item.dueDate {
              VStack {
                Text(date.formatted(.dateTime.day())).font(.headline)
                Text(date.formatted(.dateTime.month(.abbreviated))).font(.caption)
              }
              .frame(width: 48, height: 48).background(
                lavender, in: RoundedRectangle(cornerRadius: 12))
            }
            Text(item.title)
          }
        }.buttonStyle(.plain)
      }
    }
  }
}

struct LearningOverview: View {
  @Environment(\.horizontalSizeClass) private var sizeClass
  let realSubjects: [Subject]
  let assignments: [Assignment]
  let goals: [LearningGoal]
  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      Text("Your learning journey").font(
        .custom("Inter-Regular", size: 24, relativeTo: .title2).weight(.semibold))
      LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
        StatCard(
          title: "Subjects", value: "\(realSubjects.count)", symbol: "BookIcon",
          color: Color(red: 0.85, green: 0.92, blue: 0.89))
        StatCard(
          title: "Assignments", value: "\(assignments.count)", symbol: "CalendarIcon",
          color: Color(red: 0.89, green: 0.85, blue: 0.93))
        StatCard(
          title: "With feedback",
          value: "\(assignments.filter { !$0.tutorFeedback.isEmpty }.count)",
          symbol: "FeedbackIcon", color: Color(red: 0.96, green: 0.92, blue: 0.82))
        StatCard(
          title: "Goals completed", value: "\(goals.filter(\.isCompleted).count) of \(goals.count)",
          symbol: "GoalIcon", color: Color(red: 0.87, green: 0.91, blue: 0.89))
      }
      if sizeClass == .regular {
        HStack(alignment: .top, spacing: 20) {
          LearningProgressCard(realSubjects: realSubjects)
          VStack(spacing: 20) {
            LearningActionsCard(goals: goals)
            LearningDeadlinesCard(assignments: assignments)
          }.frame(maxWidth: 400)
        }
      } else {
        LearningProgressCard(realSubjects: realSubjects)
        LearningActionsCard(goals: goals)
        LearningDeadlinesCard(assignments: assignments)
      }
    }
  }
}

struct LearningProgressCard: View {
  @Environment(AppState.self) private var app
  let realSubjects: [Subject]
  var body: some View {
    DashboardCard(title: "Subject progress") {
      HStack {
        Text("See the marks you have entered so far.").foregroundStyle(.secondary)
        Spacer()
        Image("OverviewIllustration").resizable().scaledToFit().frame(width: 120)
          .accessibilityHidden(true)
      }
      if realSubjects.isEmpty {
        Text("Add a subject to see its progress.").foregroundStyle(.secondary)
      }
      ForEach(Array(realSubjects.enumerated()), id: \.element.id) { index, subject in
        let marks = app.store.subjectMarks(subjectID: subject.id)
        NavigationLink {
          SubjectDetail(subjectID: subject.id)
        } label: {
          HStack(spacing: 12) {
            Text("\(index + 1)").font(.caption.bold()).foregroundStyle(.black).frame(
              width: 32, height: 32
            ).background(Color(red: 0.85, green: 0.92, blue: 0.89), in: Circle())
            VStack(alignment: .leading, spacing: 6) {
              Text(subject.name)
              if let percentage = marks.percentage {
                ProgressView(value: percentage, total: 100).tint(teal)
              }
            }
            Text(
              marks.percentage.map { "\($0.formatted(.number.precision(.fractionLength(2))))%" }
                ?? "No marks"
            ).font(.caption)
          }
        }.buttonStyle(.plain)
      }
    }
  }
}

struct LearningSubjectList: View {
  @Environment(AppState.self) private var app
  let realSubjects: [Subject]
  let assignments: [Assignment]
  let filtered: [Subject]
  @Binding var filter: String
  let addSubject: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      LearningSectionHeader(title: "Subjects", addTitle: "Add subject", addID: "subject.add", onAdd: addSubject)
      LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 12)], spacing: 12) {
        DashboardCard(title: "Your subject performance") {
          Text("\(realSubjects.count)").font(
            .custom("Inter-Regular", size: 34, relativeTo: .largeTitle).weight(.bold))
          Text("Subjects in this selection").font(.caption).foregroundStyle(.secondary)
        }
        DashboardCard(title: "Marks at a glance") {
          Text("\(assignments.filter { $0.percentage != nil }.count) of \(assignments.count)").font(
            .title2.bold())
          Text("Assignments with marks entered").font(.caption).foregroundStyle(.secondary)
        }
      }
      Text("Marks are weighted within each subject by their available points.").font(.caption)
        .foregroundStyle(.secondary)
      Picker("Filter", selection: $filter) {
        Text("All").tag("All")
        Text("With feedback").tag("With feedback")
        Text("With goals").tag("With goals")
      }.pickerStyle(.menu)
      LearningArtBanner(
        title: "Take action", subtitle: "Review your subjects and add missing details when you are ready.",
        imageName: "SubjectActionHero")
      DashboardCard(title: "Subjects") {
        if filtered.isEmpty && !app.data.subjects.isEmpty {
          Text("No matching subjects.").foregroundStyle(.secondary)
        }
        ForEach(filtered) { subject in
          let marks = app.store.subjectMarks(subjectID: subject.id, includeDemo: subject.isDemo)
          NavigationLink {
            SubjectDetail(subjectID: subject.id)
          } label: {
            HStack(spacing: 14) {
              RoundedRectangle(cornerRadius: 5).fill(subjectColor(subject.colorHex)).frame(width: 8)
              VStack(alignment: .leading, spacing: 4) {
                Text(subject.name).font(.headline)
                Text("\(subject.code)\(subject.isDemo ? " • Sample" : "")").font(.caption)
                  .foregroundStyle(.secondary)
              }
              Spacer()
              VStack(alignment: .trailing, spacing: 4) {
                Text(
                  marks.percentage.map { "\($0.formatted(.number.precision(.fractionLength(2))))%" }
                    ?? "Awaiting marks"
                )
                .font(.caption).padding(.horizontal, 10).padding(.vertical, 5).background(
                  lavender, in: Capsule())
                let total = app.data.assignments.filter { $0.subjectID == subject.id }.count
                Text("\(marks.gradedCount) of \(total) graded").font(.caption2).foregroundStyle(
                  .secondary)
                if total > 0 {
                  ProgressView(value: Double(marks.gradedCount), total: Double(total)).tint(teal)
                    .frame(width: 80)
                }
              }
            }.padding(.vertical, 6)
          }.buttonStyle(.plain)
        }
      }
    }
  }
}


struct AssignmentsDashboard: View {
  @Environment(AppState.self) private var app
  let subjects: [Subject]
  let assignments: [Assignment]
  let query: String
  @Binding var feedbackFilter: AssignmentFeedbackFilter
  let addAssignment: (UUID?) -> Void
  @State private var selectedSubject: UUID?
  @State private var latestFirst = false

  private var visible: [Assignment] {
    assignments.filter { item in
      (selectedSubject == nil || item.subjectID == selectedSubject)
        && (feedbackFilter == .all || !item.tutorFeedback.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        && (query.isEmpty || item.title.localizedStandardContains(query)
          || subjects.contains { $0.id == item.subjectID && ($0.name.localizedStandardContains(query) || $0.code.localizedStandardContains(query)) })
    }.sorted { left, right in
      let a = left.dueDate ?? .distantFuture, b = right.dueDate ?? .distantFuture
      if left.dueDate == nil && right.dueDate != nil { return false }
      if left.dueDate != nil && right.dueDate == nil { return true }
      if a == b { return left.title.localizedStandardCompare(right.title) == .orderedAscending }
      return latestFirst ? a > b : a < b
    }
  }
  private var graded: [Assignment] { visible.filter { $0.score != nil && $0.outOf != nil } }
  private var percentage: Double? {
    let score = graded.compactMap(\.score).reduce(0, +)
    let total = graded.compactMap(\.outOf).reduce(0, +)
    return total > 0 ? score / total * 100 : nil
  }
  private var reflectedCount: Int {
    visible.filter(\.hasReflection).count
  }
  private var analysedCount: Int {
    visible.filter { item in app.data.reports.contains { $0.assignmentID == item.id && $0.engine == .appleOnDevice } }.count
  }
  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      LearningSectionHeader(
        title: "Assignments", addTitle: "Add assignment", addID: "assignments.add",
        addDisabled: subjects.isEmpty, onAdd: { addAssignment(selectedSubject) })
      Picker("Subject", selection: $selectedSubject) {
        Text("All subjects").tag(Optional<UUID>.none)
        ForEach(subjects) { subject in Text(subject.name).tag(Optional(subject.id)) }
      }.accessibilityIdentifier("assignments.subjectFilter")
      Picker("Feedback", selection: $feedbackFilter) {
        ForEach(AssignmentFeedbackFilter.allCases, id: \.self) { filter in
          Text(filter.rawValue).tag(filter)
        }
      }.accessibilityIdentifier("assignments.feedbackFilter")
      LearningArtBanner(
        title: selectedSubject == nil ? "Your assignments" : "Subject assignments",
        subtitle: "Review your work, feedback and upcoming dates.", imageName: "AssignmentsHero")
      LearningArtBanner(
        title: selectedSubject == nil ? "Overall insights" : "Subject insights",
        subtitle: "Track the details, reflections and feedback you have entered.",
        imageName: selectedSubject == nil ? "AssignmentOverviewHero" : "AssignmentSubjectHero")
      DashboardCard(title: "Assignment performance") {
        if let percentage {
          Text("\(percentage.formatted(.number.precision(.fractionLength(1))))%")
            .font(.title.bold()).foregroundStyle(teal)
          Text("Based on \(graded.count) graded assignments and their available marks.").font(.caption).foregroundStyle(.secondary)
        } else { Text("No marks entered yet.").foregroundStyle(.secondary) }
      }
      AssignmentCalendar(assignments: visible)
      Text("Assignment progress").font(.title3.bold())
      LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
        StatCard(title: "Details", value: "\(visible.filter { !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !$0.brief.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count) / \(visible.count)", symbol: "CalendarIcon", color: Color(red: 0.85, green: 0.92, blue: 0.89))
        StatCard(title: "Reflection", value: "\(reflectedCount) / \(visible.count)", symbol: "GoalIcon", color: Color(red: 0.89, green: 0.85, blue: 0.93))
        StatCard(title: "Feedback", value: "\(visible.filter { !$0.tutorFeedback.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count) / \(visible.count)", symbol: "FeedbackIcon", color: Color(red: 0.96, green: 0.92, blue: 0.82))
        StatCard(title: "AI analysis", value: "\(analysedCount) / \(visible.count)", symbol: "BookIcon", color: Color(red: 0.87, green: 0.91, blue: 0.89))
      }
      DashboardCard(title: feedbackFilter == .all
        ? "All assignments (\(visible.count))" : "Assignments with feedback (\(visible.count))")
      {
        Toggle("Latest due date first", isOn: $latestFirst)
        if visible.isEmpty { Text("No assignments in this selection.").foregroundStyle(.secondary) }
        ForEach(visible) { item in
          NavigationLink { AssignmentDetail(assignmentID: item.id) } label: {
            HStack {
              VStack(alignment: .leading, spacing: 3) {
                Text(item.title).font(.headline)
                Text(subjects.first(where: { $0.id == item.subjectID })?.name ?? "Subject unavailable").font(.caption).foregroundStyle(.secondary)
                Text(item.dueDate.map { "Due \($0.formatted(date: .abbreviated, time: .omitted))" } ?? "No due date").font(.caption)
              }
              Spacer()
              Text(item.percentage != nil ? "Graded" : (!item.submittedWork.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Work added" : "Details only"))
                .font(.caption).foregroundStyle(.secondary)
            }.padding(.vertical, 6)
          }.buttonStyle(.plain)
        }
      }
    }
    .onChange(of: subjects.map(\.id)) { _, ids in
      if let selectedSubject, !ids.contains(selectedSubject) { self.selectedSubject = nil }
    }
  }
}


private struct LearningSectionHeader: View {
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  let title: String
  let addTitle: String
  let addID: String
  var addDisabled = false
  let onAdd: () -> Void

  var body: some View {
    let layout = dynamicTypeSize.isAccessibilitySize
      ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
      : AnyLayout(HStackLayout())
    layout {
      Text(title).font(.custom("Inter-Regular", size: 24, relativeTo: .title2).weight(.semibold))
        .accessibilityAddTraits(.isHeader)
      if !dynamicTypeSize.isAccessibilitySize { Spacer() }
      Button(addTitle, systemImage: "plus", action: onAdd)
        .buttonStyle(.borderedProminent)
        .disabled(addDisabled)
        .accessibilityIdentifier(addID)
    }
  }
}

private struct LearningGoalsDashboard: View {
  @Environment(AppState.self) private var app
  @State private var editingGoal: LearningGoal?
  @State private var deletingGoal: LearningGoal?
  let goals: [LearningGoal]

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      LearningSectionHeader(title: "Goals", addTitle: "Add goal", addID: "goals.add") {
        editingGoal = LearningGoal()
      }
      DashboardCard(title: "Learning goals") {
        if goals.isEmpty {
          Text("No learning goals in this selection.").foregroundStyle(.secondary)
        }
        ForEach(goals) { goal in
          HStack(alignment: .top, spacing: 12) {
            Button {
              var updated = goal
              updated.isCompleted.toggle()
              app.perform { try app.store.upsertGoal(updated) }
            } label: {
              LearningGoalLabel(goal: goal)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("learning.goal." + goal.id.uuidString)
            .accessibilityValue(goal.isCompleted ? "Completed" : "Not completed")
            Menu {
              Button("Edit goal", systemImage: "pencil") { editingGoal = goal }
              Button("Delete goal", systemImage: "trash", role: .destructive) { deletingGoal = goal }
            } label: {
              Label("Actions for " + goal.title, systemImage: "ellipsis.circle")
                .labelStyle(.iconOnly)
                .frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityIdentifier("learning.goal.actions." + goal.id.uuidString)
          }
        }
      }
    }
    .sheet(item: $editingGoal) { GoalEditor(goal: $0) }
    .confirmationDialog(
      "Delete this goal?",
      isPresented: Binding(get: { deletingGoal != nil }, set: { if !$0 { deletingGoal = nil } }),
      titleVisibility: .visible
    ) {
      Button("Delete goal", role: .destructive) {
        if let deletingGoal { app.perform { try app.store.deleteGoal(id: deletingGoal.id) } }
        deletingGoal = nil
      }
    }
  }
}

private struct AssignmentCalendar: View {
  @Environment(\.calendar) private var calendar
  @Environment(\.locale) private var locale
  @State private var displayedMonth = Date()
  @State private var selectedDate = Date()
  let assignments: [Assignment]

  private var dueByDay: [Date: [Assignment]] {
    assignments.reduce(into: [:]) { result, assignment in
      if let dueDate = assignment.dueDate {
        result[calendar.startOfDay(for: dueDate), default: []].append(assignment)
      }
    }
  }

  var body: some View {
    let due = dueByDay
    let selectedDay = due[calendar.startOfDay(for: selectedDate)] ?? []
    DashboardCard(title: "Academic calendar") {
      HStack {
        Button("Previous month", systemImage: "chevron.backward") { moveMonth(by: -1) }
          .labelStyle(.iconOnly)
          .frame(minWidth: 44, minHeight: 44)
          .accessibilityIdentifier("assignments.calendar.previous")
        Spacer(minLength: 4)
        Text(displayedMonth, format: monthFormat)
          .font(.headline)
          .multilineTextAlignment(.center)
          .accessibilityIdentifier("assignments.calendar")
        Spacer(minLength: 4)
        Button("Next month", systemImage: "chevron.forward") { moveMonth(by: 1) }
          .labelStyle(.iconOnly)
          .frame(minWidth: 44, minHeight: 44)
          .accessibilityIdentifier("assignments.calendar.next")
      }
      let symbols = calendar.veryShortStandaloneWeekdaySymbols
      let count = symbols.count
      if count > 0, let monthStart = calendar.dateInterval(of: .month, for: displayedMonth)?.start,
        let days = calendar.range(of: .day, in: .month, for: monthStart)
      {
        let firstColumn = (calendar.component(.weekday, from: monthStart) - calendar.firstWeekday + count) % count
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 0), spacing: 1), count: count), spacing: 3) {
          ForEach(0..<count, id: \.self) { column in
            Text(symbols[(column + calendar.firstWeekday - 1) % count])
              .font(.caption.bold()).foregroundStyle(.secondary)
              .accessibilityHidden(true)
          }
          ForEach(0..<firstColumn, id: \.self) { _ in
            Color.clear.accessibilityHidden(true)
          }
          ForEach(Array(days.enumerated()), id: \.element) { offset, day in
            if let date = calendar.date(byAdding: .day, value: offset, to: monthStart) {
              let count = due[calendar.startOfDay(for: date), default: []].count
              AssignmentCalendarDay(
                number: day, dateLabel: date.formatted(dayFormat), assignmentCount: count,
                isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                select: { selectedDate = date })
            }
          }
        }
      }
      Text("Marked dates have assignments due.").font(.caption).foregroundStyle(.secondary)
      Text(selectedDate, format: dayFormat).font(.headline)
      if selectedDay.isEmpty {
        Text("No assignments due on this day.").foregroundStyle(.secondary)
      }
      ForEach(selectedDay) { assignment in
        NavigationLink(assignment.title) { AssignmentDetail(assignmentID: assignment.id) }
          .accessibilityIdentifier("assignments.calendar.assignment." + assignment.id.uuidString)
      }
    }
  }

  private var monthFormat: Date.FormatStyle {
    Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone).month(.wide).year()
  }

  private var dayFormat: Date.FormatStyle {
    Date.FormatStyle(date: .complete, time: .omitted, locale: locale, calendar: calendar, timeZone: calendar.timeZone)
  }

  private func moveMonth(by offset: Int) {
    guard let start = calendar.dateInterval(of: .month, for: displayedMonth)?.start,
      let next = calendar.date(byAdding: .month, value: offset, to: start)
    else { return }
    displayedMonth = next
    selectedDate = next
  }
}

private struct AssignmentCalendarDay: View {
  let number: Int
  let dateLabel: String
  let assignmentCount: Int
  let isSelected: Bool
  let select: () -> Void

  var body: some View {
    Button(action: select) {
      VStack(spacing: 3) {
        Text(number, format: .number).font(.subheadline.monospacedDigit())
          .lineLimit(1).minimumScaleFactor(0.65)
        Circle().fill(assignmentCount > 0 ? teal : .clear).frame(width: 6, height: 6)
      }
      .frame(maxWidth: .infinity, minHeight: 44)
      .background(isSelected ? lavender : .clear, in: .rect(cornerRadius: 10))
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .accessibilityLabel(dateLabel)
    .accessibilityValue(assignmentCount == 1 ? "1 assignment due" : "\(assignmentCount) assignments due")
    .accessibilityAddTraits(isSelected ? .isSelected : [])
    .accessibilityIdentifier("assignments.calendar.day.\(number)")
  }
}

/// The supplied artwork includes its own mint background and right-aligned illustration.
struct LearningArtBanner: View {
  let title: String
  let subtitle: String
  let imageName: String
  var body: some View {
    HStack {
      VStack(alignment: .leading, spacing: 8) {
        Text(title).font(.headline)
        Text(subtitle).font(.caption)
      }
      .foregroundStyle(Color(red: 0.09, green: 0.24, blue: 0.20))
      .frame(maxWidth: 190, alignment: .leading)
      Spacer(minLength: 0)
    }
    .padding(20)
    .frame(maxWidth: .infinity, minHeight: 150, alignment: .leading)
    .background {
      GeometryReader { geometry in
        ZStack {
          Image(imageName).resizable().scaledToFill()
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .trailing)
            .clipped()
          LinearGradient(
            stops: [
              .init(color: Color(red: 0.89, green: 0.96, blue: 0.93), location: 0),
              .init(color: Color(red: 0.89, green: 0.96, blue: 0.93).opacity(0.9), location: 0.48),
              .init(color: .clear, location: 0.76),
            ], startPoint: .leading, endPoint: .trailing)
        }.accessibilityHidden(true)
      }
    }
    .clipShape(RoundedRectangle(cornerRadius: 20))
  }
}
