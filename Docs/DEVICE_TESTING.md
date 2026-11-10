# Physical device verification

Use a disposable build and synthetic material only. Preserve the existing bundle ID and development team when updating an installed app. For a fresh independent app, use your own team and a unique bundle ID. Never commit personal signing settings. For example, replace the placeholders below with your team, device identifier and a bundle ID registered to your team:

```sh
xcodebuild -project UniCoach.xcodeproj -scheme UniCoach -destination 'id=DEVICE_UDID' DEVELOPMENT_TEAM=TEAM_ID UNICOACH_BUNDLE_IDENTIFIER=com.example.UniCoach -allowProvisioningUpdates build
xcodebuild -project UniCoach.xcodeproj -scheme UniCoach -destination 'id=DEVICE_UDID' DEVELOPMENT_TEAM=TEAM_ID UNICOACH_BUNDLE_IDENTIFIER=com.example.UniCoach -allowProvisioningUpdates test
```

The UI smoke test launches with `-ui-smoke`, which resets only a separate synthetic `ui-smoke.json`; normal app data is not deleted. Do not put real material in this test.

Manual checklist:

1. Enable Airplane Mode. Complete the optional profile, verify the library is empty, and tap Add sample subject. Open the synthetic assignment and inspect its four sections.
2. Import a small UTF-8 file and a selectable-text PDF. Correct extracted text in the review screen before use. Confirm a scanned PDF explains that it has no selectable text.
3. Open the mentor. Confirm no source is selected and Apple on-device availability is shown without an engine picker. Select synthetic submitted work and tutor feedback, redact a distinctive synthetic phrase and explicitly approve Apple processing. Check the saved snapshot excludes the redacted phrase and identifies Apple on-device. If the model is unavailable, generation stays disabled; there is no offline alternative.
4. Start and cancel a request, then reopen it and verify selection is empty. If possible while generation runs, edit or delete the source or assignment and confirm a stale report is not saved. Existing history should remain visible after deletion.
5. On eligible iOS 26 or later hardware, check the displayed Apple model availability and explicitly approve each request before generation. Inspect the saved source snapshots, exact prompt and output; check guidance against the supplied text. On unsupported hardware, verify the reason and do not expect model generation.

## Xcode Run signing

The tracked `Config/Signing.xcconfig` defaults to an empty development team and optionally includes the ignored `Config/LocalSigning.xcconfig`. To run on your device in Xcode, create that local file with your own team ID:

```xcconfig
DEVELOPMENT_TEAM = YOUR_TEAM_ID
```

The default bundle identifier remains `com.UniCoach`. Preserve the installed app's identifier and team for updates. Use a distinct identifier only for a fresh independent app. Command-line build settings can also override the local setting.

## Historical checks for the prior flow

On 9 November 2026, a physical iPhone 16 running iOS 27.2 successfully generated and saved an Apple on-device report using only the synthetic Example assignment brief, selected and approved explicitly. The report identified Apple on-device and contained an S1 summary and three recommendations grounded in that sample. These results were recorded for the previous single-source flow and do not validate the revised paired-review flow. The third automated contextual offline smoke run passed on an iPhone 16 with iOS 27.2 using Xcode 27.2: one UI test, zero failures, in 29.85 seconds. The test was corrected to tap the nested switch control; manual source selection had worked.

## Team 2 board alignment

The Team 2 brief was reviewed read-only at https://miro.com/app/board/uXjVEWCKtU8=/. The revised flow reviews selected submitted work and tutor feedback together, shows exact approved passages, separates keep-doing and improvement suggestions, and lets the student choose a focus. The contextual offline option does not assert links. Progress uses entered grades, reflections, goals and user-reported focus status. On 9 November 2026, the revised contextual offline flow passed on an iPhone 16 running iOS 27.2 with Xcode 27.2: one UI test, zero failures, in 55.296 seconds. The check covered the synthetic paired review and focus flow. Normal app data was verified byte-for-byte unchanged without reading its private contents.

