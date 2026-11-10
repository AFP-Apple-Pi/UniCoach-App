import Charts
import SwiftUI
import UniCoachCore

struct ProfileScreen: View {
  @Environment(AppState.self) private var app
  @State private var editing = false
  @State private var deletingReport: MentorReport?
  var body: some View {
    List {
      Section {
        VStack(alignment: .leading, spacing: 8) {
          Text(app.data.profile.name.isEmpty ? "Your profile" : app.data.profile.name).font(
            .title2.bold())
          Text(app.data.profile.university).foregroundStyle(.secondary)
          Text(app.data.profile.course).foregroundStyle(.secondary)
        }.padding(.vertical, 8)
      }
      Section("Privacy") {
        Text(
          "Your data and mentor requests stay on this device. Imported files are reviewed before use."
        )
      }
      Section("Report history") {
        if app.data.reports.isEmpty { Text("No reports yet.").foregroundStyle(.secondary) }
        ForEach(app.data.reports) { report in
          NavigationLink {
            ReportDetail(report: report)
          } label: {
            VStack(alignment: .leading) {
              Text(report.question.isEmpty ? "Study review" : report.question)
              Text(
                "\(report.engine.displayName) • \(report.createdAt.formatted(date: .abbreviated, time: .shortened))"
              ).font(.caption).foregroundStyle(.secondary)
            }
          }.swipeActions { Button("Delete", role: .destructive) { deletingReport = report } }
        }
      }
    }.confirmationDialog(
      "Delete this report?",
      isPresented: Binding(
        get: { deletingReport != nil }, set: { if !$0 { deletingReport = nil } }),
      titleVisibility: .visible
    ) {
      Button("Delete report", role: .destructive) {
        if let deletingReport {
          app.perform { try app.store.deleteReport(id: deletingReport.id) }
          self.deletingReport = nil
        }
      }
    }.navigationTitle("Profile").toolbar { Button("Edit") { editing = true } }.sheet(
      isPresented: $editing
    ) { ProfileEditor(profile: app.data.profile, onboarding: false) }
  }
}
struct ProfileEditor: View {
  @Environment(AppState.self) private var app
  @Environment(\.dismiss) private var dismiss
  @State var profile: AcademicProfile
  let onboarding: Bool
  var body: some View {
    NavigationStack {
      Form {
        if onboarding {
          Section {
            VStack(alignment: .leading, spacing: 8) {
              Text("Welcome to UniCoach").font(.title2.bold())
              Text("A private space to reflect, organise your work and plan your next step.")
                .foregroundStyle(.secondary)
            }.padding(.vertical)
          }
        }
        Section("Academic profile") {
          TextField("Name", text: $profile.name)
          TextField("University", text: $profile.university)
          TextField("Course", text: $profile.course)
        }
        if onboarding {
          Text("All fields are optional and can be changed later.").font(.caption).foregroundStyle(
            .secondary)
        }
      }.navigationTitle(onboarding ? "Get started" : "Edit profile").toolbar {
        if !onboarding {
          ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button(onboarding ? "Continue" : "Save") {
            profile.onboardingComplete = true
            app.perform {
              try app.store.saveProfile(profile)
              dismiss()
            }
          }.accessibilityIdentifier("profile.save")
        }
      }
    }
  }
}
struct ProgressScreen: View {
  @Environment(AppState.self) private var app
  @State private var selectedSubject: UUID?
  @State private var editingGoal: LearningGoal?
  @State private var deletingGoal: LearningGoal?

