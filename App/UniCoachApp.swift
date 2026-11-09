import SwiftUI
import UniformTypeIdentifiers
import PDFKit
import FoundationModels
import UniCoachCore

let teal = Color(uiColor: UIColor { traits in
    traits.userInterfaceStyle == .dark
        ? UIColor(red: 0.45, green: 0.82, blue: 0.78, alpha: 1)
        : UIColor(red: 0.08, green: 0.36, blue: 0.35, alpha: 1)
})
private let cream = Color(red: 0.97, green: 0.97, blue: 0.93)

@main struct UniCoachApp: App {
    @State private var app = AppState()
    var body: some Scene { WindowGroup { RootView().environment(app).tint(teal) } }
}

@MainActor @Observable final class AppState {
    var store: UniCoachStore = {
        if ProcessInfo.processInfo.arguments.contains("-ui-smoke") {
            let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("UniCoach/ui-smoke.json")
            try? FileManager.default.removeItem(at: url)
            return UniCoachStore(fileURL: url)
        }
        return UniCoachStore()
    }()
    var error: String?
    init() { error = store.loadingError }
    var data: AppData { store.data }
    func perform(_ action: () throws -> Void) { do { try action() } catch { self.error = error.localizedDescription } }
}

struct RootView: View {
    @Environment(AppState.self) private var app
    var body: some View {
        TabView {
            NavigationStack { SubjectsView() }.tabItem { Label("Subjects", systemImage: "books.vertical") }
            NavigationStack { ProgressScreen() }.tabItem { Label("Progress", systemImage: "chart.bar") }
            NavigationStack { ProfileScreen() }.tabItem { Label("Profile", systemImage: "person.crop.circle") }
        }
        .sheet(isPresented: Binding(get: { !app.data.profile.onboardingComplete }, set: { _ in })) { ProfileEditor(profile: app.data.profile, onboarding: true).interactiveDismissDisabled() }
        .alert("Could not save", isPresented: Binding(get: { app.error != nil }, set: { if !$0 { app.error = nil } })) { Button("OK") { app.error = nil } } message: { Text(app.error ?? "") }
    }
}

struct SubjectsView: View {
    @Environment(AppState.self) private var app
    @State private var editing: Subject?
    @State private var query = ""
    var filteredSubjects: [Subject] { app.data.subjects.filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) || $0.code.localizedCaseInsensitiveContains(query) } }
    var body: some View {
        List {
            Section { VStack(alignment: .leading, spacing: 8) { Text("Your learning, in one place").font(.title2.bold()); Text("Keep your subjects, feedback and reflections close.").foregroundStyle(.secondary) }.padding(.vertical, 8).listRowBackground(Color(uiColor: .secondarySystemGroupedBackground)) }
            if app.data.subjects.isEmpty {
                Section { ContentUnavailableView("No subjects yet", systemImage: "books.vertical", description: Text("Add a subject to start organising your work.")); Button("Add sample subject") { addSample() }.accessibilityIdentifier("subjects.sample").accessibilityHint("Creates clearly labelled synthetic sample data") }
            } else {
                Section("Your subjects") { ForEach(filteredSubjects) { subject in NavigationLink { SubjectDetail(subjectID: subject.id) } label: { HStack(spacing: 14) { RoundedRectangle(cornerRadius: 5).fill(subjectColor(subject.colorHex)).frame(width: 8); VStack(alignment: .leading, spacing: 4) { Text(subject.name).font(.headline); Text("\(subject.code)\(subject.isDemo ? "  •  Sample" : "")").font(.subheadline).foregroundStyle(.secondary) } }.padding(.vertical, 5) } } }
            }
        }.searchable(text: $query, prompt: "Search subjects").navigationTitle("Subjects").toolbar { Button { editing = Subject(colorHex: "#287C76") } label: { Label("Add subject", systemImage: "plus") } }.sheet(item: $editing) { SubjectEditor(subject: $0) }
    }
    private func addSample() {
        app.perform { _ = try app.store.addSampleSubject() }
    }
}
func subjectColor(_ hex: String) -> Color { let value = UInt64(hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted), radix: 16) ?? 0x287C76; return Color(red: Double((value >> 16) & 255)/255, green: Double((value >> 8) & 255)/255, blue: Double(value & 255)/255) }