A physical Apple on-device review used one joint request with only approved synthetic work and feedback. The saved report retained the exact sources and quotes and produced both keep-doing and improvement findings. The improvement addressed the requested explanation. The strength still overstated causal support and suggested expansion instead of repeating the praised practice. Models can overstate causal support, misclassify or rephrase praise and requested changes, or imply that a request has already been addressed. Exact quote and source validation verifies text identity, not interpretation; the report asks the student to check it.

After the hit-area fix, a physical signed reinstall was checked with a fresh synthetic Apple report. Expanding the work disclosure and scrolling saved zero focus actions. Deliberately adopting the improvement saved exactly one focus with findingIndex 1. My Progress showed it under Sample practice with the Example subject and Example assignment origin and Working on it status.

## Figma and Maria alignment

The responsive Home, Learning Overview and Subjects layouts were adapted from the local UniCoach.fig export and the live Figma file `INRt3rcz4iC3Im2WYM847c`, nodes `19:733`, `19:491` and `35:1983`. The desktop layout is adapted to stacked phone cards and native tab navigation. MountainHero, CoachBackground, OverviewIllustration, the dashboard stat icons and navigation/search vector assets are downloaded from the Figma design and bundled locally. Student identity and course details come from the profile. The Figma design uses Inter. The app bundles the official Inter variable font from Google Fonts under the SIL Open Font License; the license is in App/Fonts/OFL.txt. Figma heading styles use Dynamic Type-scaled Inter, while native controls retain platform fonts. Native controls and their platform icons remain for interaction and accessibility. Physical phone verification of this revision is recorded below.

The Maria model update uses score and total marks, subject-weighted marks, optional semesters and a unified goals list. The offline option is keyword-based, is not AI, and may miss or misclassify feedback. Tutor quotes are checked against approved text, not independently verified interpretations. Historical reports remain readable.


On 9 November 2026, the Figma/Maria revision passed 24 core tests and a signed build with Xcode 27.2. The expanded physical UI test passed on an iPhone 16 running iOS 27.2 in 118.606 seconds with zero failures. It created non-demo synthetic records in the isolated test store, entered 12.35/20 and 35.8/40, checked 80.25% and 48.15 of 60 marks, generated offline three-part advice, created a linked goal, and verified completion propagated between Progress and the subject's open goals. It captured Home, Learning Overview and Subjects screenshots. Manual phone review caught and corrected Home artwork overflow; assignment forms now include a keyboard Done control.

Apple's on-device model was available. A manual request selected and approved only synthetic submitted work and tutor feedback. The first generated response failed evidence validation and was not saved; there was no engine fallback. A second explicitly approved request saved an Apple on-device report containing keep-doing and improvement advice, exact tutor sentence quotes, paired work excerpts and a concrete next step. Exact-source validation does not guarantee the model's interpretation or causal reasoning.

After verification, the app was launched normally. Its normal data file was verified byte-for-byte unchanged against a protected pre-update backup without displaying private contents. Tests used only `ui-smoke.json`. The `-ui-smoke-preserve` launch argument opens that isolated store without resetting it for manual inspection; normal launch uses `data.json`.

## SwiftAgents review and Apple AI Mentor questions (10 November 2026)

The initial question-only revision added **Ask your mentor** alongside assignment feedback reviews. The conversational revision below replaces that entry with **New conversation**. The question flow uses Apple's on-device Foundation Models engine only. Context is optional and starts unselected; every request requires an explicit Apple AI choice and approval. A fresh model session receives only the approved question and context, with no previous conversation. Without context, the answer is general study guidance. Answers retain the exact prompt, instructions, approved source titles and text, and can be deleted from local history.

The review added compiler guards around Foundation Models, localized search, safe optional handling, migration UUID construction without force unwraps, reusable dashboard views and shared cards. The iOS 17 deployment target, Swift language mode, Figma layout, local signing configuration and existing learning logic remain unchanged. Debug builds now use the selected device architecture so app and local Swift package simulator slices agree.

