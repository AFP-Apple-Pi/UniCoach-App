# Repository guidance

Keep the app local-first and preserve explicit, per-request consent. Never send user data over a network or silently substitute one mentor engine for another. Tests and demonstrations must use synthetic content. Keep generated reports and approved source snapshots readable after source changes. Use the shared UniCoach scheme and a local signing override for physical devices; do not commit a personal development team.

For this user workflow, an Astra supervisor coordinates exactly two coding subagents and reviews their work, tests, and build validation.

Do not use em dashes in code, documentation, or user-facing text.

## Publishing workflow

The team reviews and agrees on changes verbally. After completing the requested work and appropriate validation, commit and push directly to `main` by default. Do not create pull requests unless the user explicitly requests one. Preserve collaborators' work, fetch and inspect remote changes before publishing, and never force-push or bypass repository protections.
