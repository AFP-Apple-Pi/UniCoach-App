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
  @Environment(\.horizontalSizeClass) private var sizeClass
  private var assignments: [Assignment] { app.data.assignments.filter { !$0.isDemo } }
  private var subjects: [Subject] { app.data.subjects.filter { !$0.isDemo } }
  private var reflected: Int {
    assignments.filter(\.hasReflection).count
  }
  private var goals: [LearningGoal] {
    app.data.goals.filter { !$0.isDemo }.sorted {
      ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast)
    }
  }
  private var reports: [MentorReport] {
    app.data.reports.filter { report in
      guard let id = report.assignmentID,
        let assignment = app.data.assignments.first(where: { $0.id == id })
      else { return false }
      return !assignment.isDemo
    }.sorted { $0.createdAt > $1.createdAt }
  }
  private var feedbackCount: Int {
    assignments.filter { !$0.tutorFeedback.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
      .count
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        Text(app.data.profile.name.isEmpty ? "Greetings" : "Greetings, \(app.data.profile.name)")
          .font(.custom("Inter-Regular", size: 34, relativeTo: .largeTitle).weight(.bold))
          .foregroundStyle(teal)
        NavigationLink {
          SubjectsView(startInSubjects: true)
        } label: {
          Label {
            Text("Search subjects and assignments")
          } icon: {
            Image("SearchIcon").renderingMode(.template)
          }
          .foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
          .padding(14).background(.background, in: Capsule())
        }.buttonStyle(.plain)
        if sizeClass == .regular {
          HStack(alignment: .top, spacing: 24) {
            VStack(alignment: .leading, spacing: 20) {
              JourneyCard(assignments: assignments, reflected: reflected)
              HomeStatsCard(subjects: subjects, assignments: assignments, feedbackCount: feedbackCount, goals: goals)
              HomeRecentCards(subjects: subjects, reports: reports)
            }
            .frame(maxWidth: .infinity)
            VStack(alignment: .leading, spacing: 20) { HomeGoalCards(goals: goals) }
              .frame(maxWidth: 360)
          }
        } else {
          JourneyCard(assignments: assignments, reflected: reflected)
          HomeStatsCard(subjects: subjects, assignments: assignments, feedbackCount: feedbackCount, goals: goals)
          HomeRecentCards(subjects: subjects, reports: reports)
          HomeGoalCards(goals: goals)
        }
      }.padding().frame(maxWidth: 1200)
    }.background(canvasColor).navigationTitle("Home").navigationBarTitleDisplayMode(.inline)
  }

}

struct StatCard: View {
  let title: String
  let value: String
  let symbol: String
  let color: Color
  var body: some View {
    HStack(alignment: .top, spacing: 10) {
      Image(symbol).resizable().scaledToFit().frame(width: 20, height: 20).padding(8).background(
        .white.opacity(0.8), in: RoundedRectangle(cornerRadius: 10))
      VStack(alignment: .leading, spacing: 4) {
        Text(value).font(.title3.bold())
        Text(title).font(.caption)
      }
      Spacer(minLength: 0)
    }.foregroundStyle(Color.black.opacity(0.85)).frame(
      maxWidth: .infinity, minHeight: 78, alignment: .leading
    ).padding(14).background(color, in: RoundedRectangle(cornerRadius: 20))
  }
}

struct JourneyCard: View {
  let assignments: [Assignment]
  let reflected: Int
  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("Your learning journey").font(.subheadline.weight(.medium))
      Text(
        assignments.isEmpty
          ? "No reflections yet"
          : "\(Int((Double(reflected) / Double(assignments.count) * 100).rounded()))%"
      )
      .font(.custom("Inter-Regular", size: 34, relativeTo: .largeTitle).weight(.bold))
      Text("Reflection coverage: \(reflected) of \(assignments.count) assignments").font(
        .subheadline)
      if !assignments.isEmpty {
        ProgressView(value: Double(reflected), total: Double(assignments.count)).tint(teal).frame(
          maxWidth: 180)
      }
    }
    .frame(maxWidth: .infinity, minHeight: 192, alignment: .leading)
    .padding(24)
    .background {
      GeometryReader { geometry in
        Image("MountainHero").resizable().scaledToFill()
          .frame(width: geometry.size.width, height: geometry.size.height).clipped()
          .accessibilityHidden(true)
          .overlay {
            LinearGradient(
              colors: [lavender, lavender.opacity(0.92), lavender.opacity(0.15)],
              startPoint: .leading, endPoint: .trailing)
          }
      }
    }
    .clipShape(RoundedRectangle(cornerRadius: 24))
  }
}

