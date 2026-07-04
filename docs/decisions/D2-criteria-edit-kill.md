# D2 — Agent edits frozen acceptance criteria → kill whole loop

Date: 2026-07-04 · Owner-approved

## Decision

Checksum mismatch on `acceptance` fields → driver halts entire run
immediately. No revert-and-continue.

## Rationale

- Acceptance criteria = the exam. Agent touching them = gaming the exam
  = gravest offense in the system; every downstream signal becomes
  untrustworthy.
- False-positive cost is low: criteria live in JSON the agent has no
  legitimate reason to touch; accidental edits are rare. One restart on
  a rare false positive is cheaper than one gamed run trusted overnight.

## Alternatives rejected

- Auto-revert + warn + continue: keeps run alive but masks an agent
  persistently probing the exam
- Revert + count as story fail (ladder): middle path; rejected for v1 —
  adds machinery for a case that should never happen; revisit only if
  kills prove frequent

## Revisit when

- Kill triggers more than rarely AND inspection shows accidental (not
  gaming) edits → move to revert + count-as-fail
