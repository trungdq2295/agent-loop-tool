# Verify — design (settled 2026-07-04)

**Loop quality = verifier quality.** Weak verify → agent "completes"
garbage that passes weak tests. This doc specifies how the verifier is
built, protected, and improved. Rationale: [D7](decisions/D7-verify-protection.md).

## The pipeline (verify is a pipeline, not a file)

```
1. concrete criteria   PRD concreteness gate — "expired token → 410",
                       never "handles errors gracefully" (prd-step.md)
2. red-first tests     per story: write acceptance test → RUN → MUST fail
                       → commit red → implement → green. A test that
                       never failed proves nothing. (PROMPT.md rule)
3. mechanical guards   ratchet + criteria checksum + verify snapshot (below)
4. human reads TESTS   Phase 2 = read acceptance test files against the
                       PRD checklist. NEVER read implementation — the
                       exam is yours, the implementation is the machine's.
```

## verify.sh contract

- Exit 0 = healthy, non-zero = fail. Driver reads nothing else.
- Driver runs it with CWD = project root (script must not self-cd).
- Three blocks:
  - Block 1 — layer-1 invariants: THE per-project fill-in (suite,
    typecheck, lint — 2-4 commands)
  - Block 2 — test-count ratchet: count may grow, never shrink
    (backstop against test deletion, harness §2)
  - Block 3 — documentation only: finished stories' acceptance tests
    already run inside Block 1's suite (graduation flywheel)

## Protection — snapshot + checksum (prevent + tripwire)

```
FREEZE (end of prd phase):
  driver copies .loop/verify.sh → loop-tool/state/<project>/verify.sh
  (outside project dir; agent sessions confined to project → unreachable)
  + records checksum of the project copy

EVERY ITERATION:
  driver executes THE SNAPSHOT — edits to project copy have no effect
  + compares project copy checksum: mismatch = tamper ATTEMPT → kill run
    (same logic as D2 — the attempt itself makes all signals suspect)
```

## Known hole (open-eyed, not closed in v1)

Agent can game TEST CONTENT: keep test count, gut assertions. Ratchet
counts, doesn't read. v1 mitigation: red-first rule + human reads tests.
Escalation if real runs show gamed tests (tuning signals, D7): separate
test-writer session per story → mutation testing.

## Self-improvement — gated channels, never mid-run

Exam frozen DURING a run (student can't rewrite exam while taking it).
Between runs it grows:

1. **Automatic** — finished stories' acceptance tests graduate into the
   suite; next run's exam is harder with zero ceremony. The flywheel.
2. **Harvest proposals** — librarian mines failure logs for verifier
   weaknesses ("S4 flaked twice — propose retry detection"), stages a
   verify.sh upgrade proposal, human approves → applied BETWEEN runs →
   new snapshot at next freeze. (D6 extension)
3. **Tuning signals** — decision-log pages say when to upgrade guards
   (ratchet → mutation testing etc.). Human-paced.

Self-improving ≠ self-modifying-mid-flight. Every layer learns; nothing
learns unsupervised while running.
