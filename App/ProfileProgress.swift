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
      Section("Learning goal") {
        Text(
          app.data.profile.learningGoal.isEmpty
            ? "No learning goal added yet." : app.data.profile.learningGoal)
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
          TextField("Learning goal", text: $profile.learningGoal, axis: .vertical)
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
  @State private var subjectID: UUID?
  @State private var assignmentID: UUID?
  @State private var goal: LearningGoal?
  @State private var deleting: LearningGoal?
  @State private var deletingFocus: FocusAction?
  var assignments: [Assignment] {
    app.data.assignments.filter {
      !$0.isDemo && (subjectID == nil || $0.subjectID == subjectID)
        && (assignmentID == nil || $0.id == assignmentID)
    }
  }
  var goals: [LearningGoal] {
    let sampleIDs = Set(app.data.subjects.filter(\.isDemo).map(\.id))
    return app.data.goals.filter {
      ($0.subjectID.map { !sampleIDs.contains($0) } ?? true)
        && (subjectID == nil || $0.subjectID == subjectID)
    }
  }
  var average: Double? {
    let grades = assignments.compactMap(\.grade)
    return grades.isEmpty ? nil : grades.reduce(0, +) / Double(grades.count)
  }
  var body: some View {
    List {
      Section {
        Picker("Subject", selection: $subjectID) {
          Text("All subjects").tag(Optional<UUID>.none)
          ForEach(app.data.subjects.filter { !$0.isDemo }) { subject in
            Text(subject.name).tag(Optional(subject.id))
          }
        }.onChange(of: subjectID) { _, _ in assignmentID = nil }
        Picker("Assignment", selection: $assignmentID) {
          Text("All assignments").tag(Optional<UUID>.none)
          ForEach(
            app.data.assignments.filter {
              !$0.isDemo && (subjectID == nil || $0.subjectID == subjectID)
            }
          ) { assignment in
            Text(assignment.title).tag(Optional(assignment.id))
          }
        }
      }
      Section("Your progress") {
        LabeledContent(
          "Subjects",
          value: "\(subjectID == nil ? app.data.subjects.filter { !$0.isDemo }.count : 1)")
        LabeledContent(
          "Entered-grade average",
          value: average.map { "\($0.formatted(.number.precision(.fractionLength(1))))%" }
            ?? "No grades entered")
        LabeledContent("Assignments", value: "\(assignments.count)")
        LabeledContent("Graded", value: "\(assignments.compactMap(\.grade).count)")
        LabeledContent(
          "Goals completed", value: "\(goals.filter(\.isCompleted).count) of \(goals.count)")
        Text(
          "Averages use only grades you entered, with equal weight. Sample assignments are excluded."
        ).font(.caption).foregroundStyle(.secondary)
      }
      Section("Reflection practice") {
        let reflected = assignments.filter {
          !$0.reflection.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }.count
        Text("\(reflected) of \(assignments.count) assignments have a reflection")
      }
      focusSection(
        "Your next-assignment focus",
        actions: app.data.focusActions.filter {
          !$0.isDemo && (subjectID == nil || $0.subjectID == subjectID)
            && (assignmentID == nil || $0.assignmentID == assignmentID)
        })
      if subjectID == nil && app.data.focusActions.contains(where: { $0.isDemo }) {
        focusSection("Sample practice", actions: app.data.focusActions.filter { $0.isDemo })
      }
      Section("Entered grades") {
        if assignments.compactMap(\.grade).isEmpty {
          Text("No grades entered yet. Add a grade to an assignment to see it here.")
            .foregroundStyle(.secondary)
        } else {
          Chart(assignments.filter { $0.grade != nil }) { assignment in
            BarMark(
              x: .value("Assignment", assignment.id.uuidString),
              y: .value("Grade", assignment.grade ?? 0)
            ).foregroundStyle(teal).accessibilityLabel(assignment.title).accessibilityValue(
              "\((assignment.grade ?? 0).formatted()) percent")
          }.chartXAxis(.hidden).chartYScale(domain: 0...100).frame(height: 180).accessibilityLabel(
            "Entered assignment grades, out of 100 percent")
          ForEach(assignments.filter { $0.grade != nil }) { assignment in
            LabeledContent(assignment.title, value: "\((assignment.grade ?? 0).formatted())%")
          }
        }
      }
      Section("Goals") {
        ForEach(goals) { item in
          Button {
            var updated = item
            updated.isCompleted.toggle()
            app.perform { try app.store.upsertGoal(updated) }
          } label: {
            Label(item.title, systemImage: item.isCompleted ? "checkmark.circle.fill" : "circle")
          }.swipeActions {
            Button("Delete", role: .destructive) { deleting = item }
            Button("Edit") { goal = item }.tint(.blue)
          }
        }
        Button {
          goal = LearningGoal(subjectID: subjectID)
        } label: {
          Label("Add goal", systemImage: "plus")
        }
      }
    }.confirmationDialog(
      "Delete this focus?",
      isPresented: Binding(get: { deletingFocus != nil }, set: { if !$0 { deletingFocus = nil } }),
      titleVisibility: .visible
    ) {
      Button("Delete focus", role: .destructive) {
        if let deletingFocus {
          app.perform { try app.store.deleteFocus(id: deletingFocus.id) }
          self.deletingFocus = nil
        }
      }
    }.navigationTitle("My Progress").sheet(item: $goal) { GoalEditor(goal: $0) }.confirmationDialog(
      "Delete this goal?",
      isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
      titleVisibility: .visible
    ) {
      Button("Delete goal", role: .destructive) {
        if let deleting {
          app.perform { try app.store.deleteGoal(id: deleting.id) }
          self.deleting = nil
        }
      }
    }
  }
  @ViewBuilder private func focusSection(_ title: String, actions: [FocusAction]) -> some View {
    Section(title) {
      if actions.isEmpty { Text("No focus chosen yet.").foregroundStyle(.secondary) }
      ForEach(actions) { action in
        VStack(alignment: .leading, spacing: 8) {
          Text(action.title).font(.headline)
          let subject = app.data.subjects.first { $0.id == action.subjectID }
          let assignment = app.data.assignments.first { $0.id == action.assignmentID }
          Text(
            "From: \(subject?.name ?? "Former subject") • \(assignment?.title ?? "Former assignment")"
          )
          .font(.caption).foregroundStyle(.secondary)
          Picker(
            "Your reported status",
            selection: Binding(
              get: { action.status },
              set: { status in
                app.perform { try app.store.updateFocusStatus(id: action.id, status: status) }
              }
            )
          ) {
            Text("Working on it").tag(FocusStatus.workingOnIt)
            Text("Improved (self-reported)").tag(FocusStatus.improved)
            Text("Awaiting feedback").tag(FocusStatus.awaitingFeedback)
          }.pickerStyle(.menu)
        }.swipeActions { Button("Delete", role: .destructive) { deletingFocus = action } }
      }
    }
  }

}
