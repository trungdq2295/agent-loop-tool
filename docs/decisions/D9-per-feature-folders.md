# D9 — Per-feature folders: `.loop/features/<slug>/`, sequential multi-feature

Date: 2026-07-06 · Owner-approved

## Context

v2 had one flat `.loop/` = one PRD = one feature, forever. Real projects
run feature after feature; `init` refusing an existing `.loop/` forced a
manual wipe between features and threw away learnings. A single growing
`prd.json` would also make every iteration pay tokens reading OTHER
features' stories and notes.

## Decision

- Feature state is encapsulated per folder: `.loop/features/<slug>/`
  holds `prd.json`, `PRD.md`, `criteria.sum`, `QUESTIONS.md`, `logs/`,
  `REPORT.md`. Slug derives from the PRD's branch name (basename,
  sanitized).
- Shared, permanent, feature-agnostic state stays at `.loop/` root:
  `PROMPT.md`, `verify.sh` (layer-1 invariants), `learnings/` (feature 2
  must benefit from feature 1's lessons), `test-count` (the ratchet is
  project-global).
- The iteration agent reads ONLY its feature dir + shared learnings —
  the driver directive names the exact path. Token cost per iteration
  stays flat no matter how many features accumulate.
- Tool-side frozen state mirrors the layout: `state/<proj>/<slug>/`
  (snapshot + sums per feature). Feature A improving `verify.sh` no
  longer invalidates feature B's freeze.
- Lifecycle: `init` once per project; per feature `prd` → `run` → merge.
  Finished features stay in place as history — no archive step.
- `run <project>` auto-picks when exactly ONE feature is open (open =
  not all stories done); several open → demand the slug:
  `run <project> <slug> [max-iters]`.
- ONE run per working tree, enforced by a pid lockfile in the state dir.
  Parallel runs in one tree would fight over `git checkout` — folders
  don't fix that. True parallel = worktrees, BACKLOG.
- Legacy flat `.loop/` auto-migrates into `features/<slug>/` on the next
  prd/run/harvest — mid-flight features survive the upgrade.

## Alternatives rejected

- One growing prd.json with a `feature` field per story: token tax on
  every iteration; criteria checksum would churn across features; no
  isolation of logs/questions.
- Archive-on-completion (move finished feature aside): an extra
  lifecycle step and command for zero benefit over just leaving the
  folder in place.
- Parallel runs in one working tree: impossible to do safely — branch
  checkout, shelving, and verify all collide. Worktrees are the real
  mechanism (BACKLOG).

## Revisit when

- A feature needs >1 branch or a branch rename mid-flight (slug is
  derived from branch at prd time).
- Someone actually needs parallel — see BACKLOG "worktree parallel".
