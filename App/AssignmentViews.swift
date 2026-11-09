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
            detailText(
              item.reflection, empty: "Add a reflection about how you approached this work.")
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
            Text(
              item.dueDate.map { "Due \($0.formatted(date: .abbreviated, time: .omitted))" }
                ?? "No due date")
          }
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
  @State private var hasDueDate = false
  @State private var importTarget: ImportTarget?
  @State private var importerPresented = false
  @State private var imported: ImportedText?
  @State private var importError: String?
  @FocusState private var focusedField: EditorField?
  private enum EditorField { case title, score, outOf, brief, work, feedback, reflection }
  enum ImportTarget { case brief, work, feedback, reflection }
  struct ImportedText: Identifiable {
    let id = UUID()
    var text: String
    var target: ImportTarget
  }
  var body: some View {
    NavigationStack {
      Form {
        Section("Assignment") {
          TextField("Title", text: $assignment.title).focused($focusedField, equals: .title)
            .accessibilityIdentifier("assignment.title")
          Toggle("Add due date", isOn: $hasDueDate).onChange(of: hasDueDate) { _, enabled in
            if enabled && assignment.dueDate == nil { assignment.dueDate = Date() }
            if !enabled { assignment.dueDate = nil }
          }
          if hasDueDate {
            DatePicker(
              "Due date",
              selection: Binding(
                get: { assignment.dueDate ?? Date() }, set: { assignment.dueDate = $0 }),
              displayedComponents: .date)
          }
          TextField("Score (optional)", text: $scoreText).focused($focusedField, equals: .score)
            .keyboardType(.decimalPad)
            .accessibilityIdentifier("assignment.score")
          TextField("Out of", text: $outOfText).focused($focusedField, equals: .outOf).keyboardType(
            .decimalPad
          ).accessibilityIdentifier(
            "assignment.outOf")
        }
        Section("Brief") {
          TextEditor(text: $assignment.brief).focused($focusedField, equals: .brief)
            .accessibilityLabel("Assignment brief").frame(
              minHeight: 100)
          Button("Import brief") {
            importTarget = .brief
            importerPresented = true
          }
        }
        Section("Submitted work") {
          Text("Paste or import the work you submitted so it can be reviewed alongside feedback.")
            .font(.caption).foregroundStyle(.secondary)
          TextEditor(text: $assignment.submittedWork).focused($focusedField, equals: .work)
            .accessibilityLabel("Submitted work").frame(
              minHeight: 120)
          Button("Import submitted work") {
            importTarget = .work
            importerPresented = true
          }
        }
        Section("Tutor feedback") {
          TextEditor(text: $assignment.tutorFeedback).focused($focusedField, equals: .feedback)
            .accessibilityLabel("Tutor feedback").frame(
              minHeight: 100)
          Button("Import feedback") {
            importTarget = .feedback
            importerPresented = true
          }
        }
        Section("Your reflection") {
          Text(
            "What went well? What felt challenging? Your reflection stays private unless selected."
          ).font(.caption).foregroundStyle(.secondary)
          TextEditor(text: $assignment.reflection).focused($focusedField, equals: .reflection)
            .accessibilityLabel("Your reflection").frame(
              minHeight: 100)
          Button("Import reflection") {
            importTarget = .reflection
            importerPresented = true
          }
        }
      }.scrollDismissesKeyboard(.interactively).navigationTitle("Assignment").toolbar {
        ToolbarItemGroup(placement: .keyboard) {
          Spacer()
          Button("Done") { focusedField = nil }.accessibilityIdentifier("assignment.keyboardDone")
        }
        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
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
            assignment.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
      }.onAppear {
        scoreText = assignment.score.map { String($0) } ?? ""
        outOfText = assignment.outOf.map { String($0) } ?? ""
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
