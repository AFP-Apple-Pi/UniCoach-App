import PDFKit
import SwiftUI
import UniCoachCore
import UniformTypeIdentifiers

struct AssignmentDetail: View {
  @Environment(AppState.self) private var app
  @Environment(\.dismiss) private var dismiss
  let assignmentID: UUID
  @State private var editing: Assignment?
  @State private var mentor = false
  @State private var deleting = false
  var assignment: Assignment? { app.data.assignments.first { $0.id == assignmentID } }
  var body: some View {
    Group {
      if let item = assignment {
        List {
          Section("Your approach") {
            if !item.reflection.isEmpty { Text(item.reflection) }
            ForEach([
              ("Current stage & progress", item.currentStage),
              ("Approach & methodology", item.approach),
              ("Challenges & roadblocks", item.challenges),
              ("Collaboration & team dynamic", item.collaboration),
              ("Rubric & quality self-assessment", item.rubric),
            ], id: \.0) { title, value in
              if !value.isEmpty {
                Text(title).font(.caption.bold()).foregroundStyle(.secondary)
                Text(value)
              }
            }
            if !item.hasReflection { Text("Add a reflection about how you approached this work.").foregroundStyle(.secondary) }
            if !item.submittedWork.isEmpty {
              Text("Submitted work").font(.caption.bold()).foregroundStyle(.secondary)
              Text(item.submittedWork)
            }
            if !item.brief.isEmpty {
              Text("Assignment brief").font(.caption.bold()).foregroundStyle(.secondary)
              Text(item.brief)
            }
          }
          Section("Tutor feedback") {
            detailText(item.tutorFeedback, empty: "No feedback added yet.")
            if let score = item.score, let outOf = item.outOf {
              Text("Grade: \(score.formatted()) / \(outOf.formatted())")
            } else if let outOf = item.outOf {
              Text("Awaiting grade • out of \(outOf.formatted())")
            }
          }
          Section("AI analysis") {
            Text(
              "Choose exactly what to share before each analysis. Your material stays on this device."
            ).font(.subheadline).foregroundStyle(.secondary)
            Button("Open mentor") { mentor = true }
            ForEach(app.data.reports.filter { $0.assignmentID == assignmentID }) { report in
              NavigationLink {
                ReportDetail(report: report)
              } label: {
                VStack(alignment: .leading) {
                  Text(report.engine.displayName)
                  Text(report.createdAt.formatted()).font(.caption).foregroundStyle(.secondary)
                }
              }
            }
          }
          Section("Subject overview") {
            if let subject = app.data.subjects.first(where: { $0.id == item.subjectID }) {
              Text(subject.name).font(.headline)
              Text(subject.code).foregroundStyle(.secondary)
              if let semester = subject.semester { Text(semester) }
            }
            if !item.collaborationType.isEmpty { LabeledContent("Collaboration", value: item.collaborationType) }
            if !item.assignmentFormat.isEmpty { LabeledContent("Format", value: item.assignmentFormat) }
            if let weighting = item.weighting { LabeledContent("Weighting", value: "\(weighting.formatted())%") }
            if !item.targetGrade.isEmpty { LabeledContent("Target grade", value: item.targetGrade) }
            Text(
              item.dueDate.map { "Due \($0.formatted(date: .abbreviated, time: .omitted))" }
                ?? "No due date")
          }
          ImportedDocumentSources(references: item.sourceReferences)
        }.navigationTitle(item.title).navigationBarTitleDisplayMode(.inline).toolbar {
          Menu {
            Button("Edit") { editing = item }.accessibilityIdentifier("assignment.edit")
            Button("Delete assignment", role: .destructive) { deleting = true }
          } label: {
            Label("Assignment actions", systemImage: "ellipsis.circle")
          }.accessibilityIdentifier("assignment.actions")
        }.sheet(item: $editing) { AssignmentEditor(assignment: $0) }.sheet(isPresented: $mentor) {
          MentorView(assignmentID: assignmentID)
        }.confirmationDialog(
          "Delete this assignment?", isPresented: $deleting, titleVisibility: .visible
        ) {
          Button("Delete assignment", role: .destructive) {
            app.perform {
              try app.store.deleteAssignment(id: assignmentID)
              dismiss()
            }
          }
        }
      } else {
        ContentUnavailableView("Assignment unavailable", systemImage: "doc")
      }
    }
  }
  @ViewBuilder func detailText(_ value: String, empty: String) -> some View {
    if value.isEmpty { Text(empty).foregroundStyle(.secondary) } else { Text(value) }
  }
}

