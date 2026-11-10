# Alpha verification: 10 November 2026

## Verdict

The alpha is **not fully passing**. Two application defects were fixed and the functional regression checks below passed where stated. A high-priority AI relevance failure and a separate instruction-following limitation remain. A technical UI pass means the approved request, persistence and audit workflow behaved correctly; it does not establish that the generated advice was correct.

The user explicitly authorised removal of all previous app data. The connected UniCoach app was uninstalled without a backup. None of the previous private records were read, copied into fixtures or sent to the model. The replacement student profile and coursework are invented, with ordinary student-facing names as requested.

## Fixes

- Duplicate IDs in a saved JSON collection could load and then crash during a later save. A disposable reproduction terminated with signal 5. The store now checks subjects, assignments, goals, reports and mentor answers before exposing loaded data. An invalid file remains untouched and writes fail closed. Historical dangling references remain supported.
- Negative subject credits were accepted and survived reopening. New or edited credits must now be finite and nonnegative. The editor validates the whole entered string, rejecting malformed text instead of accepting a numeric prefix or silently retaining an old value. Blank means zero; zero and fractional credits remain valid. Untouched legacy values retain their exact precision.

Production changes are confined to the store load check, credits validation/error and the subject credits editor. No model prompt, engine, context limit, network dependency, signing identity or data schema was changed.

## Coverage matrix

| Implemented area | Positive cases | Negative or rejection cases | Evidence/result |
| --- | --- | --- | --- |
| Profile/onboarding | Optional onboarding, edit, save and reopen | Cancel preserves saved profile | Physical profile/goal lifecycle passed; core round-trip tests passed |
| Home/navigation | Four catalogue routes and four tabs; feedback-filter route | Opening a new destination resets inappropriate prior filters | Existing physical Learning flow passed |
| Subjects | Creation, edit, description, semester, credits, colour presentation | Blank name, cancelled edit, negative/malformed credits, delete confirmation/cascade | Physical Learning and alpha validation flows passed; core zero/fractional/nonfinite boundaries passed |
| Search | Home search, subject code match, clearing | No-match query | Final normal-store smoke passed, including positive, no-match and cleared search |
| Assignment wizard | All four stages, detailed fields, reopen, score/total and weighting | Blank title, early Save, invalid weighting, score above total, cancel and confirmed deletion | Physical validation and Learning flows passed; core relationship and numeric boundaries passed |
| Calendar | Multiple same-day dates, past dates, dates beyond seven days, next/previous months and selected-day links | Empty/scoped collections; no next-seven-days section | Physical calendar and Learning cases passed; nil-date persistence/date fallback covered by core tests |
| Goals/progress | General and subject-linked goals, edit/completion, marks/reflections, explicit adoption of a saved review next step | Blank goal, cancelled edit/deletion, invalid subject relationship, historical origin retention | Physical lifecycle, Learning and saved-review adoption passed; core contracts passed |
| Imports | Text review/edit/cancel/accept; all four field destinations; selectable PDF | Empty text, invalid UTF-8, image-only PDF, unsupported extension, over 2 MB, over 100,000 characters | Physical importer passed for all four destinations and every listed rejection; unsupported Markdown was rejected by the app |
| Persistence/migration | Reopen, schema migration, original snapshots, adopted-goal origin | Corrupt JSON, duplicate IDs, future schema, failed atomic commit | Core tests passed; original malformed bytes unchanged |
| AI consent/privacy | Explicit source and request approval, exact redacted text, visible history, saved audit | No hidden prior snapshots, foreign/tampered/replayed requests, stale/deleted sources, cancellation, unavailable engine | Core tests and physical consent/real conversation cases passed |
| Apple-only app workflow | Honest availability, explicit Apple review button, actual Apple responses | No new offline selection or silent fallback; old reports still decode | Core Apple-only tests and physical Learning/mentor checks passed |
| Structured review | Paired work/feedback, exact evidence ranges, saved report/history, optional goal adoption | Bad quote/ID rejection; irrelevant-feedback first-response evaluation | Technical path passed. Relevance evaluation failed, detailed below |
| Conversation | Two actual turns, exact request snapshots, reopening, deletion, fresh-source reset | Empty message disabled, new conversation excludes history, cancelled/stale replies | Existing and retained-student physical cases passed; student follow-up quality only partially met the request |
| 50,000-character input | Inclusive aggregate boundary, Unicode coverage, unchanged short prompts, exact current question, multi-level audit | Over-limit, impossible fit, nonshrinking summaries, interrupted processing, no partial save | Current core tests passed. Earlier physical 50k question/review evidence is in DEVICE_TESTING.md; these model requests were not repeated in this pass |
| Accessibility/keyboard | Largest Dynamic Type, dark mode, portrait and landscape composer, source/request sheets | Approval/context controls remain reachable; keyboard Done dismisses | Physical accessibility, landscape and consent cases passed |
| Terrier mascot | Existing static avatars and motion lifecycle | Reduce Motion and inactive/covered-view guards | Code review only; system Reduce Motion was not toggled in this pass |

Core validation: **68 tests passed**, including nine new alpha contracts. LLVM measured **96.00% line coverage** and **91.36% region coverage for UniCoachCore only**, with no branch metric. These figures do not imply complete UI or semantic coverage. The tested core files matched the checkout.

## Actual model quality

**High-priority failure: unrelated feedback.** One approved on-device review paired the study-space research report with laboratory feedback. It returned four findings, all citing the exact spectrophotometer instruction as evidence for design research advice. It incorrectly described that instruction as praise for qualitative coding and did not flag the mismatch. The original first response was preserved without retrying or tuning the prompt. Exact source and quote validation passed, demonstrating that text identity does not establish a valid reasoning link. See [the unedited fictional evidence and single-approval record](QA/alpha-blind-review-2026-11-10.json).