  private var subjects: [Subject] { app.data.subjects.filter { !$0.isDemo } }
  private var goals: [LearningGoal] {
    app.data.goals.filter {
      !$0.isDemo && (selectedSubject == nil || $0.subjectID == selectedSubject)
    }
  }
  private var groups: [String] {
    Array(
      Set(
        subjects.map {
          semesterName($0.semester)
        })
    ).sorted()
  }
  private var allGrades: [Assignment] {
    subjects.filter { selectedSubject == nil || $0.id == selectedSubject }
      .flatMap { app.store.gradedAssignments(subjectID: $0.id) }
      .sorted { lhs, rhs in
        switch (lhs.chartDate, rhs.chartDate) {
        case (let left?, let right?):
          return left == right ? lhs.id.uuidString < rhs.id.uuidString : left < right
        case (_?, nil): return true
        case (nil, _?): return false
        case (nil, nil): return lhs.id.uuidString < rhs.id.uuidString
        }
      }
  }
  private var datedGrades: [Assignment] { allGrades.filter { $0.chartDate != nil } }
  var body: some View {
    List {
      Section {
        Picker("Subject", selection: $selectedSubject) {
          Text("All subjects").tag(Optional<UUID>.none)
          ForEach(subjects) { subject in Text(subject.name).tag(Optional(subject.id)) }
        }
      }
      Section("Your progress") {
        LabeledContent("Subjects", value: "\(selectedSubject == nil ? subjects.count : 1)")
        LabeledContent(
          "Goals completed", value: "\(goals.filter(\.isCompleted).count) of \(goals.count)")
        let relevant = app.data.assignments.filter {
          !$0.isDemo && (selectedSubject == nil || $0.subjectID == selectedSubject)
        }
        LabeledContent(
          "Reflections",
          value:
            "\(relevant.filter { !$0.reflection.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count) of \(relevant.count)"
        )
      }
      ForEach(groups, id: \.self) { semester in
        Section(semester) {
          ForEach(
            subjects.filter {
              semesterName($0.semester) == semester
                && (selectedSubject == nil || $0.id == selectedSubject)
            }
          ) { subject in
            let marks = app.store.subjectMarks(subjectID: subject.id)
            NavigationLink {
              SubjectDetail(subjectID: subject.id)
            } label: {
              VStack(alignment: .leading, spacing: 4) {
                Text(subject.name).font(.headline)
                if let percentage = marks.percentage {
                  Text(
                    "\(percentage.formatted(.number.precision(.fractionLength(2))))% • \(marks.score.formatted()) of \(marks.outOf.formatted()) marks graded so far"
                  ).font(.caption).foregroundStyle(.secondary)
                } else {
                  Text("No marks entered").font(.caption).foregroundStyle(.secondary)
                }
              }
            }
          }
        }
      }
      Section("Grades over time") {
        if datedGrades.isEmpty {
          Text("No dated grades yet.").foregroundStyle(.secondary)
        } else {
          Chart(datedGrades) { item in
            BarMark(
              x: .value("Assignment", item.id.uuidString),
              y: .value("Percentage", item.percentage ?? 0)
            )
            .foregroundStyle(teal).accessibilityLabel(item.title).accessibilityValue(
              "\((item.percentage ?? 0).formatted()) percent")
          }.chartXAxis(.hidden).chartYScale(domain: 0...100).frame(height: 180)
          Text(
            "Ordered by due date, or creation date when due date is missing. Undated records are not charted."
          ).font(.caption).foregroundStyle(.secondary)
          ForEach(datedGrades) { item in
            LabeledContent(
              item.title,
              value: "\((item.percentage ?? 0).formatted(.number.precision(.fractionLength(2))))%")
          }
        }
      }
      if allGrades.contains(where: { $0.chartDate == nil }) {
        Section("Grades without a date") {
          ForEach(allGrades.filter { $0.chartDate == nil }) { item in
            LabeledContent(
              item.title,
              value: "\((item.percentage ?? 0).formatted(.number.precision(.fractionLength(2))))%")
          }
        }
      }
      Section("Learning goals") {
        if goals.isEmpty { Text("No learning goals yet.").foregroundStyle(.secondary) }
        ForEach(goals) { item in goalRow(item) }
        Button {
          editingGoal = LearningGoal(subjectID: selectedSubject)
        } label: {
          Label("Add goal", systemImage: "plus")
        }
      }
      let samples = app.data.goals.filter(\.isDemo)
      if !samples.isEmpty {
        Section("Sample practice") { ForEach(samples) { item in goalRow(item) } }
      }
    }
    .navigationTitle("My Progress")
    .sheet(item: $editingGoal) { GoalEditor(goal: $0) }
    .confirmationDialog(
      "Delete this goal?",
      isPresented: Binding(get: { deletingGoal != nil }, set: { if !$0 { deletingGoal = nil } }),
      titleVisibility: .visible
    ) {
      Button("Delete goal", role: .destructive) {
        if let deletingGoal {
          app.perform { try app.store.deleteGoal(id: deletingGoal.id) }
          self.deletingGoal = nil
        }
      }
    }
  }
  @ViewBuilder private func goalRow(_ goal: LearningGoal) -> some View {
    Button {
      var updated = goal
      updated.isCompleted.toggle()
      app.perform { try app.store.upsertGoal(updated) }
    } label: {
      VStack(alignment: .leading, spacing: 4) {
        Label(goal.title, systemImage: goal.isCompleted ? "checkmark.circle.fill" : "circle")
        if let subjectID = goal.subjectID {
          Text(app.data.subjects.first { $0.id == subjectID }?.name ?? "Former subject").font(
            .caption
          ).foregroundStyle(.secondary)
        }
        if let assignmentID = goal.originAssignmentID {
          Text(
            "From: "
              + (app.data.assignments.first { $0.id == assignmentID }?.title ?? "Former assignment")
          )
          .font(.caption).foregroundStyle(.secondary)
        }
        if let status = goal.legacyFocusStatus {
          Text("Previously reported: " + legacyStatusLabel(status)).font(.caption).foregroundStyle(
            .secondary)
        }
      }
    }.accessibilityIdentifier("progress.goal." + goal.id.uuidString).accessibilityValue(
      goal.isCompleted ? "Completed" : "Not completed"
    ).swipeActions {
      Button("Delete", role: .destructive) { deletingGoal = goal }
      Button("Edit") { editingGoal = goal }.tint(.blue)
    }
  }
  private func legacyStatusLabel(_ status: FocusStatus) -> String {
    switch status {
    case .workingOnIt: return "Working on it"
    case .improved: return "Improved"
    case .awaitingFeedback: return "Awaiting feedback"
    }
  }

}

private func semesterName(_ semester: String?) -> String {
  guard let semester, !semester.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
    return "Unspecified semester"
  }
  return semester
}