Compatibility decisions: the older tab API and array-backed enumerated lists remain for iOS 17. Background-only GeometryReader sizing retains the Figma illustration crop. The original dynamic palette and native grouped canvas color remain adaptive; a named-color conversion was reverted after screenshot review exposed unreadable tint. Newer APIs are not adopted at the cost of supported devices or approved design behavior.

For a live model check, use only synthetic data in the isolated UI test store:

1. Open AI Mentor, then Ask your mentor. Confirm the question, source selections and Apple AI toggle start empty/off.
2. Inspect the model availability message. On eligible iOS 26 or newer hardware, enable Apple Intelligence and allow its model to finish downloading if needed.
3. Enter a synthetic study question. Optionally select synthetic context, edit the exact approved text, then explicitly enable Apple AI and approve the request.
4. Inspect the saved answer's engine, question, source snapshots and exact model request. Check the answer against the approved text. Model interpretation is not independently validated.
5. Start and cancel another request. Reopen the screen and confirm fresh consent is required. Verify saved answers remain readable after source edits/deletion, and that deleting an answer removes only that answer and its snapshots.

The initial validation below was performed on a simulator. Physical verification of the subsequent conversational revision is recorded in the next section.

Validation for this revision used Xcode 27.2:

- All 34 core tests passed, including 10 new mentor-question tests. The tested package, source and test files matched the applied checkout byte-for-byte.
- The iOS device build passed with signing disabled. Bundle identifier and personal signing overrides were not changed.
- All three UI cases passed on the iPhone 17 simulator running iOS 27.2, across the final consent/offline run and the corrected Apple test rerun. Consent reset took 30.026 seconds; the existing assignment/marks/offline-advice/goal regression took 114.966 seconds. The real Apple question test passed in 27.522 seconds and was not skipped.
- The Apple test explicitly approved a synthetic question without private context, generated a real answer, and verified its saved Apple engine and exact question-only prompt. It uses no model stub. An initial test assertion was corrected to scroll to the saved-answer link in the lazy form.
- Astra reviewed the resulting mentor, Home, Overview and Subjects screenshots. Readable tint and the approved dashboard layout were verified.
- SwiftLint was not installed. No Swift compiler errors or warnings were reported; Xcode emitted its expected AppIntents metadata-skip warning because the app has no AppIntents dependency.

These simulator results apply to the initial question-only revision. No existing private uploads or normal app data were used for these tests.


## Mentor conversations (10 November 2026)

Open **AI Mentor > New conversation** to ask a question, or reopen a saved conversation to answer the mentor's follow-up questions. Existing single answers become one-turn conversations without rewriting the saved data during loading. Each reply requires **Approve conversation and send**, which approves the displayed conversation and new reply for Apple on-device AI. **Review exact conversation history** shows the full transcript. Earlier source snapshots are not reattached; visible messages may still quote or discuss those sources. Start a new conversation to select different source material.

The app constructs each request from its explicitly approved transcript. Other conversations are excluded. Changed or deleted conversations, cancellation and changed selected sources prevent late responses from being saved. The initial conversational revision used a 6,000-character limit for the combined transcript, new question and selected sources. The later 50,000-character revision is documented below; neither revision silently truncates approved text. **Request details** retains each turn's exact prompt and approved snapshots. Deleting a saved conversation requires confirmation and removes all of its turns.

The physical test uses only synthetic material in `ui-smoke.json`:

1. Ask for help planning study time and request a follow-up question. Select a synthetic progress source with a distinctive marker, explicitly enable Apple AI and approve the first request.
2. Check that the first answer identifies Apple on-device and its request includes the exact approved synthetic context.
3. Expand the conversation history and verify the displayed question and actual generated answer. Reply that weekday study time is limited to 30 minutes, then approve the conversation and send.
4. Check the second answer and exact history-only prompt. Verify the earlier source snapshot was not automatically reattached.
5. Relaunch with `-ui-smoke-preserve`, reopen the saved conversation and confirm both turns persist. Start a new conversation and confirm its question, context and Apple consent are empty. Confirm deleting the saved conversation removes the whole thread.

