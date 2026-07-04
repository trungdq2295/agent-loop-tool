# D3 — JSON for machine state, MD for human contract

Date: 2026-07-04 · Owner-approved

## Decision

Dual artifact, one format per reader: `.loop/PRD.md` (human) +
`.loop/prd.json` (machine). Agent reads both, indifferent.

## Numbers behind it

- JSON ≈ 10-20% more tokens than equivalent MD (braces, quotes, keys).
  At prd.json size (~330B ≈ 100 tokens) → ~15 tokens/iteration
  difference. Irrelevant.
- Decisive reader is the driver: bash + jq.
  `jq '[.stories[].passes] | all'` = 1 line, deterministic. MD checkbox
  parsing in bash = regex that silently breaks when agent reformats.
- JSON self-validates: broken syntax → jq fails LOUD next driver tick.
  Broken MD fails silent.

## Rationale

Exit decision cannot rest on regex guessing. 15 tokens/iteration =
price of deterministic gating. Owner (PM) never reads prd.json — PRD.md
and verbal read-back are the human surface.

## Revisit when

- Agent repeatedly corrupts prd.json on writes → move to v2: agent emits
  `RESULT: S3 passes` text line, DRIVER flips flag via jq (agent never
  writes the file)
- Stories grow numerous enough that whole-file read costs real tokens →
  reconsider current-story-only injection (rejected for now, see D4)