**Coherent feedback: useful but imperfect.** The first review addressed requirement-to-evidence links, observation versus inference and stale availability data. Internal W2/W3/W4/W5 aliases leaked into user-facing advice. The first chat answer was broadly grounded, although its wording weakly overlooked that availability was already proposed in the work.

**Follow-up: partial instruction-following failure.** The student explicitly requested tasks and checks for two 45-minute sessions. The response mentioned the time budget but did not allocate tasks to each session, largely repeated the previous answer and asked whether help organising sessions was wanted. See [the actual review and two responses](QA/alpha-student-model-2026-11-10.json). These outputs remain unchanged in the populated app.

These are observed outcomes from the first approved requests, not a statistical model evaluation. The remaining work is a general relevance safeguard and broader evaluation, not a prompt tuned to this one fixture. UniCoach should not be represented as reliably detecting mismatched tutor feedback.

## Runs, failures and corrections

| Run | Result | Diagnosis/action |
| --- | --- | --- |
| Initial expanded run | Interrupted after three completed failures | The phone was landscape while the helper assumed portrait; a profile assertion also queried a lazy offscreen row. Explicit portrait setup, safe-area-aware scrolling and a separate landscape case were added |
| Second run | 1 passed, 2 failed | New tests assumed native confirmations always have Cancel. This OS uses anchored popovers. Tests now dismiss via the native dismiss region, verify the record remains, then test confirmed deletion |
| Third run | 3 passed, 1 failed | Import test assumed the folder title was a NavigationBar identifier. Native Files exposes a generic bar and a folder action title; the local fixture folder was already open |
| Fourth run | 5 passed, 1 failed | All existing regressions passed. Valid/rejected text import checks passed, but tapping the partially visible PDF grid cell did not deliver it to the app. PDFKit independently read the fixture correctly; the helper now targets the visible thumbnail and checks picker dismissal |
| Blind review | 1 technical UI pass, semantic failure | Exactly one approval, no retry; original false alignment retained |
| Student calendar/review/chat | 3 technical UI passes | Calendar 16.175s; grounded review 61.162s; two-turn conversation 58.759s. Quality qualifications above apply |
| Saved-review goal adoption | Passed, 37.898s | A lazy-row existence check had skipped the optional button in the earlier harness. A no-model case explicitly adopted it and verified persistence after reopening |
| Final import retry | Passed, 145.308s | All four destinations and all rejection cases completed through the native Files picker |
| Normal-store first attempt | Failed, 37.609s | Positive and no-match search passed, but keyboard deletion did not clear the native search field. The helper now uses the verified Clear text and Close controls and asserts keyboard dismissal |
| Restored normal installation | Passed, 49.561s | Original metadata restored, all test-container content removed, normal app populated and checked without smoke-store arguments |

Across all attempts there were **24 completed physical case executions: 16 passed and 8 failed**, plus the interrupted initial run. All **14 distinct cases** eventually passed their technical assertions, with zero final unresolved UI-test failures and zero skips among the explicitly enabled cases. The failures and corrections are recorded above. This does not convert the model relevance failure or partial instruction-following failure into passes. The normal default suite has seven active cases and seven opt-in fixture cases; all seven opt-ins were enabled at the relevant stage here.

One test-only build failed on an incorrect screenshot API and was corrected to `XCUIScreen.main.screenshot()`. The signed builds otherwise succeeded with the expected AppIntents metadata-skip warning. Previously observed runtime frame/device-diagnostic warnings did not correspond to a failing final app assertion. SwiftLint was not installed.

The Files test uses temporary `UIFileSharingEnabled` and `LSSupportsOpeningDocumentsInPlace` metadata so invented fixtures can be selected through the actual system picker. This is explicitly a test-build difference. Fixture generation, opt-in environment variables and setup are documented in [AppTests/Fixtures](../AppTests/Fixtures/README.md). Normal builds restore the original plist exactly. Optional fixture tests skip by default; the reported cases were explicitly enabled for this pass.

## Populated app

The installed final dataset contains Jordan Lee's academic profile, three subjects, five detailed assignments, five manually entered goals plus one explicitly adopted review goal, one genuine Apple review and one genuine two-turn conversation. It includes briefs, submitted work, tutor comments where results exist, guided and freeform reflections, dates, weighting/targets/formats and entered marks. Two graded assignments total 43 of 55 available marks. In-app records do not carry synthetic labels. The separate blind-feedback fixture and transient importer records are excluded from normal data.

The app was uninstalled again after fixture testing, then the normal signed build was installed with the original Info.plist restored byte-for-byte. The compiled app contains neither temporary Files-sharing flag. The populated normal-store test passed, and a subsequent launch without test arguments succeeded. Its data.json matched the populated input byte-for-byte (SHA-256 `a6b20af53fca4bde6a4eb5c7d7a3565025bb2349f2d17c7fe081624d9ba1f94f`). All 69 recorded source, test, fixture and asset hashes matched the final tested checkout. Final Home, Progress and saved-conversation screenshots were visually reviewed. No transient test store, imported fixture folder or blind-feedback record was included in the final installation.

## Limits

The device pass covers one iPhone 16 running iOS 27.2, using the Sydney timezone and an English interface. The code retains its iOS 17 guards, but this pass does not physically test every supported OS, hardware, locale or Dynamic Type/orientation combination. Subject credits received physical English-locale checks and Foundation parsing checks; locale combinations are not exhaustively tested.

The app has no login, biometric lock, cloud sync or network backend. Static inspection found no app networking or authentication API calls in App/Sources. That is not a network packet audit or a guarantee about operating-system services. Import originals are not stored as documents in the app's records; reviewed text is stored. No new cloud service or dependency was introduced.
