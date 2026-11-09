import FoundationModels
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

struct RootView: View {
  @Environment(AppState.self) private var app
  var body: some View {
    TabView {
      NavigationStack { HomeScreen().profileToolbar() }.tabItem {
        Label {
          Text("Home")
        } icon: {
          Image("NavHome").renderingMode(.template)
        }
      }
      NavigationStack { SubjectsView().profileToolbar() }.tabItem {
        Label {
          Text("My Learning")
        } icon: {
          Image("NavLearning").renderingMode(.template)
        }
      }
      NavigationStack { ProgressScreen().profileToolbar() }.tabItem {
        Label {
          Text("My Progress")
        } icon: {
          Image("NavProgress").renderingMode(.template)
        }
      }
      NavigationStack { MentorLanding().profileToolbar() }.tabItem {
        Label {
          Text("AI Mentor")
        } icon: {
          Image("NavCoach").renderingMode(.template)
        }
      }
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
}

struct SubjectsView: View {
  @Environment(AppState.self) private var app
  @Environment(\.horizontalSizeClass) private var sizeClass
  @State private var editing: Subject?
  @State private var query = ""
  @State private var filter = "All"
  @State private var mode: String
  @State private var semester = "All semesters"
  init(startInSubjects: Bool = false) {
    _mode = State(initialValue: startInSubjects ? "Subjects" : "Overview")
  }
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
  private var filtered: [Subject] {
    scoped.filter { subject in
      let matches =
        query.isEmpty || subject.name.localizedCaseInsensitiveContains(query)
        || subject.code.localizedCaseInsensitiveContains(query)
        || app.data.assignments.contains {
          $0.subjectID == subject.id && $0.title.localizedCaseInsensitiveContains(query)
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
          Text("Overview").tag("Overview")
          Text("Subjects").tag("Subjects")
        }.pickerStyle(.segmented)
        Picker("Semester", selection: $semester) {
          Text("All semesters").tag("All semesters")
          ForEach(semesters, id: \.self) { Text($0).tag($0) }
        }.pickerStyle(.menu)
        if mode == "Overview" { overview } else { subjectList }
        if app.data.subjects.isEmpty {
          ContentUnavailableView(
            "No subjects yet", systemImage: "books.vertical",
            description: Text("Add a subject to start organising your work."))
          Button("Add sample subject") {
            app.perform {
              _ = try app.store.addSampleSubject()
              mode = "Subjects"
            }
          }.accessibilityIdentifier("subjects.sample").accessibilityHint(
            "Creates clearly labelled synthetic sample data")
        }
      }.padding().frame(maxWidth: 1200)
    }.background(canvasColor).searchable(text: $query, prompt: "Search subjects or assignments")
      .onChange(of: query) { _, value in if !value.isEmpty { mode = "Subjects" } }
      .navigationTitle("My Learning").toolbar {
        Button {
          editing = Subject(colorHex: "#287C76")
        } label: {
          Label("Add subject", systemImage: "plus")
        }.accessibilityIdentifier("subject.add")
      }.sheet(item: $editing) { SubjectEditor(subject: $0) }
  }
  private var overview: some View {
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
          progressCard
          VStack(spacing: 20) {
            actionsCard
            deadlinesCard
          }.frame(maxWidth: 400)
        }
      } else {
        progressCard
        actionsCard
        deadlinesCard
      }
    }
  }
  private var progressCard: some View {
    learningCard("Subject progress") {
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
  private var actionsCard: some View {
    learningCard("Key actions") {
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
  private var deadlinesCard: some View {
    learningCard("Upcoming deadlines") {
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
  private var subjectList: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Subjects").font(
        .custom("Inter-Regular", size: 24, relativeTo: .title2).weight(.semibold))
      LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 12)], spacing: 12) {
        learningCard("Your subject performance") {
          Text("\(realSubjects.count)").font(
            .custom("Inter-Regular", size: 34, relativeTo: .largeTitle).weight(.bold))
          Text("Subjects in this selection").font(.caption).foregroundStyle(.secondary)
        }
        learningCard("Marks at a glance") {
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
      learningCard("Subjects") {
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
  private func learningCard<Content: View>(_ title: String, @ViewBuilder content: () -> Content)
    -> some View
  {
    VStack(alignment: .leading, spacing: 14) {
      Text(title).font(.custom("Inter-Regular", size: 20, relativeTo: .title3).weight(.semibold))
      content()
    }
    .frame(maxWidth: .infinity, alignment: .leading).padding(20).background(
      .background, in: RoundedRectangle(cornerRadius: 24))
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
  @State var subject: Subject
  let colors = ["#287C76", "#526EA3", "#A3664C", "#806395", "#A58435"]
  var body: some View {
    NavigationStack {
      Form {
        Section("Subject") {
          TextField("Name", text: $subject.name).accessibilityIdentifier("subject.name")
          TextField("Code", text: $subject.code).accessibilityIdentifier("subject.code")
          TextField("Credits", value: $subject.credits, format: .number).keyboardType(.decimalPad)
          TextField("Tutor", text: $subject.tutor)
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
            Button("Save") {
              app.perform {
                try app.store.upsertSubject(subject)
                dismiss()
              }
            }.accessibilityIdentifier("editor.save").disabled(
              subject.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
          }
        }
    }
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
        TextField("Goal", text: $goal.title)
        Toggle("Completed", isOn: $goal.isCompleted)
      }.navigationTitle("Learning goal").toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
            app.perform {
              try app.store.upsertGoal(goal)
              dismiss()
            }
          }.disabled(goal.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
      }
    }
  }
}