Validation used Xcode 27.2 and a physical iPhone 16 running iOS 27.2. Apple's on-device model was available and generated both answers, with no stub or offline fallback. The second response incorporated the supplied 30-minute weekday constraint. Model interpretation remains the student's responsibility.

- All 42 core tests passed, including 18 mentor tests covering legacy decoding, persistence, exact transcript boundaries, conversation isolation, cancellation, changed/deleted history and request limits.
- The signed device build and build-for-testing passed with the existing bundle identifier and development team.
- The physical conversation test passed in 69.136 seconds. Consent reset passed in 27.283 seconds. Astra reviewed the physical screenshots for readable controls, the reply composer, approval disclosure and response content.
- The existing synthetic assignment, marks, offline-advice and goals regression passed on the physical phone in 122.452 seconds. Its first run exposed a test timing issue: the keyboard Done control existed before becoming hittable. A bounded readiness wait fixed the test; assignment production code was unchanged.
- The app was reopened normally after testing. Before the separately requested synthetic sample-data population, the normal data file matched its pre-install backup byte-for-byte. Private contents were not displayed or used for generation.
- A pre-existing runtime invalid-frame diagnostic appeared during the offline test without a visible or assertion failure. No blocking review findings remain.


## Requests up to 50,000 characters (10 November 2026)

The aggregate limit is now 50,000 characters across the question, approved conversation history and selected source text. The exact direct prompt remains unchanged when it fits the device model. On systems with token-counting support, the app measures the instructions, prompt and structured-review schema and reserves room for output and framework framing. Earlier supported systems use a conservative UTF-8 byte budget. See Apple's [context management guidance](https://developer.apple.com/documentation/foundationmodels/managing-the-context-window).

When a request is too large for one model session, the app processes every part in bounded fresh on-device sessions and combines the resulting notes before generating the answer. The final prompt retains the exact current question whenever that question itself fits. Oversized questions are processed in sections too. No source text or conversation tail is silently clipped, and there is no cloud or offline-engine fallback. The approval screen explains that summaries can omit details. Progress and cancellation remain available throughout processing.

Successful answers and reviews retain the complete approved material and the actual instructions, prompts and outputs for each model call. Chunk records contain UTF-16 ranges into the full original prompt, allowing exact coverage checks. The UI distinguishes the full approved request from actual model calls. For structured reviews, final findings must resolve to a bounded catalog of exact original work and feedback passages, never to summary text. Source identity checks establish provenance, not the correctness of the model's interpretation.

Cancellation, changed sources and deleted or changed conversations are checked around token counting and generation, and again before saving. Failed or cancelled requests do not save partial answers. Existing answers and reports decode without the new optional processing records. Long editing fields scroll within a Dynamic Type-scaled viewport; long saved material and processing prompts are expandable.

Validation:

- All 54 core tests passed, including initial stale/cancelled request cleanup, inclusive 50,000-character boundaries with history and sources, unchanged direct prompts, exact current-question retention, complete Unicode coverage, non-monotonic token-fit behavior, cancellation, deleted conversations, explicit failure when summaries cannot shrink, audit persistence and legacy decoding.
- The signed device build passed with Xcode 27.2, the existing bundle identifier and development team. Tests use the separate synthetic store, never the normal data file.
- A physical iPhone 16 running iOS 27.2 completed a 50,000-character structured review in 76.497 seconds. Two reading calls and one final call covered the full approved prompt. All three generated findings referenced exact original work and feedback ranges, and tutor quotations were verified verbatim.
- The first long-input UI attempt exposed an expanding text-editor cell before any model request. Bounded editors fixed the actual usability issue; the test was not relaxed to scroll through the oversized cell.
- The final physical 50,000-character question test passed in 56.164 seconds. Two reading calls covered all 50,212 UTF-16 units of the original prompt, including its framing, and a third call generated the answer with the exact current question retained. The approved question and source text totalled exactly 50,000 characters. The answer still omitted a concluding recommendation, demonstrating that complete input coverage does not guarantee complete retention in the summary or final answer.
- The three existing physical UI regressions passed on the final build: consent reset in 28.447 seconds, a real two-turn Apple conversation in 68.570 seconds, and the assignment/marks/offline-advice/goals flow in 123.358 seconds. Temporary long-request harness cases were removed after verification.
- After testing, UniCoach launched normally and its normal data file matched the immediate pre-install backup byte-for-byte. Existing subjects, assignments, uploads and conversations were preserved. No private material was used for these long-request tests.
- No Swift compiler warnings or errors were reported. Xcode emitted its expected AppIntents metadata-skip warning. SwiftLint was not installed.


