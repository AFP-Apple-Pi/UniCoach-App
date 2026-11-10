# Mentor quality checks, 10 November 2026

This revision adds feedback relevance checks and constrained study planning. It improves several observed failures, but it does not establish reliable interpretation for every tutor comment or subject. The same Apple on-device model performs the semantic checks, so correlated mistakes remain possible. Exact quotations establish text identity, not the truth of an interpretation.

## Request and evidence handling

Every request still needs explicit approval. Only selected source snapshots and the approved visible conversation enter processing. Previous source snapshots are not silently reused. Apple on-device AI is the only engine for new requests. Cancellation, source edits, deleted conversations, one-use approvals, and stale completion checks remain in force before and after asynchronous model work. There is no network or model fallback.

The aggregate limit remains 50,000 characters. Long requests process every approved section in bounded sessions; summaries can omit details. The saved record distinguishes the full approved input from actual model calls. Additional target, relevance, finding-check, intent, constraint, and plan-check calls retain their real prompts and outputs. The pipeline has a finite 256-call ceiling, with no automatic retry or self-repair loop.

Paired work and feedback use a feedback-only first pass to identify exact named targets and whether the tutor is praising, requesting improvement, or both. Vague references and instructions embedded in feedback do not authorize a specific criticism. A separate pass compares eligible feedback against the work. Valid partial feedback can proceed while unsupported portions are disclosed. Each proposed finding then needs an exact original work/feedback pair and a further relation check. Unsupported findings cannot become goals. Generic clarification does not assert a certain mismatch when the model is unsure.

Generated references are validated against trusted source IDs. An extra target or relevance entry can be discarded only when every expected eligible ID is present exactly once; it is never mapped onto another source. Missing or duplicate expected IDs still decline the collection. Feedback excluded by an earlier check never becomes eligible again through an extra classification. Invalid exact target quotations exclude the affected item. New advice hides internal W/F passage aliases while preserving exact quotations and the raw processing audit. Historical saved records remain decodable and their raw audits remain unchanged.

## Study plans

A narrow, general local grammar recognizes explicit session counts and durations in the student's current question. It does not take timing instructions from source documents or quoted examples. Complete recognized allocations supply authoritative session durations; the model fills only the task and completion check for each slot. The original current and prior student questions are still checked against the resulting plan. Changed current allocations can supersede earlier allocations without inventing weekdays.

Clear planning requests that contain additional or unsupported constraints enter the verified structured planning path or ask for clarification. They do not silently become ordinary advice. Ordinary questions remain ordinary answers. Numeric provenance, count and duration bounds, exact slot coverage, daily limits and conflicting totals are validated. The app does not silently rewrite an invalid model plan. Supported plans have at most 12 sessions; unsupported expressions may need clarification rather than a guessed schedule.

## Evaluation method

Eleven semantic scenarios were fixed before the first model run, followed by one mechanical 50,000-character regression. Each case had one first attempt per implementation version. Outputs were retained even when poor. A new version followed a general schema or validation change, not repeated generation until a preferred answer appeared. Tests ran in the separate fictional `ui-smoke.json` store. The existing normal student data was not used as model input.

A passing XCUITest establishes interaction, approval, saving and reopening, not useful or correct advice. The reviewed fictional [request/output evidence](QA/mentor-quality/) contains actual processing steps. Deterministic clarification messages and session formatting are identified separately from model output. The original [alpha findings](ALPHA_TESTING.md) remain historical evidence.

### Earlier first outcomes

| Version | Technical cases | Observed semantic failures and resulting general change |
| --- | ---: | --- |
| V1 | 2 passed | Redundant overall relevance and ID lists contradicted each other, falsely blocking a coherent case. Replaced with one classification per trusted ID and a locally derived aggregate. |
| V2 | 12 passed | Vague feedback became invented specific criticism; mixed feedback was falsely blocked by malformed multi-ID strings; constrained plans misrouted or invented metadata. Added feedback-only targets, typed citation indices, typed intent/constraint schemas and exact provenance checks. |
| V3 | 5 passed | A single changed-case quotation blocked valid comments; generic target text still became specific advice; requests could become praise; model-authored days and redundant totals blocked feasible plans. Added per-item exact target filtering, specificity and intent fields, and authoritative time slots. |
| V4 | 12 passed | Vague and unrelated cases withheld advice, three 20-minute sessions worked, and impossible limits explained 90 versus 60 minutes. Two-session requests still misrouted or carried phantom old daily limits. A fabricated extra target ID blocked valid mixed feedback. Added explicit allocation routing and strictly isolated unknown extra target entries. |
| V5 | 6 passed | The two-session update, mixed feedback, vague feedback, embedded instructions and three-session plan met their primary expectations. A coherent standalone review falsely abstained when a later stage returned an already-ineligible extra ID. Applied the same eligible-only isolation rule to that stage, preserving strict coverage and exclusion. |

