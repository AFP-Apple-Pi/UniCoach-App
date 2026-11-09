# UniCoach

Repository: https://github.com/AFP-Apple-Pi/UniCoach-App

A private, native iOS study companion for subjects, assignments, goals and reflections. It starts empty; the sample is synthetic and added only when requested. Records are stored locally in the app's Application Support directory. There is no account, network service or analytics.

Open `UniCoach.xcodeproj` in Xcode and select the shared UniCoach scheme. The app targets iOS 17 or later. Build for Simulator without signing:

```sh
xcodebuild -project UniCoach.xcodeproj -scheme UniCoach -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

For updates to an app already installed on a physical device, preserve its existing bundle identifier and development team. For a fresh, independent installation, use your own development team and a unique bundle identifier in Xcode's Signing & Capabilities settings, or pass `DEVELOPMENT_TEAM` and `UNICOACH_BUNDLE_IDENTIFIER` as build overrides. The project does not contain a personal team ID.

The Apple on-device mentor requires iOS 26 or later, eligible hardware, and an available Apple Intelligence model. The app shows the system availability reason. The separately selected contextual offline option is deterministic and is not AI. Each request requires fresh source selection and approval. You can edit the exact source text before approving; report history retains the approved snapshots and prompt. Model output can be inaccurate and should be checked.

Imports support UTF-8 text and PDFs containing selectable text, up to 2 MB and 100,000 extracted characters. Scanned PDFs need transcription before import. Review the extracted text before using it.

Run `swift test` for core tests. For manual verification, use only synthetic data, enable Airplane Mode, add the sample explicitly, and inspect the assignment and consent flow. Reports remain in local history after source edits or deletion. The UI smoke test uses a separate disposable synthetic data file and never resets the normal store.
