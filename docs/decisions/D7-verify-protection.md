# D7 — Verify protection: snapshot + checksum; improvement via gated channels

Date: 2026-07-04 · Owner-approved

## Decision

- Driver executes a SNAPSHOT of verify.sh stored outside the project
  (loop-tool/state/<project>/), taken at freeze. Agent edits to the
  project copy have no effect.
- Checksum tripwire on the project copy every iteration: mismatch =
  tamper attempt → kill whole run (same logic as D2).
- verify.sh self-improves only BETWEEN runs: automatic test graduation,
  harvest-staged upgrade proposals (human-approved), tuning-signal
  driven guard upgrades. Never mid-run.

## Alternatives rejected

- git review next morning: gamed run trusted all night
- chmod read-only: agent runs as same user, can chmod back
- checksum alone (detect-only): run dies AFTER edit; snapshot makes the
  edit pointless in the first place — prevention + tripwire beats
  detection alone
- agent may improve verify.sh mid-run ("self-improvement"): student
  rewriting the exam while taking it; all signals become circular

## Known hole accepted in v1

Test-content gaming (keep count, gut assertions). Mitigated by
red-first rule + human-reads-tests. NOT closed mechanically.

## Revisit when

- Real runs show gamed/weakened tests despite red-first + Phase 2 →
  escalate: separate test-writer session per story; then mutation
  testing (strongest machine answer)
- Snapshot/state dir management becomes friction across many projects →
  reconsider location (e.g., .git/loop-state/)
