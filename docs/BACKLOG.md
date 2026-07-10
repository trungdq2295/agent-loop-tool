# Backlog — noted, NOT built

Ideas with an owner decision behind them but no implementation. Pull an
item only when its trigger fires. Nothing here is supported today.

## Examiner stage — machine-verified "it works", not just "tests green"

Trigger: first multi-story run at the owner's work proves the loop's
value; examiner is what removes the owner's remaining per-feature cost
(final manual verification). Owner priority 2026-07-09: correctness
over token cost.

Today COMPLETE = agent claims + tests the agent itself wrote — the
integration level self-grades. The examiner breaks that: a NEW loop
phase after all stories pass, before the COMPLETE verdict:

- fresh session, NOT the implementer — gets the frozen acceptance
  criteria as a checklist and judges only observable behavior
- boots the real app (env contract below), exercises each criterion as
  a user would (browser automation for UI, curl for API, CLI for CLI)
- writes PASS/FAIL per criterion + cited evidence (output, screenshot)
  into REPORT.md; any FAIL → verdict withheld, feature reopened
- softer than deterministic tests (LLM judgment) — mitigations: runs
  once at the end, must cite evidence, findings harden into permanent
  e2e tests over subsequent features

## Env contract — declared boot/observe hooks per repo

Trigger: examiner stage (it needs this to see anything), or first
backend feature where "works" means "check the service's logs".

Verifiability is a codebase property — an examiner can only check what
the repo exposes. `.loop/env.sh` with four hooks, filled at init
(auto-detect docker-compose, ask otherwise): `boot`, `ready` (health
check / known log line), `logs` (where, what shape), `teardown`.
Frozen criteria say WHAT must be true; env.sh says HOW to observe it.
Same contract later composes across services (multi-service tier 3).

## Scoped verify — only changed services in a monorepo

Trigger: owner's work monorepo makes full-suite verify painfully slow
per iteration (accept the pain first; optimize on evidence).

Block 1 runs everything every iteration. Scoped: driver detects which
service folders the iteration touched (git diff vs previous iteration)
and runs only their suites, full suite still gates the final COMPLETE.
Token/time optimization — LAST by owner priority (correctness first).

## `prd --doc` flag — first-class design-doc-fed PRD

Trigger: the chat-injected doc flow (PRD-PROMPT §1b, owner's working
model: design doc first, feed the tool) proves itself at work AND the
manual "read docs/x.md" first message becomes annoying ceremony.

`loop.sh prd PROJECT label --doc path/to/design.md` injects the doc
into the PRD prompt directly and biases the session to validation mode
(translate-or-flag, HOW demotion, drift check) without the PM having to
say anything.

## Worktree parallel — run several features of one project at once

Trigger: sequential multi-feature (D9) proven in real use AND a real
need to run two features simultaneously.

Two loops in one working tree can never work: they fight over
`git checkout`, auto-shelve, and every file on disk. The mechanism is
`git worktree` — each feature gets its own working copy of the repo:

- `run` creates/reuses a worktree per feature (e.g.
  `<project>-worktrees/<slug>/`), runs the loop inside it on the
  feature's branch, locks per worktree instead of per project
- worktree lifecycle: create on first run, remove after merge (or a
  `loop.sh clean` command)
- shared `.loop/learnings/` needs a merge story (two parallel features
  both append learnings on their own branches)
- merge conflicts between parallel features remain the human's problem —
  the tool only isolates the runs, it cannot un-conflict the code

## More init auto-fill detectors (python, go, rust, make)

Trigger: first teammate on that stack adopts the tool — build the
detector against THEIR real repo, not a guess (owner call 2026-07-06:
js + java first, others when needed).

Sketch, same first-marker-wins ladder as npm/maven/gradle in cmd_init:
- `go.mod`        → `go build ./...` + `go vet ./...` + `go test ./...`
- `Cargo.toml`    → `cargo build` + `cargo test`
- `pyproject.toml` / `pytest.ini` → `pytest`
- `Makefile` with a `test:` target → `make test`

Until then these stacks fill Block 1 by hand (3 lines, once per
project); the prd test-runner gate already recognizes their runners.

## Defender/endpoint-interruption hardening

Trigger: a second freeze/state write gets corrupted by an external
process (TCC revocation, antivirus, disk-full) despite the half-frozen
recovery path in `run`.

Make every multi-step state mutation write-to-temp + atomic rename, so
interruption can never leave a partial state at all.
