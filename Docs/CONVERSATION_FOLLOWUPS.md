# Mentor follow-up verification

## Change

Direct conversation replies now create a fresh Apple on-device session from the explicitly approved student and mentor message roles, then send the current request and newly approved sources. The actual native transcript is measured against the runtime context budget and retained in the processing audit. This is not a persistent session carrying hidden private source snapshots. Long requests continue through bounded processing of the full approved material, with an explicitly identified current request.

Routing can interpret a short reply using the preceding mentor offer. Timing constraints remain grounded in student messages only. The latest student request takes priority when changing topic or schedule.

New response instructions prohibit questions and invitations to reply. A bounded text check detects question punctuation and common interrogative or solicitation forms. Ordinary answers get at most one audited rewrite. If that is still unsuitable, the app honestly identifies an incomplete answer and labels general starting guidance. Review explanations and plan tasks are checked before use; exact original evidence quotations and historical records are preserved. This textual guard does not establish semantic perfection for every possible phrasing.

## Method

The fictional legacy and live cases were fixed in `AppTests/Fixtures/mentor-followup-evaluations.json` before generation. Each version received one actual model attempt per turn. The authored legacy offer is explicitly marked as a fictional historical fixture, not an Apple result. The live conversation starts from the existing fictional student fixture, approves brief/work/feedback only for its first turn, and uses visible conversation history alone thereafter.

Technical assertions check approval, saving, no question punctuation and relaunch persistence. Human review separately checks whether each answer advances the conversation and addresses the latest request. Different wording or a generic fallback does not count as semantic success. Original first responses are retained.

## Version 1 findings

The legacy Yes response gave concrete revision actions instead of repeating the evaluation or another offer. It was brief and omitted the earlier stale-availability point.

The live conversation progressed from evaluation to three revision actions and then quantitative transport-data guidance. However, the first response asserted that assessment criteria were met and suggested naming three students without support. The second response propagated that suggestion. The statistics transfer was relevant but vague and referred to similar data-cleaning steps that had not been established.

The final 20-minute, one-session request was falsely declined. The intent router recognised a timed plan, but extraction emitted a 20-minute minimum and omitted the session count. No plan-writing call ran. The response was question-free but did not satisfy the requested feasible plan.

These are retained failures, not counted as a fully successful conversation. Protected local device bundles retain the unchanged first responses, exact prompts, role entries and model outputs. Full conversation contents are not exported into the repository.

## Version 2 correction

General instructions now preserve anonymity and pseudonyms, distinguish sample counts from identities, prohibit unsupported overall grades or claims that every criterion is met, and direct the mentor to correct unsupported earlier advice. No extra model stage was added.

The existing explicit-allocation parser now recognises common count/duration ceiling statements in either order. Ordinary earlier discussion no longer blocks a new clear allocation; unresolved earlier timing and availability still require the verified model path. Maximum budgets retain their meaning, and locally allocated slots must satisfy the numeric constraints and a separate semantic check of the original request.

## Observed results and release choice

Version 2's legacy acceptance produced concrete revision actions without repeating an offer or asking a question. Its four-turn live conversation progressed from report feedback to three revision steps, then a different assignment topic, then one 20-minute session with a task and completion check. The last request's ceiling and session count were preserved. No new response asked a question or solicited a reply.

This was a partial semantic result, not a complete pass. The first answer omitted supported strengths. The three-step reply recommended a direct quote without establishing that original verbatim notes existed. The transfer reply did not adequately explain both the reusable approach and the necessary adaptation. The saved conversation retains these weaknesses unchanged for manual review.

A third version added ordinary-answer instructions about covering every requested part and quotation integrity. Its single live run was worse: the three-step request and transfer request received missing-information boilerplate, and the plan's semantic verifier rejected the generated task despite valid locally allocated timing. The app saved a generic fallback. That version was not selected for release. Its unchanged outputs and audits remain in protected local test artifacts.

The final code restores Version 2's ordinary-answer instructions. It also corrects deterministic failure text: an unverified drafted plan no longer falsely claims the student's timing is inadequate. There are no extra model retries. Role-separated approved history, explicit current-turn priority, bounded no-question handling, and the timing-parser correction remain.

The additional model check is not an independent truth guarantee. Useful follow-ups improved in the observed Version 2 run, but answer completeness, quotation recommendations, and occasional false rejections still need user review. Long-context summaries retain their previously documented potential to omit details.

## Final validation

On 11 November 2026, all 103 core tests passed. The final signed build passed with Xcode 27.2. Three physical iPhone 16 regressions passed with zero failures: composer accessibility (29.125 seconds), consent reset (33.488 seconds), and actual Apple two-turn conversation, persistence and deletion (67.956 seconds). Final compiled source hashes were verified unchanged. SwiftLint was unavailable; the build emitted the expected AppIntents metadata-skip warning.

The two semantic versions preceding the rejected third version also completed their UI assertions: Version 1 legacy/live in 24.643/95.264 seconds, Version 2 legacy/live in 21.790/93.208 seconds, and Version 3 live in 87.656 seconds. These technical passes are separate from the semantic failures described above.

After those isolated tests, the normal store was still byte-identical to its protected pre-task backup. At the user's request, exactly four actual Version 2 answers were added as one saved conversation. Every pre-existing record and raw field was independently verified unchanged. Source snapshots, approved visible history and actual generation audits were retained; only the new answers' top-level test assignment links were detached. No test profile, assignments, subjects or goals were imported. A normal app launch succeeded, and readback matched the merged file byte-for-byte.

Open AI Mentor, then Saved conversations, and choose the conversation beginning “How did I do on this campus study-spaces report”. Its first responses are unchanged, including the limitations above. Full generated transcripts remain in the app and protected local artifacts; repository documentation contains outcome summaries only.