struct CoachCard: View {
  var body: some View {
    VStack(spacing: 12) {
      Text("Your AI Coach").font(.title2.bold())
      Text("Understand your feedback and plan your next steps.").multilineTextAlignment(.center)
      NavigationLink("Start a coaching session") { MentorLanding() }.buttonStyle(.borderedProminent)
        .tint(Color(red: 0.09, green: 0.24, blue: 0.20))
    }
    .foregroundStyle(.white)
    .frame(maxWidth: .infinity, minHeight: 190)
    .padding(20)
    .background {
      GeometryReader { geometry in
        Image("CoachBackground").resizable().scaledToFill()
          .frame(width: geometry.size.width, height: geometry.size.height).clipped()
          .accessibilityHidden(true)
          .overlay { Color.black.opacity(0.40) }
      }
    }
    .clipShape(RoundedRectangle(cornerRadius: 24))
  }
}

struct HomeStatsCard: View {
  let subjects: [Subject]
  let assignments: [Assignment]
  let feedbackCount: Int
  let goals: [LearningGoal]
  var body: some View {
    LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 12)], spacing: 12) {
      StatCard(
        title: "Subjects", value: "\(subjects.count)", symbol: "BookIcon",
        color: Color(red: 0.85, green: 0.92, blue: 0.89))
      StatCard(
        title: "Assignments", value: "\(assignments.count)", symbol: "CalendarIcon",
        color: Color(red: 0.89, green: 0.85, blue: 0.93))
      StatCard(
        title: "With feedback", value: "\(feedbackCount)", symbol: "FeedbackIcon",
        color: Color(red: 0.96, green: 0.92, blue: 0.82))
      StatCard(
        title: "Goals completed",
        value: "\(goals.filter(\.isCompleted).count) of \(goals.count)", symbol: "GoalIcon",
        color: Color(red: 0.87, green: 0.91, blue: 0.89))
    }
  }
}

struct HomeRecentCards: View {
  let subjects: [Subject]
  let reports: [MentorReport]
  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      DashboardCard(title: "Continue learning") {
        if subjects.isEmpty {
          Text("Add a subject to begin your learning journey.").foregroundStyle(.secondary)
        }
        ForEach(subjects.prefix(3)) { subject in
          NavigationLink {
            SubjectDetail(subjectID: subject.id)
          } label: {
            HStack {
              Image(systemName: "book.closed").foregroundStyle(teal)
              VStack(alignment: .leading) {
                Text(subject.name)
                Text(subject.code).font(.caption).foregroundStyle(.secondary)
              }
              Spacer()
              Image(systemName: "chevron.right")
            }.padding(.vertical, 5)
          }.buttonStyle(.plain)
        }
      }
      DashboardCard(title: "Recent activity") {
        if reports.isEmpty {
          Text("Your saved feedback reviews will appear here.").foregroundStyle(.secondary)
        }
        ForEach(reports.prefix(3)) { report in
          NavigationLink {
            ReportDetail(report: report)
          } label: {
            VStack(alignment: .leading) {
              Text("Feedback review saved")
              Text(report.createdAt.formatted(date: .abbreviated, time: .shortened)).font(
                .caption
              ).foregroundStyle(.secondary)
            }
          }.buttonStyle(.plain)
        }
      }
    }
  }
}

struct HomeGoalCards: View {
  @Environment(AppState.self) private var app
  let goals: [LearningGoal]
  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      DashboardCard(title: "Your next steps") {
        if goals.filter({ !$0.isCompleted }).isEmpty {
          Text("Choose a learning goal to plan your next step.").foregroundStyle(.secondary)
        }
        ForEach(goals.filter { !$0.isCompleted }.prefix(3)) { goal in
          Button {
            var updated = goal
            updated.isCompleted = true
            app.perform { try app.store.upsertGoal(updated) }
          } label: {
            Label(goal.title, systemImage: "circle")
          }.buttonStyle(.plain)
        }
      }
      CoachCard()
      DashboardCard(title: "Your learning goals") {
        if goals.isEmpty { Text("No learning goals yet.").foregroundStyle(.secondary) }
        ForEach(goals.prefix(3)) { goal in
          Label(goal.title, systemImage: goal.isCompleted ? "checkmark.circle.fill" : "circle")
        }
        NavigationLink("View progress") { ProgressScreen() }.font(.subheadline.weight(.semibold))
      }
    }
  }
}

struct DashboardCard<Content: View>: View {
  let title: String
  @ViewBuilder let content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text(title).font(.custom("Inter-Regular", size: 20, relativeTo: .title3).weight(.semibold))
      content
    }
    .frame(maxWidth: .infinity, alignment: .leading).padding(20).background(
      .background, in: RoundedRectangle(cornerRadius: 24))
  }
}