V4 also exposed remaining model limitations: a request to separate observations from inferences was labeled as praise; a database-normalisation plan used a conceptually weak query task; embedded-instruction feedback was safely rejected but lost its legitimate portion. These are semantic errors or omissions despite successful technical workflows.

## Final validation

The final checkout passed all 98 core tests. Core-only line coverage was 96.72% with tests and generated entry points excluded; this does not measure SwiftUI or model correctness. The signed Xcode 27.2 build passed for iPhone 16 running iOS 27.2, with only the expected App Intents metadata warning. Source hashes were recorded for all 73 app, test and core files. SwiftLint was not installed.

The final physical regressions passed: accessibility at the largest text size in dark mode (28.869 seconds), per-request consent reset (33.502 seconds), and a real saved two-turn Apple conversation with exact history, reopening and deletion checks (75.871 seconds). All three passed on the final build. The 12 distinct evaluation scenarios had 38 first-attempt case executions across six implementation versions, all completing their technical UI assertions; semantic failures are recorded separately below. The final V6 coherent review completed in 65.994 seconds.

The tested app was installed as an update with the existing bundle and signing identity and launched without test arguments. Its normal data file was byte-for-byte identical to the protected pre-change copy, and the normal process remained running. Existing profile, subjects, assignments, goals, reports, source snapshots and conversations were preserved. All new model evaluations remained in the isolated test store. No temporary file-sharing metadata or production seeding code was added.

### Final scenario assessment

| Scenario | Evidence version | Human assessment |
| --- | --- | --- |
| Two 45-minute sessions, then changed to two 20-minute sessions | V5 | Passed the primary scheduling requirement: exact durations, separate tasks and end checks, latest budget respected. The example-writing task must use existing notes rather than invent evidence. |
| Mixed design and unrelated chemistry feedback | V5 | Two useful improvement findings for the design comments, chemistry excluded, partial-review notice. |
| Vague feedback | V5 | Qualified clarification after the feedback-only pass, no invented criticism, findings or evidence claims. |
| Coherent feedback | V6 | Two actual praises and one requested anonymised-example improvement, with unsupported links excluded and a partial-review warning. A praise next-step still asks for redrafting instead of purely repeating the strength; other valid comments were omitted. V5 false abstention is retained. |
| Embedded instructions plus a legitimate comment | V5 | One legitimate improvement retained, injected instructions excluded, partial-review notice. |
| Unrelated chemistry feedback | V4 | No advice or evidence claims; clarification. |
| Unrelated domains with shared protocol/network vocabulary | V4 | No advice; clarification despite overlapping words. |
| Unrelated feedback in chat | V4 | No advice; clarification. |
| Three 20-minute sessions | V5 | Three distinct tasks and end checks with exact 20-minute slots: read normalisation rules, revise a schema, compare normalised and denormalised tables. The verified fallback path also remains useful. |
| Three sessions of at least 30 minutes, only 60 minutes total | V4 | Correct conditional explanation that at least 90 minutes is needed and asks which limit should change. |
| Ordinary observation versus inference question | V4 | Useful distinction without forcing a timed plan. |
| 50,000-character request | V4 | Exact contiguous chunks cover all 50,211 UTF-16 units of the original framed prompt; four actual calls; full current question in the final prompt. The answer still omits the ending twelve-month recommendation. |

V4 results above cover paths whose actual inputs and decisions were not changed by the final isolated-reference and explicit-allocation fixes. V5 adds the exact-allocation branch and unknown-extra-target isolation; V6 applies the same strict eligible-only isolation to relevance output; focused V5 cases exercise those changes. Core regression tests additionally reject quoted or negated allocations, conceptual questions, ordinary imperative requests, extra breaks, days and unresolved prior limits from the deterministic allocation path. This is a conservative English grammar, not complete natural-language understanding.

## Remaining limitations

The fixed primary examples now produce useful mixed-feedback advice and explicit session plans, but the system is not semantically perfect. A model can still mistake a requested change for praise, exclude valid feedback, make a weak subject-specific suggestion, or omit details during long-context summarisation. The additional check is another call to the same model, not an independent authority. Tasks that ask for an example must use genuine existing notes; the app does not supply or authorize invented interview evidence. Review the exact quotes and advice before adopting a goal.

Unsupported phrasing, decimal time expressions, implicit availability and complex historical constraints can require clarification. Local allocation recognition is conservative English grammar rather than a complete parser. The device results describe the installed Apple model at this time, not all supported devices or future model versions.
