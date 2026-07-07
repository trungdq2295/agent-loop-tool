# Backlog — noted, NOT built

Ideas with an owner decision behind them but no implementation. Pull an
item only when its trigger fires. Nothing here is supported today.

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