struct SubjectEditor: View {
    @Environment(AppState.self) private var app; @Environment(\.dismiss) private var dismiss
    @State var subject: Subject
    let colors = ["#287C76", "#526EA3", "#A3664C", "#806395", "#A58435"]
    var body: some View { NavigationStack { Form {
        Section("Subject") { TextField("Name", text: $subject.name); TextField("Code", text: $subject.code); TextField("Credits", value: $subject.credits, format: .number).keyboardType(.decimalPad); TextField("Tutor", text: $subject.tutor) }
        Section("Academic goal") { TextField("What would you like to achieve?", text: $subject.academicGoal, axis: .vertical) }
        Section("Colour") { Picker("Colour", selection: $subject.colorHex) { ForEach(colors, id: \.self) { color in HStack { Circle().fill(subjectColor(color)).frame(width: 20, height: 20); Text(["#287C76": "Teal", "#526EA3": "Blue", "#A3664C": "Terracotta", "#806395": "Lavender", "#A58435": "Gold"][color] ?? "Colour") }.tag(color) } } }
    }.navigationTitle(subject.name.isEmpty ? "New subject" : "Edit subject").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Save") { app.perform { try app.store.upsertSubject(subject); dismiss() } }.disabled(subject.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) } } } }
}

struct SubjectDetail: View {
    @Environment(AppState.self) private var app; @Environment(\.dismiss) private var dismiss
    let subjectID: UUID
    @State private var editing: Subject?; @State private var assignment: Assignment?; @State private var gradeFilter = "All"; @State private var goal: LearningGoal?; @State private var deletingGoal: LearningGoal?; @State private var deleting = false
    var subject: Subject? { app.data.subjects.first { $0.id == subjectID } }
    var body: some View { Group { if let subject { List {
        Section { VStack(alignment: .leading, spacing: 6) { Text(subject.code).font(.caption.bold()).foregroundStyle(teal); Text(subject.name).font(.title2.bold()); if subject.isDemo { Text("Synthetic sample").font(.caption).foregroundStyle(.secondary) }; Text("\(subject.credits.formatted()) credits  •  \(subject.tutor.isEmpty ? "No tutor added" : subject.tutor)").foregroundStyle(.secondary); if !subject.academicGoal.isEmpty { Text(subject.academicGoal).padding(.top, 4) } }.padding(.vertical, 8) }
        Section { Picker("Assignments", selection: $gradeFilter) { Text("All").tag("All"); Text("Graded").tag("Graded"); Text("Ungraded").tag("Ungraded") }.pickerStyle(.segmented); ForEach(app.data.assignments.filter { $0.subjectID == subjectID && (gradeFilter == "All" || (gradeFilter == "Graded" ? $0.grade != nil : $0.grade == nil)) }) { item in NavigationLink { AssignmentDetail(assignmentID: item.id) } label: { VStack(alignment: .leading) { Text(item.title).font(.headline); Text("Due \(item.dueDate.formatted(date: .abbreviated, time: .omitted))" + (item.grade.map { "  •  \($0.formatted())%" } ?? "")).font(.subheadline).foregroundStyle(.secondary) } } }; Button { assignment = Assignment(subjectID: subjectID) } label: { Label("Add assignment", systemImage: "plus") } } header: { Text("Assignments") }
        Section("Goals") { ForEach(app.data.goals.filter { $0.subjectID == subjectID }) { item in Button { var updated = item; updated.isCompleted.toggle(); app.perform { try app.store.upsertGoal(updated) } } label: { Label(item.title, systemImage: item.isCompleted ? "checkmark.circle.fill" : "circle") }.swipeActions { Button("Delete", role: .destructive) { deletingGoal = item }; Button("Edit") { goal = item }.tint(.blue) } }; Button { goal = LearningGoal(subjectID: subjectID) } label: { Label("Add goal", systemImage: "plus") } }
        Section { Button("Delete subject", role: .destructive) { deleting = true } }
    }.navigationTitle("Subject").navigationBarTitleDisplayMode(.inline).toolbar { Button("Edit") { editing = subject } }.sheet(item: $editing) { SubjectEditor(subject: $0) }.sheet(item: $assignment) { AssignmentEditor(assignment: $0) }.sheet(item: $goal) { GoalEditor(goal: $0) }.confirmationDialog("Delete this subject and its assignments?", isPresented: $deleting, titleVisibility: .visible) { Button("Delete subject", role: .destructive) { app.perform { try app.store.deleteSubject(id: subjectID); dismiss() } } }.confirmationDialog("Delete this goal?", isPresented: Binding(get: { deletingGoal != nil }, set: { if !$0 { deletingGoal = nil } }), titleVisibility: .visible) { Button("Delete goal", role: .destructive) { if let deletingGoal { app.perform { try app.store.deleteGoal(id: deletingGoal.id) }; self.deletingGoal = nil } } }
    } else { ContentUnavailableView("Subject unavailable", systemImage: "books.vertical") } } }
}

struct GoalEditor: View {
    @Environment(AppState.self) private var app; @Environment(\.dismiss) private var dismiss; @State var goal: LearningGoal
    var body: some View { NavigationStack { Form { TextField("Goal", text: $goal.title); Toggle("Completed", isOn: $goal.isCompleted) }.navigationTitle("Learning goal").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Save") { app.perform { try app.store.upsertGoal(goal); dismiss() } }.disabled(goal.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) } } } }
}
