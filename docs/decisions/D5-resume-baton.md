# D5 — Mid-story continuity via git + notes baton

Date: 2026-07-04 · Owner-approved

## Decision

Sessions are disposable; continuity lives in files. A story interrupted
(turn cap, crash) resumes automatically next iteration via three
mechanisms:

1. **Commit early, commit often** (PROMPT.md rule): every green sub-step
   = WIP commit on loop branch (`wip(S3): ...`), squash at story end.
   Cutoff loses since-last-commit only, not the iteration.
2. **notes = mandatory handoff baton**: before any session ends, agent
   updates story `notes`: done / next / suspicion. The resume protocol,
   not a diary.
3. **Driver injects failure-log tail** on retry (part of fail ladder).

## Rationale (the triangle)

Owner tension: long session → hallucination risk; early exit → task
pending. Resolution:

- small stories (PRD story-size gate: must fit ~30-60 turns) → session
  stays focused, no rot
- baton → cutoff cheap, resume automatic, task continues "across
  sessions" without shared memory
- caps (D1) → pure insurance, never the scheduling mechanism

## Revisit when

- Resumed sessions repeat work already done → notes too thin; strengthen
  PROMPT.md baton requirements
- WIP commits pollute history reviews → enforce squash-at-story-end in
  verify or driver