## Final Figma design and chat refresh (10 November 2026)

This revision supersedes the earlier question Form and Apple toggle instructions above. Open **AI Mentor > New conversation** to enter the chat. The animated white Scottish terrier is the AI mentor mascot. Its gentle greeting motion respects Reduce Motion. The message composer remains available throughout the conversation. **Approve & send** explicitly approves Apple on-device AI for the current message, displayed history and any selected source text. **Add context** opens a separate source-selection and exact-text review sheet. Merely reviewing context does not send a request. Source selection resets after every attempt, and earlier source snapshots are never automatically reattached.

At accessibility text sizes, the composer uses a compact **Approve** button and accessible context/information controls. **Review request** shows the full processing explanation, current message, history and selected text in a scrollable sheet. Dynamic Type is not capped. The app still preserves the 50,000-character aggregate limit, cancellation, saved request audits and the explicit offline alternative for assignment reviews.

The updated Learning screen has Overview, Subjects and Assignments destinations. The assignment dashboard filters by subject, shows a selectable calendar and upcoming deadlines, and derives progress counts from saved records. Assignment editing uses Details, Questions, Feedback and Review stages. New metadata and five guided reflection answers decode safely when absent in older records. Guided reflection is a separate opt-in source. Skipping feedback preserves existing marks and comments; confirming an assignment never automatically runs analysis.

For synthetic device verification:

1. Create and reopen a subject description. Create an assignment through all four stages, with a brief, work, guided and all-in-one reflection, weighting, score and maximum marks. Verify the Review values, save, reopen, and cancel an edit without altering the saved record.
2. Verify marks, a paired contextual offline report and linked-goal completion. Inspect Assignments, subject filtering, calendar, the assignment list and Progress.
3. Open the mentor, edit optional source text, cancel source changes and start a new conversation. Check that merely reviewing context produces no answer and that a fresh conversation has no selected context.
4. On an eligible device, explicitly approve two synthetic turns with the actual Apple model. Check saved prompt/source/history boundaries, persistence, and conversation deletion.
5. Use dark mode and the largest Dynamic Type size. Verify the message box, keyboard, approval/context controls and scrollable exact-request sheet. Restore the original appearance after testing.

Design references, downloaded illustration provenance, generated mascot prompt and the Figma quota limitation are recorded in [design notes](DESIGN_UPDATE.md).


Final refresh validation:

