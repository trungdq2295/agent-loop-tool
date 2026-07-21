# D12 — Cooperate with repo knowledge (CLAUDE.md), don't invent; CI is the reproducibility oracle

Date: 2026-07-20 · Owner call (from real-use failure, discussion logged before build)

## The failure this fixes

Owner ran the tool on a real shared-library repo. It bent the production
code to serve its tests — three concrete moves, one root cause:

- **Refactored prod code for testability.** It split a function into
  smaller pieces *only* so it could attach a unit test. The owner avoids
  this deliberately. Correct behavior: if a unit test cannot be added
  following the codebase's existing convention, DO NOT add it — skip or
  flag, never reshape the code to force a test onto it.
- **Added machine-specific branching to the codebase.** To make an
  integration-test setup work, it introduced `os === "macOS"` logic into
  the *production* code. That is "works on my laptop" leaking into the
  code itself, not just into verify.sh.
- **Non-reproducible gate.** The setup passed on the owner's laptop only;
  `verify.sh` held a machine-local check, so a green ratchet proved
  nothing — it would not pass anywhere else.

Root cause: **the tool acts on the agent's generic habits instead of the
repo's actual knowledge and conventions — and it bends the codebase to
fit the test instead of the reverse.** Today PROMPT.md tells the agent
how to work *in general* (red-first, narrow tests); nothing tells it how
*this* repo works, and nothing forbids editing production code purely to
enable a test. On a well-trodden repo that is fine; on a repo with
unusual constraints the agent invents and mutilates.

## Decision

- **Repo knowledge lives in the repo's `CLAUDE.md` — no new bespoke
  file.** `claude -p` auto-loads `CLAUDE.md` natively, so the knowledge
  reaches every iteration with zero load mechanism, zero per-iteration
  token wiring, and zero new convention for a team to learn (D8). This
  is the same channel D11 already chose for the workspace repo map.

- **`init` seeds/enriches `CLAUDE.md` — proposes, never overwrites.** The
  tool scans the repo and drafts additions: how it tests, the CI command,
  conventions to follow, and explicit "does NOT do X" absences. AI
  drafts, human approves — the same draft→gate→freeze crank used
  everywhere else. Existing `CLAUDE.md` is appended to / suggested
  against, never clobbered (trust + adoption). No `CLAUDE.md` → offer to
  create one; thin one → enrich.

- **CI is the reproducibility oracle for `verify.sh`.** Where the repo
  has CI (`.github/workflows`, `.gitlab-ci.yml`, `Jenkinsfile`), Block 1
  is derived from / cross-checked against the CI test command. CI has no
  laptop, so a check that passes locally but CI would not run is rejected
  at init. This closes the fake-green hole directly.

- **Tests conform to the code, never the code to the test.** New
  PROMPT.md hard rules for the build agent:
  - Do NOT refactor, split, or restructure production code for the sole
    purpose of making it testable. If a unit test cannot be added
    following the codebase's existing convention, skip it and write the
    reason to QUESTIONS.md — an untested-but-honest story beats a
    reshaped codebase.
  - Do NOT add environment/platform branching (`os === "macOS"`, host
    paths, machine-local flags) to production code to satisfy a test or
    its setup. Test setup lives in the test/CI layer, never in shipped
    code.
  - Conform to `CLAUDE.md`. If a story needs a *cross-cutting* pattern
    not in `CLAUDE.md` (test framework, build tool, CI setup), write it
    to QUESTIONS.md and stop — never introduce it unilaterally.
  PRD-PROMPT.md flags such criteria at PRD time, before the run, not at
  story 6.

## Why this shape (principle)

Two principles combine here.

*Tests conform to the code, never the reverse.* The purpose of a test is
to observe the code as it is. The moment the agent edits production code
to make a test easier — splitting a function, adding an `os === "macOS"`
branch — the test no longer measures the real thing, and the codebase
carries scars for the test's convenience. Testability pressure is fed
back to the human (skip + QUESTIONS.md), not resolved by mutating shipped
code.

*Spec precision scales with blast radius* (from D11). Inventing how a
repo tests, builds, or verifies is maximum blast radius — a wrong guess
poisons the gate and every downstream iteration. So it becomes an upfront
human decision (init-time CLAUDE.md + CI-derived verify), not an agent
guess. Per-story implementation detail stays free; cross-cutting
infrastructure and production-code shape do not.

Keep D11's build philosophy: the new intelligence is born as prompts and
init scan logic, not hardcoded policy. `loop.sh` gains only mechanics
(CI-config detection, CLAUDE.md draft/append, a QUESTIONS.md gate).

## Build slices (smallest first)

1. **CI-derived verify** — init detects CI config, proposes a Block 1
   that mirrors the CI test command; flag/refuse a hand-authored check
   that CI would not run. *Fake-green poisons the whole gate, so this
   ships first.*
2. **CLAUDE.md seeding at init** — scan + draft test/CI/convention/
   "does-not-do" sections; propose, human approves, never overwrite.
3. **Conform-don't-invent rules** — PROMPT.md hard rule + PRD-PROMPT.md
   pre-run flag for cross-cutting patterns absent from CLAUDE.md.

## Traps identified (design around, not after)

- **Clobbering a curated CLAUDE.md.** Many repos already have a good one.
  The tool must append/suggest, never overwrite — a destroyed CLAUDE.md
  is an instant-distrust event for a team (D8).
- **No CI at all.** Some repos have none. Then the reproducibility oracle
  is absent; fall back to build+lint and SAY SO loudly (relates to
  FEATURES F2, no-test-suite projects). Never pretend a local check is
  reproducible when nothing proves it.
- **CLAUDE.md drift.** Frozen-exam principle: the CLAUDE.md the PRD
  session read is the contract for that feature; note its state at PRD
  time so staleness surfaces early (same as the design-doc drift check).
- **Over-stuffing CLAUDE.md.** It loads every iteration — keep the
  seeded content tight (commands + conventions + absences), not prose.

## Alternatives rejected

- **New `.loop/repo.md` knowledge file.** A parallel channel nobody
  maintains, plus a load mechanism to build. CLAUDE.md already auto-loads
  and is the ecosystem standard. Rejected in favor of using it.
- **Let the agent infer conventions per iteration.** That is exactly the
  current behavior that failed — inference from generic habit. The whole
  point is to make the knowledge explicit and human-gated once.
- **Hard-block every new pattern.** Too rigid — a genuinely greenfield
  repo needs the agent to establish patterns. The line is *cross-cutting
  infrastructure* only; per-story choices stay free.

## Priority

This precedes the validation run (docs/validation-run.md). The run would
have failed on exactly this — it is the weak layer the harvest log would
have named. Fix here, then validate a tool worth validating.

## Revisit when

- First repo with no CI forces the F2 (no-test-suite) fallback to be real.
- Skill-builder repo exists (D11) → convention knowledge may move there
  as an org catalog, CLAUDE.md seeding reads from it.
