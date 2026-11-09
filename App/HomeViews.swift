import SwiftUI
import UniCoachCore

extension View {
  func profileToolbar() -> some View {
    toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        NavigationLink {
          ProfileScreen()
        } label: {
          Label("Profile", systemImage: "person.crop.circle")
        }
      }
    }
  }
}
struct HomeScreen: View {
  @Environment(AppState.self) private var app
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 18) {
        VStack(alignment: .leading, spacing: 10) {
          Text(app.data.profile.name.isEmpty ? "Welcome" : "Hello, \(app.data.profile.name)").font(
            .subheadline.weight(.semibold))
          Text("Your learning. A little clearer.").font(.largeTitle.bold())
          Text("Make sense of feedback and carry useful ideas into your next assignment.")
            .foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(24).background(
          LinearGradient(
            colors: [lavender, lavender.opacity(0.5)], startPoint: .topLeading,
            endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 24))
        VStack(alignment: .leading, spacing: 10) {
          Text("Your reflection practice").font(.headline)
          let assignments = app.data.assignments.filter { !$0.isDemo }
          let reflected = assignments.filter {
            !$0.reflection.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
          }.count
          Text("\(reflected) of \(assignments.count) assignments have a reflection")
          Text(
            "\(app.data.subjects.filter { !$0.isDemo }.count) subjects  •  \(assignments.count) assignments"
          ).font(.subheadline).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(20).background(
          .regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        VStack(alignment: .leading, spacing: 10) {
          Text("Understand your feedback").font(.headline)
          Text(
            "Review your submitted work and tutor feedback together, then choose a focus for next time."
          ).foregroundStyle(.secondary)
          NavigationLink("Show me what it means") { MentorLanding() }.buttonStyle(
            .borderedProminent)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(20).background(
          .regularMaterial, in: RoundedRectangle(cornerRadius: 20))
      }.padding()
    }.navigationTitle("Home")
  }
}
struct MentorLanding: View {
  @Environment(AppState.self) private var app
  @State private var chosen: Assignment?
  var body: some View {
    List {
      Section {
        Text(
          "Choose an assignment, then review and approve the exact submitted work and feedback for this request."
        ).foregroundStyle(.secondary)
      }
      Section("Assignments") {
        if app.data.assignments.isEmpty {
          Text("Add an assignment in My Learning to begin.").foregroundStyle(.secondary)
        }
        ForEach(app.data.assignments) { assignment in
          Button {
            chosen = assignment
          } label: {
            VStack(alignment: .leading) {
              Text(assignment.title).font(.headline)
              if let subject = app.data.subjects.first(where: { $0.id == assignment.subjectID }) {
                Text(subject.name).font(.caption).foregroundStyle(.secondary)
              }
            }
          }
        }
      }
    }.navigationTitle("AI Mentor").sheet(item: $chosen) { MentorView(assignmentID: $0.id) }
  }
}