- All 57 core tests passed, including new-field persistence, decoding older records without the optional metadata, guided-reflection source separation, and weighting validation without changing saved marks.
- The signed device build passed with Xcode 27.2 for the existing iPhone 16 running iOS 27.2. The bundle identifier and local development team were preserved. There were no Swift compiler warnings or errors; Xcode emitted its expected AppIntents metadata-skip warning. SwiftLint was not installed.
- The real Apple on-device model completed the two-turn synthetic conversation test twice, most recently in 66.329 seconds. The test checked saved source/history boundaries, reopening the conversation and deletion. The contextual offline engine was tested separately and was never substituted for Apple generation.
- The complete synthetic assignment wizard, saved metadata/reflections, marks, offline advice, linked goals, subject filters, calendar and progress flow passed in 177.960 seconds.
- After the final white Scottish terrier asset and animation change, consent/reset passed in 33.682 seconds and the dark-mode, largest-Dynamic-Type composer check passed in 28.686 seconds. These were targeted reruns; the Apple-generation and assignment regressions passed before the mascot-only change.
- Astra and both existing coding agents reviewed the mascot's Reduce Motion, active-scene and visibility guards. The welcome animation pauses under request sheets or alerts; small chat avatars stay still. Reduce Motion behavior was verified in code review, not by changing the phone's system setting. Final light and dark screenshots were visually reviewed.
- All UI tests used the separate synthetic store. The final app was installed as an update and launched with no test arguments. The normal data file matched its immediate pre-install backup byte-for-byte, preserving existing subjects, assignments, uploads and conversations.
- A pre-existing runtime invalid-frame diagnostic and a partial device-diagnostics collection warning appeared during testing without a failing final assertion or observed UI failure. No blocking review findings remain.


## Learning navigation and Apple-only mentor (10 November 2026)

This revision supersedes the earlier offline-engine and next-seven-days instructions above. My Learning now includes Overview, Subjects, Assignments and Goals. Subjects and Goals have their own Add buttons. Home catalogue cards open their matching Learning destinations; With feedback opens the filtered assignment list. The calendar marks all assignment due dates within the active filters, supports month navigation and lists assignments for the selected day. The separate Upcoming (next 7 days) section is removed.

New mentor requests use only Apple on-device AI. Assignment review shows availability and requires explicit approval of the selected work and feedback. If Apple AI is unavailable, generation remains unavailable without substituting another engine. Historical offline reports retain their original labels and remain readable.

Validation on the connected iPhone 16 running iOS 27.2:

- All 59 core tests passed, including Apple-request rejection by the offline generator and legacy offline-report decoding.
- Signed build and build-for-testing passed with Xcode 27.2, the existing bundle identifier and development team. The tested source and asset hashes matched all 66 recorded files before publication.
- All four physical UI tests passed on the first run: largest-Dynamic-Type dark-mode composer (30.730 seconds), consent reset (33.257 seconds), actual two-turn Apple conversation (68.714 seconds), and the expanded synthetic Learning flow (179.061 seconds).
- The Learning flow verified the four Home routes, feedback filtering and reset, subject creation, all assignment wizard stages and persistence, marks, new Apple-only review controls and availability, manual subject-linked goals and completion in Progress, two assignments on one calendar day, selected-day links, month navigation, and absence of the removed Upcoming section. The review controls were tested without invoking a new structured model review; the real model ran for the two-turn chat.
- Goals, assignment dashboard and selected-day screenshots were reviewed. Existing consent and accessibility checks continued to pass. Tests used only the separate synthetic store.
- The final app was installed as an update and launched without test arguments. The normal data file matched the immediate pre-install backup byte-for-byte both after tests and after normal launch. Existing records, uploads and conversations were preserved without displaying their contents.
- Xcode emitted the expected AppIntents metadata-skip warning. Previously observed runtime frame and partial device-diagnostics warnings did not produce a failing assertion or visible blocker. SwiftLint was not installed.


## Expanded alpha reset and student walkthrough (10 November 2026)

The user explicitly requested a complete reset and realistic invented student data. The app was uninstalled without backing up or reusing previous private records. See [the alpha report](ALPHA_TESTING.md) for the coverage matrix, failure ledger, fixture instructions and unedited fictional model evidence.

