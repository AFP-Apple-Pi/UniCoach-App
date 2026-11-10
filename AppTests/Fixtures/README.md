# Physical alpha fixtures

The fixtures contain invented coursework and profile data. The opt-in tests run on a physical iPhone and use the isolated `ui-smoke.json` store in a Debug build. Keep raw app-store dumps and result bundles outside the repository. Reviewed fictional model evidence for this alpha pass is recorded under `Docs/QA`; it contains no previous user data.

Set the values below for the signed build and paired test device. Use the UniCoach scheme and the existing signing configuration to build for testing and install the app.

```sh
device='<paired device identifier>'
bundle='<signed UniCoach bundle identifier>'
test_run='<path to a temporary copy of the generated .xctestrun>'
```

Add the environment variable for the case to the UI test target's `EnvironmentVariables` in the temporary `.xctestrun`. Run the selected case against the physical device.

```sh
case_name='testAlphaCalendarAcrossMonths'
xcodebuild test-without-building -xctestrun "$test_run" \
  -destination "platform=iOS,id=$device" \
  -only-testing:"UniCoachUITests/UniCoachUITests/$case_name"
```

## Files import

Generate ten invented text and PDF files with Python 3.

```sh
python3 AppTests/Fixtures/make_import_fixtures.py '/private/tmp/Alpha Fixtures'
```

Save an exact copy of `App/Info.plist` and record its SHA-256. For the temporary test build, set `UIFileSharingEnabled` and `LSSupportsOpeningDocumentsInPlace` to true. Build and install that app, then copy the generated folder to its data container.

```sh
xcrun devicectl device copy to --device "$device" --domain-type appDataContainer \
  --domain-identifier "$bundle" --source '/private/tmp/Alpha Fixtures' \
  --destination 'Documents/Alpha Fixtures'
```

Set `UNICOACH_ALPHA_IMPORT_FIXTURES=1` and run `testAlphaFileImport`. The case opens **On My iPhone > UniCoach > Alpha Fixtures** and checks the Files picker, editable preview, acceptance, cancellation and saved text for all four import destinations. It checks blank text, invalid UTF-8, an image-only PDF, excessive byte size, excessive extracted text length and an unsupported file. The unsupported file can be filtered by the system picker or rejected by the app. The test reports which occurred.

Restore the exact plist and compare its hash before rebuilding the normal signed app. Remove the temporary folder from the device after collecting the test evidence.

## Calendar and Apple Intelligence

Choose `student.json` or `blind-feedback.json` for the case and copy it to the isolated store before launching the test. This overwrites the isolated fixture, so export any wanted results first. The app must be stopped for the copy. The destination is distinct from the normal store at `Library/Application Support/UniCoach/data.json`.

```sh
fixture='AppTests/Fixtures/student.json'
xcrun devicectl device copy to --device "$device" --domain-type appDataContainer \
  --domain-identifier "$bundle" --source "$fixture" \
  --destination 'Library/Application Support/UniCoach/ui-smoke.json'
```

| Case | `UNICOACH_ALPHA_MODEL_FIXTURE` | File | Check |
| --- | --- | --- | --- |
| `testAlphaCalendarAcrossMonths` | `student` | `student.json` | November and December 2026 markers and assignment links. The test uses Australia/Sydney due days and navigates from the device month on Gregorian calendars within 36 months of the fixture. |
| `testAlphaGroundedAssignmentReview` | `student` | `student.json` | Real on-device structured review of the approved work and tutor feedback. If Apple returns an actionable step, the test also adopts it as a goal. |
| `testAlphaAdoptSavedReviewGoal` | `student-saved-review` | Retained isolated output from the student review | Adopt an unadopted next step in an already saved report. Verify the linked goal in Progress and after relaunch without generating another report. |
| `testAlphaRetainedAppleConversation` | `student` | `student.json` | Two real on-device turns with explicitly approved assignment sources on the first turn and only visible conversation history on the second. |
| `testAlphaBlindUnrelatedFeedback` | `blind` | `blind-feedback.json` | First on-device result for tutor feedback about an unrelated assignment. The test records the actual outcome without prescribing what the model should infer. |

The Apple cases require a compatible iPhone with the on-device model ready. Each generation requires an explicit approval in the app. Export the isolated store and result bundle before running a test that resets the fixture. Cases skip when the corresponding opt-in environment variable is absent.

## Populated normal-store smoke check

After installing the normal signed build and populating the test device with the fictional student records, set `UNICOACH_ALPHA_NORMAL_FIXTURE=student` and run `testAlphaPopulatedNormalLaunch`. It opens the app without smoke-store arguments, verifies the Jordan Lee greeting before capturing screenshots, and reads the profile, catalogue, positive and no-match subject search, progress, saved Apple report and two-turn conversation. It does not change records or start an AI request.
