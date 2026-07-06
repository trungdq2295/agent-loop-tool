# Backlog — noted, NOT built

Ideas with an owner decision behind them but no implementation. Pull an
item only when its trigger fires. Nothing here is supported today.

## LOOP_GIT_MODE — configurable git strategy for `.loop/`

Trigger: first real teammate objection to tracked `.loop/` in a shared
repo (D8). Build only the mode that answers the actual objection.

Sketch:
- `tracked` (today's behavior, stays default) — baton committed per
  iteration on the feature branch; recommend squash-merge
- `ignored` — whole `.loop/` gitignored; loses git crash-recovery and
  branch-carried state, everything else works
- `scrub` — tracked during the run, `git rm -r .loop` before PR-ready