struct AssignmentEditor: View {
  @Environment(AppState.self) private var app
  @Environment(\.dismiss) private var dismiss
  @State var assignment: Assignment
  @State private var scoreText = ""
  @State private var outOfText = ""
  @State private var weightingText = ""
  @State private var step = 0
  @State private var guided = true
  @State private var initialized = false
  @State private var showFeedback = true
  @ScaledMetric(relativeTo: .body) private var editorHeight: CGFloat = 140
  @State private var hasDueDate = false
  @State private var importTarget: ImportTarget?
  @State private var importerPresented = false
  @State private var imported: ImportedText?
  @State private var importError: String?
  @State private var showDocumentImport = false
  @State private var documentSaved = false
  @FocusState private var focusedField: EditorField?
  private enum EditorField { case title, score, outOf, brief, work, feedback, reflection, weighting, target, stage, approach, challenges, collaboration, rubric }
  enum ImportTarget { case brief, work, feedback, reflection }
  struct ImportedText: Identifiable {
    let id = UUID()
    var text: String
    var target: ImportTarget
  }
  var body: some View {
    NavigationStack {
      Form {
        Section {
          Picker("Step", selection: $step) {
            Text("Details").tag(0)
            Text("Questions").tag(1)
            Text("Feedback").tag(2)
            Text("Review").tag(3)
          }.pickerStyle(.segmented).accessibilityIdentifier("assignment.step")
        }
        if step == 0 {
          Section("Start with basics") {
            Image("AssignmentDocumentHero").resizable().scaledToFit().frame(maxWidth: .infinity, maxHeight: 130).accessibilityHidden(true)
            Text("Add your assignment details. You can type or use keyboard dictation.")
              .font(.caption).foregroundStyle(.secondary)
            if !app.data.assignments.contains(where: { $0.id == assignment.id }) {
              Button("Import PDF or photo", systemImage: "doc.viewfinder") {
                focusedField = nil
                showDocumentImport = true
              }.accessibilityIdentifier("assignment.importDocument")
            }
            TextField("Assignment title", text: $assignment.title).focused($focusedField, equals: .title)
              .accessibilityIdentifier("assignment.title")
            Picker("Subject", selection: $assignment.subjectID) {
              ForEach(app.data.subjects) { subject in
                Text(subject.name).tag(subject.id)
              }
            }.accessibilityIdentifier("assignment.subject")
            Picker("Collaboration type", selection: $assignment.collaborationType) {
              Text("Not specified").tag("")
              Text("Individual").tag("Individual")
              Text("Group work").tag("Group work")
            }
            Toggle("Add due date", isOn: $hasDueDate).onChange(of: hasDueDate) { _, enabled in
              if enabled && assignment.dueDate == nil { assignment.dueDate = Date() }
              if !enabled { assignment.dueDate = nil }
            }
            if hasDueDate {
              DatePicker("Due date", selection: Binding(get: { assignment.dueDate ?? Date() }, set: { assignment.dueDate = $0 }), displayedComponents: .date)
            }
            TextField("Weighting % (optional)", text: $weightingText).focused($focusedField, equals: .weighting).keyboardType(.decimalPad)
              .accessibilityIdentifier("assignment.weighting")
            TextField("Target grade (optional)", text: $assignment.targetGrade).focused($focusedField, equals: .target)
            Picker("Assignment format", selection: $assignment.assignmentFormat) {
              ForEach(["", "Presentation", "Report", "Quiz", "Written", "Research project", "Design project"], id: \.self) { format in
                Text(format.isEmpty ? "Not specified" : format).tag(format)
              }
            }
          }
          Section("Brief / description") {
            TextEditor(text: $assignment.brief).focused($focusedField, equals: .brief)
              .accessibilityLabel("Assignment brief").frame(height: editorHeight)
            Button("Import brief") { importTarget = .brief; importerPresented = true }
          }
        } else if step == 1 {
          Section("Reflection & process") {
            Text("Reflect on your work using the guided questions or an all-in-one reflection. Both are saved independently.")
              .font(.caption).foregroundStyle(.secondary)
            Picker("Reflection style", selection: $guided) {
              Text("Guided questions").tag(true)
              Text("All-in-one reflection").tag(false)
            }.pickerStyle(.segmented)
            if guided {
              guidedQuestion("Current stage & progress", prompt: "What milestones have you completed so far?", text: $assignment.currentStage, field: .stage)
              guidedQuestion("Approach & methodology", prompt: "What methods or tools are you using?", text: $assignment.approach, field: .approach)
              guidedQuestion("Challenges & roadblocks", prompt: "What has been difficult or uncertain?", text: $assignment.challenges, field: .challenges)
              guidedQuestion("Collaboration & team dynamic", prompt: "How are responsibilities and teamwork managed?", text: $assignment.collaboration, field: .collaboration)
              guidedQuestion("Rubric & quality self-assessment", prompt: "How does your work compare with the grading criteria?", text: $assignment.rubric, field: .rubric)
            } else {
              TextEditor(text: $assignment.reflection).focused($focusedField, equals: .reflection)
                .accessibilityLabel("Your reflection").frame(height: editorHeight)
              Button("Import reflection") { importTarget = .reflection; importerPresented = true }
            }
          }
          Section("Submitted work") {
            TextEditor(text: $assignment.submittedWork).focused($focusedField, equals: .work)
              .accessibilityLabel("Submitted work").frame(height: editorHeight)
            Button("Import submitted work") { importTarget = .work; importerPresented = true }
          }
        } else if step == 2 {
          Section("Tutor feedback & grades") {
            Text("You can add feedback now or skip for now. Skipping keeps any existing feedback and marks.")
              .font(.caption).foregroundStyle(.secondary)
            Picker("Results", selection: $showFeedback) {
              Text("Skip for now").tag(false)
              Text("I have feedback or marks").tag(true)
            }.pickerStyle(.segmented)
          }
          if showFeedback {
          Section("Tutor feedback") {
            TextEditor(text: $assignment.tutorFeedback).focused($focusedField, equals: .feedback)
              .accessibilityLabel("Tutor feedback").frame(height: editorHeight)
            Button("Import feedback") { importTarget = .feedback; importerPresented = true }
          }
          Section("Marks") {
            TextField("Score (optional)", text: $scoreText).focused($focusedField, equals: .score)
              .keyboardType(.decimalPad).accessibilityIdentifier("assignment.score")
            TextField("Out of", text: $outOfText).focused($focusedField, equals: .outOf)
              .keyboardType(.decimalPad).accessibilityIdentifier("assignment.outOf")
          }
          }
        } else {
          Section("Review assignment") {
            LabeledContent("Title", value: assignment.title.isEmpty ? "Not entered" : assignment.title)
            LabeledContent("Subject", value: app.data.subjects.first(where: { $0.id == assignment.subjectID })?.name ?? "Unavailable")
            LabeledContent("Due date", value: assignment.dueDate.map { $0.formatted(date: .abbreviated, time: .omitted) } ?? "No due date")
            LabeledContent("Weighting", value: weightingText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Not entered" : weightingText + "%")
            LabeledContent("Target grade", value: assignment.targetGrade.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Not entered" : assignment.targetGrade)
            LabeledContent("Collaboration", value: assignment.collaborationType.isEmpty ? "Not entered" : assignment.collaborationType)
            LabeledContent("Format", value: assignment.assignmentFormat.isEmpty ? "Not entered" : assignment.assignmentFormat)
            LabeledContent("Grade", value: scoreText.isEmpty ? (outOfText.isEmpty ? "Not entered" : "Awaiting grade, out of " + outOfText) : scoreText + " / " + (outOfText.isEmpty ? "not entered" : outOfText))
            LabeledContent("Brief", value: assignment.brief.isEmpty ? "Not entered" : "Added")
            LabeledContent("Reflection", value: [assignment.reflection, assignment.currentStage, assignment.approach, assignment.challenges, assignment.collaboration, assignment.rubric].allSatisfy(\.isEmpty) ? "Not entered" : "Added")
            LabeledContent("Submitted work", value: assignment.submittedWork.isEmpty ? "Not entered" : "Added")
            LabeledContent("Feedback", value: assignment.tutorFeedback.isEmpty ? "Not entered" : "Added")
            Button("Edit details") { step = 0 }.buttonStyle(.borderless)
            Button("Edit reflection") { step = 1 }.buttonStyle(.borderless)
            Button("Edit feedback") { step = 2 }.buttonStyle(.borderless)
            Text("Nothing is sent to a mentor until you review and approve a separate request.")
              .font(.caption).foregroundStyle(.secondary)
          }
        }
        Section {
          HStack {
            if step > 0 { Button("Back") { focusedField = nil; step -= 1 }.buttonStyle(.borderless) }
            Spacer()
            if step < 3 {
              Button("Next") { focusedField = nil; step += 1 }.buttonStyle(.borderless).accessibilityIdentifier("assignment.next")
                .disabled(step == 0 && (assignment.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !app.data.subjects.contains { $0.id == assignment.subjectID }))
            }
          }
        }
      }.scrollDismissesKeyboard(.interactively).navigationTitle("Assignment").toolbar {
        ToolbarItemGroup(placement: .keyboard) {
          Spacer()
          Button("Done") { focusedField = nil }.accessibilityIdentifier("assignment.keyboardDone")
        }
        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button(app.data.assignments.contains(where: { $0.id == assignment.id }) ? "Save" : "Confirm & Add") {
            if weightingText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
              assignment.weighting = nil
            } else if let value = Double(weightingText), value.isFinite, (0...100).contains(value) {
              assignment.weighting = value
            } else {
              importError = "Enter a weighting between 0 and 100."
              return
            }
            if scoreText.isEmpty && outOfText.isEmpty {
              assignment.score = nil
              assignment.outOf = nil
            } else if scoreText.isEmpty, let outOf = Double(outOfText), outOf.isFinite, outOf > 0 {
              assignment.score = nil
              assignment.outOf = outOf
            } else if let score = Double(scoreText), let outOf = Double(outOfText), score.isFinite,
              outOf.isFinite, score >= 0, outOf > 0, score <= outOf
            {
              assignment.score = score
              assignment.outOf = outOf
            } else {
              importError =
                "Enter a positive total. If you enter a score, it must be between zero and the total."
              return
            }
            if !hasDueDate { assignment.dueDate = nil }
            app.perform {
              try app.store.upsertAssignment(assignment)
              dismiss()
            }
          }.accessibilityIdentifier("editor.save").disabled(
            assignment.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || step != 3)
        }
      }.onAppear {
        guard !initialized else { return }
        initialized = true
        scoreText = assignment.score.map { String($0) } ?? ""
        outOfText = assignment.outOf.map { String($0) } ?? ""
        weightingText = assignment.weighting.map { String($0) } ?? ""
        hasDueDate = assignment.dueDate != nil
      }
      .fileImporter(isPresented: $importerPresented, allowedContentTypes: [.plainText, .pdf]) {
        result in
        guard let target = importTarget else { return }
        importTarget = nil
        do {
          let url = try result.get()
          let access = url.startAccessingSecurityScopedResource()
          defer { if access { url.stopAccessingSecurityScopedResource() } }
          let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
          guard size <= 2_000_000 else { throw ImportError.tooLarge }
          let text: String
          guard ["pdf", "txt", "text"].contains(url.pathExtension.lowercased()) else {
            throw ImportError.unsupported
          }
          if url.pathExtension.lowercased() == "pdf" {
            guard let document = PDFDocument(url: url), let extracted = document.string,
              !extracted.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else { throw ImportError.noText }
            text = extracted
          } else {
            text = try String(contentsOf: url, encoding: .utf8)
          }
          guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ImportError.noText
          }
          guard text.count <= 100_000 else { throw ImportError.tooLarge }
          imported = ImportedText(text: text, target: target)
        } catch { importError = error.localizedDescription }
      }.sheet(item: $imported) { draft in
        ImportReview(draft: draft) { reviewed in
          switch reviewed.target {
          case .brief: assignment.brief = reviewed.text
          case .work: assignment.submittedWork = reviewed.text
          case .feedback: assignment.tutorFeedback = reviewed.text
          case .reflection: assignment.reflection = reviewed.text
          }
        }
      }.alert(
        "Import",
        isPresented: Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })
      ) {
        Button("OK") { importError = nil }
      } message: {
        Text(importError ?? "")
      }
    }
    .sheet(isPresented: $showDocumentImport, onDismiss: {
      if documentSaved { dismiss() }
    }) {
      DocumentImportView(entry: .assignment, preferredSubjectID: assignment.subjectID) {
        documentSaved = true
      }
    }
  }

  private func guidedQuestion(_ title: String, prompt: String, text: Binding<String>, field: EditorField) -> some View {
    DisclosureGroup(title) {
      Text(prompt).font(.caption).foregroundStyle(.secondary)
      TextEditor(text: text).focused($focusedField, equals: field).frame(height: editorHeight).accessibilityLabel(title)
    }
  }
  enum ImportError: LocalizedError {
    case tooLarge, noText, unsupported
    var errorDescription: String? {
      switch self {
      case .unsupported: return "Choose a UTF-8 text file or selectable-text PDF."
      case .tooLarge:
        return
          "The file or extracted text is too large. Use a file under 2 MB and 100,000 characters."
      case .noText:
        return
          "No selectable text was found. Scanned PDFs cannot be imported; use a text PDF or type the content."
      }
    }
  }
}
struct ImportReview: View {
  @Environment(\.dismiss) private var dismiss
  @State var draft: AssignmentEditor.ImportedText
  let save: (AssignmentEditor.ImportedText) -> Void
  var body: some View {
    NavigationStack {
      VStack(alignment: .leading) {
        Text("Review and correct the extracted text before using it.").font(.subheadline)
          .foregroundStyle(.secondary).padding([.horizontal, .top])
        TextEditor(text: $draft.text).padding(.horizontal)
      }.navigationTitle("Review import").toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button("Use text") {
            save(draft)
            dismiss()
          }.disabled(draft.text.count > 100_000)
        }
      }
    }
  }
}