- Two production defects were fixed: duplicate saved IDs could crash a later commit, and negative/malformed subject credits could be accepted. All 68 core tests passed, with 96.00% line and 91.36% region coverage for UniCoachCore only.
- Fourteen distinct physical cases passed their final technical assertions on the iPhone 16 running iOS 27.2. Across attempts there were 16 passes and 8 harness failures in 24 completed case executions, plus the interrupted initial run. The report records each correction. Final importer checks passed in 145.308 seconds and the normal populated-app check passed in 49.561 seconds.
- The checks covered CRUD and cancellation, validation/rejection, profile and goals, all navigation routes, search, multi-month calendar dates, all four import destinations, invalid/oversized/scanned inputs, consent, actual Apple review/chat, saved goal adoption, persistence, dark accessibility text and landscape. The existing 50k physical checks were not repeated; current core boundary and processing tests passed.
- Model quality is not fully passing. The blind unrelated-feedback review falsely connected laboratory feedback to design research. The coherent review was useful with wording issues, and the follow-up failed to allocate the requested two 45-minute sessions. First responses remain unchanged; technical evidence checks do not establish semantic correctness.
- Temporary Files-sharing metadata was restored byte-for-byte before the final signed build. A final uninstall removed all test-store/import artifacts. The normal app now holds Jordan Lee's profile, three subjects, five detailed assignments, six goals, one actual Apple review and two actual conversation turns. Final launch used no test arguments; the normal data file matched the populated input byte-for-byte.
- All 69 recorded source/test/fixture/asset hashes matched the final build. No signing, bundle, dependency, model prompt or context-limit change was made. Signed builds passed with the expected AppIntents metadata-skip warning. SwiftLint was unavailable.


## Mentor relevance and constrained planning, 10 November 2026

The [mentor quality report](MENTOR_QUALITY.md) records the predeclared scenarios, actual first responses, general contract changes and remaining semantic errors. The final checkout passed 98 core tests (96.72% core-only line coverage) and a signed Xcode 27.2 build on iPhone 16 with iOS 27.2. The final physical consent, largest-text dark-mode accessibility and real two-turn conversation regressions passed in 33.502, 28.869 and 75.871 seconds respectively.

Observed improvements include withholding advice for unrelated or vague feedback, retaining legitimate portions of mixed and instruction-bearing feedback, useful coherent feedback, exact two-by-45 and changed two-by-20 session plans, three-by-20 plans, and an explanation of incompatible 90-minute minimum versus 60-minute availability. These are observed cases, not a guarantee of model accuracy. Earlier first outputs included false praise, invented specific criticism, false abstention and poor plan routing. The report preserves them. The final coherent review still omits valid comments and one praise next-step suggests redrafting. Long-input summaries can omit details despite complete processing.

The 50,000-character regression retained exact contiguous chunks covering the entire original prompt, the exact current question in the final call, and the actual output. New typed model stages preserve their real prompts, schemas and responses. The model checks its own interpretations in fresh sessions; exact quote checks and these additional calls do not provide independent semantic truth.

All evaluations used fictional isolated records. The final tested app was installed as an update, launched without test arguments and remained running. Normal data matched its pre-change copy byte-for-byte. No existing student records or source snapshots were changed, no private uploads were sent for these evaluations, and no temporary file-sharing settings were used.


## Learning headers and mentor icon, 11 November 2026

The requested layout update passed a signed build on iPhone 16 with iOS 27.2 and Xcode 27.2. The focused Learning/branding test passed in 39.117 seconds, verifying the Assignments header followed by progress and then filters, absence of both old insight banners, top Subjects and Goals banners, preserved add/cancel controls and the mentor app icon. The existing largest-Dynamic-Type dark-mode mentor test passed in 29.250 seconds, including the input, request review and context controls. Both passed on their first run, and screenshots of all affected screens were reviewed.

The runtime mentor icon is an exact copy of the bundled app icon. The retired dog artwork and animation were removed; welcome, pending-response and saved-message avatars use the shared static icon component. Composer and all later request/engine implementation remained byte-identical, and no core or persistence code changed. This visual update did not rerun model quality evaluations or make an AI request. The previous mentor quality findings remain applicable.

The tested app was installed as an update and launched without test arguments. Normal data matched the fresh pre-update copy byte-for-byte. Tests used only the isolated fictional store. The only build warnings were the expected App Intents metadata extraction notices.
