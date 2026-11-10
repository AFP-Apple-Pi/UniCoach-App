# Repository guidance

Keep the app local-first and preserve explicit, per-request consent. Never send user data over a network or silently substitute one mentor engine for another. Tests and demonstrations must use synthetic content. Keep generated reports and approved source snapshots readable after source changes. Use the shared UniCoach scheme and a local signing override for physical devices; do not commit a personal development team.

For this user workflow, an Astra supervisor coordinates exactly two coding subagents and reviews their work, tests, and build validation.

Do not use em dashes in code, documentation, or user-facing text.

## Publishing workflow

The team reviews and agrees on changes verbally. After completing the requested work and appropriate validation, commit and push directly to `main` by default. Do not create pull requests unless the user explicitly requests one. Preserve collaborators' work, fetch and inspect remote changes before publishing, and never force-push or bypass repository protections.

## Swift and SwiftUI guidance

Adopt [Paul Hudson's SwiftAgents guide](https://github.com/twostraws/SwiftAgents/blob/70132f3d11561f45ccfab8823bb3d26bbe470b2f/AGENTS.md), reviewed on 2026-11-10. Before future Swift or SwiftUI implementation and review, read that pinned guide and follow it subject to the UniCoach exceptions below. Review changes before adopting a newer upstream revision. If the source cannot be accessed, use the checklist here and report that limitation.

### Working checklist

- Follow Apple's interface and review guidelines. Prefer native SwiftUI and modern Foundation APIs; obtain agreement before adding third-party frameworks.
- Use structured concurrency and async/await. Keep observable UI state actor-isolated; prefer Observation with appropriate ownership and bindings.
- Prefer safe error handling, localized search, and FormatStyle. Avoid force unwraps, legacy dispatch, and unnecessary type erasure.
- Use semantic, accessible buttons, Dynamic Type, NavigationStack, and typed destinations. Extract reusable View types and keep business logic independently testable.
- Prefer modern styling, clipping, change observation, scrolling, and layout APIs when supported. Avoid screen-global sizing and unnecessary GeometryReader usage.
- Organize code by feature, use consistent names, separate types sensibly, document intent, and keep secrets out of Git.
- Test core logic with unit tests. Use UI tests for behavior unit tests cannot establish. Run SwiftLint if installed.
- Prefer available Xcode MCP tools for documentation, builds, diagnostics, previews, and project editing. Verify API availability before use.
- Apply upstream SwiftData/CloudKit and string-catalog rules only when those technologies are actually in use.

### UniCoach compatibility and workflow exceptions

These project-specific requirements take precedence over conflicting upstream recommendations:

- Keep the current iOS 17 deployment target, Swift 5 language mode, and Swift tools 5.9 package baseline unless a separate requested change includes a reviewed migration. Upstream's iOS 26 and Swift 6.2 baseline is not authorization to change these settings.
- Check both OS and compiler availability. Use supported alternatives or availability guards for newer Tab, scrolling, collection, and other APIs; keep the iOS 17 path functional.
- Use Xcode 26 or newer when building the Foundation Models implementation. Guard that implementation for iOS 26 or newer and check runtime model availability. New mentor requests use Apple on-device AI only, with explicit per-request source approval, cancellation and honest availability. Do not expose an offline alternative or silently fall back. Preserve historical offline reports and their engine labels; the user explicitly requested this Apple-only policy on 10 November 2026.
- Preserve the local-first store, saved subjects and assignments, source snapshots, report history, and Maria's data model and logic. SwiftAgents does not authorize a SwiftData or CloudKit migration.
- Preserve the approved Figma design, including its typography and spacing, while supporting accessibility. Modernize touched code deliberately; do not turn a scoped change into an unrelated architectural rewrite.
- Keep existing core and UI regression coverage. Follow `Docs/DEVICE_TESTING.md` for device validation, use synthetic records, and obtain agreement before testing with private uploads.
- Keep the app named UniCoach. Preserve the installed bundle identifier and signing team when updating an existing installation; keep personal signing settings in the ignored local override.
- The Astra supervision requirement above applies to coding work. Documentation-only changes do not require coding subagents or an app rebuild.
- The publishing workflow above remains authoritative: validated, agreed changes go directly to `main`; the upstream PR heading does not require opening a PR.
