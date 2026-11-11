# UniCoach

Repository: https://github.com/AFP-Apple-Pi/UniCoach-App

A private, native iOS study companion for subjects, assignments, goals and reflections. It starts empty; the sample is synthetic and added only when requested. Records are stored locally in the app's Application Support directory. There is no account, network service or analytics.

Open `UniCoach.xcodeproj` in Xcode and select the shared UniCoach scheme. The app targets iOS 17 or later. Build for Simulator without signing:

```sh
xcodebuild -project UniCoach.xcodeproj -scheme UniCoach -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

For updates to an app already installed on a physical device, preserve its existing bundle identifier and development team. For a fresh, independent installation, use your own development team and a unique bundle identifier in Xcode's Signing & Capabilities settings, or pass `DEVELOPMENT_TEAM` and `UNICOACH_BUNDLE_IDENTIFIER` as build overrides. The project does not contain a personal team ID.

## AI Mentor

Open the AI Mentor tab and choose **New conversation**. The UniCoach app icon identifies the mentor in the welcome screen and conversation, alongside a persistent message box. Enter a study question or edit a starter. Optionally tap **Add context**, select and redact the exact text, and choose **Use selected text**. Tap **Approve & send** to approve Apple on-device AI for that request. Reviewing context alone never sends anything.

Continue in the same message box and tap **Approve & send** for each reply. That action approves the visible conversation, new message and any newly selected text for Apple on-device processing. Expand **Review exact conversation history** to inspect the transcript. Earlier private source snapshots are not automatically reused, although previous messages may quote or discuss them. Add context explicitly for any turn; source selection resets after every attempt. At accessibility text sizes, the compact composer labels the action **Approve** and provides a **Review request** information button for the full message, history, sources and processing explanation.

The question, selected source text and approved conversation history together can contain up to 50,000 characters. Requests that fit the device model run directly. Longer requests are processed in sections on the device, then combined through summaries before the final answer. Every approved part is processed, but summaries can miss details. Progress and cancellation remain available, and the full approved text and actual processing steps are retained for inspection. Nothing is silently cut off.

Apple Intelligence generation uses the on-device Foundation Models system model. Build with Xcode 26 or newer; generation requires iOS 26 or later, eligible hardware, Apple Intelligence enabled, and a ready model. The app displays the availability reason and disables generation when unavailable. It never silently switches engines or uploads a request.

Conversations are saved locally and can be reopened under **Saved conversations**. Older saved answers open as one-turn conversations that you can continue. Each turn's **Request details** retains its approved question, source snapshots, conversation snapshot and processing record. For long requests, the original approved request is distinguished from the smaller prompts actually sent to the model. Swipe a saved conversation to delete all its turns and snapshots after confirmation.

Cancelled requests, deleted or changed conversations, and changed selected sources cannot save a late answer. Each retry requires a new approval. New conversations start with no previous history, source selection or Apple consent.

Follow-ups use the approved student and mentor roles in chronological order, with the latest request taking priority. Short replies can refer to an earlier mentor offer. Direct replies use a fresh on-device session seeded only with those visible messages; earlier private source snapshots remain excluded. Long conversations retain the bounded section-processing path and preserve the current request.

New mentor responses use declarative guidance rather than asking questions or inviting another reply. Missing timing produces unscheduled steps instead of a timing question. A response containing a detected question or reply solicitation gets at most one audited rewrite; if that is still unsuitable, the app states that it could not complete a useful answer and labels its general starting guidance. Review findings and plan tasks also pass this prose check, while original evidence quotations remain unchanged. The bounded text check is not a proof that every possible indirect phrasing is detectable. See [follow-up verification](Docs/CONVERSATION_FOLLOWUPS.md) for first-attempt device evidence.


**Review assignment feedback** remains available for paired work and tutor-feedback analysis, including Maria's Keep doing, Improve and Next step advice and linked goals. New assignment reviews use Apple on-device AI only. There is no engine picker or offline fallback. Existing reports from the retired contextual offline option remain readable and retain their original engine label. Both chat and assignment reviews require explicit approval; selected context can be edited before use. Model output can be inaccurate and should be checked.

Feedback reviews first check what each tutor comment refers to, whether it relates to the approved work, and whether each proposed finding is supported. Uncertain or unrelated feedback asks for clarification; partial feedback can produce a limited review. Internal passage IDs are hidden in ordinary advice while exact quotes and processing records remain available. These checks use the same on-device model and can still misclassify praise or requested changes.

For explicit study allocations, the app builds session slots from grounded counts and durations, then asks Apple AI for a task and end check in each. A follow-up can change the allocation. Additional constraints are checked or clarified, and incompatible time limits are explained rather than silently changed. Ordinary questions stay conversational. See the [mentor quality report](Docs/MENTOR_QUALITY.md) for supported cases, first-attempt evidence and remaining errors.

Add subject and Add assignment share **Import PDF or photo**. Choose a PDF, JPG or PNG from Files, or an image from Photos. UniCoach reads selectable PDF text and uses on-device OCR for images and scanned pages. Review the subject details, select and edit discovered assignments, then save them together. Missing deadlines stay unset; assessment weighting never becomes a personal mark. Likely subject and assignment matches are shown for review, and changing an existing subject requires an explicit update choice. Saved records retain source filenames, page references and extracted excerpts.

For layouts the local parser cannot structure, **Review text for Apple suggestions** lets you approve the exact extracted text for on-device AI. Suggestions remain editable and are never saved automatically. This optional step requires a ready Apple model and text that fits its runtime context budget; shorten the approved excerpt if needed. Document reading supports files up to 24 MB, 80 PDF pages and 100,000 extracted characters. See [document import and verification](Docs/DOCUMENT_IMPORT.md).

The separate text-import controls inside assignment brief, submitted work, tutor feedback and reflection fields continue to support UTF-8 text and selectable-text PDFs up to 2 MB and 100,000 characters. Those field imports do not perform OCR. Review extracted text before using it.

Run `swift test` for core tests. For manual verification, use only synthetic data, enable Airplane Mode, add the sample explicitly, and inspect the assignment and consent flow. Reports remain in local history after source edits or deletion. The UI smoke test uses a separate disposable synthetic data file and never resets the normal store.

## Design and learning logic

Home, Learning Overview, Subjects and the assignment dashboard follow the updated UniCoach Figma design, with bundled illustrations, the UniCoach mentor icon and licensed Inter typography. Phone layouts stack the desktop cards and retain native navigation and accessible controls. Dashboard values come from saved records. See [design references and asset provenance](Docs/DESIGN_UPDATE.md).

My Learning contains Overview, Subjects, Assignments and Goals. Subjects and Goals have their own illustrated headers and add actions, and the Home catalogue cards open their matching destinations. The Assignments header is followed immediately by the four progress cards, then its filters; the former insights banner has been removed. The Assignments view supports subject filtering, a calendar marking every due date in the current selection, selected-day deadlines and completion counts. The separate next-seven-days section has been removed. Assignment creation and editing use Details, Questions, Feedback and Review stages. Optional fields include collaboration type, format, target grade, weighting and five guided reflections. Weighting is recorded separately from actual score and available marks. Existing records remain readable without new fields. Skipping feedback preserves existing feedback and marks; saving an assignment never starts AI analysis.

The on-device backend migrates earlier data into schema version 1 while preserving historical reports. Learning goals unify profile goals, subject goals and saved focuses; new report next steps can become linked goals. Assignments use earned and available marks, with weighted subject totals, optional semesters and chronological grade charts. A known maximum without a score remains ungraded. New coaching reports contain Keep doing, Improve and Next step, with checked tutor quotes and explicit approval for Apple on-device processing.

See [device verification](Docs/DEVICE_TESTING.md) for validation and model limitations. No remote backend, sign-in or cloud upload is required.

## Alpha verification

The [10 November 2026 alpha report](Docs/ALPHA_TESTING.md) records the feature coverage matrix, positive and rejection cases, reproducible fictional fixtures, two fixed defects and actual model evidence. All 68 core tests and all 14 distinct physical UI workflows passed their final technical assertions. At that checkpoint the alpha was not fully passing: Apple AI failed to detect unrelated tutor feedback and only partly followed a two-session planning request. Those first responses were retained without tuning or retrying for a better outcome.

The subsequent [mentor quality revision](Docs/MENTOR_QUALITY.md) adds relevance checks and constrained session plans, with new first-attempt device evidence. It records improvements and remaining semantic errors separately from technical test passes.
