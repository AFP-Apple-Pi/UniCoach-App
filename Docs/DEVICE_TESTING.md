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
3. Open the mentor. Confirm no source or engine is selected. Select submitted work and tutor feedback, redact a distinctive synthetic phrase and approve the contextual offline option. Check the saved snapshot excludes the redacted phrase and labels the engine as not AI.
4. Start and cancel a request, then reopen it and verify selection is empty. If possible while generation runs, edit or delete the source or assignment and confirm a stale report is not saved. Existing history should remain visible after deletion.
5. On eligible iOS 26 or later hardware, check the displayed Apple model availability and explicitly select it before generation. Inspect the saved source snapshots, exact prompt and output; check guidance against the supplied text. On unsupported hardware, verify the reason and do not expect model generation.

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
