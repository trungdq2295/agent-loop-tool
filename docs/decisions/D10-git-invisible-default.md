# D10 — `.loop/` is gitignored by default; `LOOP_GIT_MODE=tracked` opts in

Date: 2026-07-06 · Owner call (the D8 trigger fired — first real objection
was the owner's own)

## Decision

- `init` writes a single `.loop/` line into the project's `.gitignore`.
  The loop leaves ZERO trace in the repo: no status noise, no
  `chore(loop)` commits, no baton files in PRs.
- `LOOP_GIT_MODE=tracked loop.sh init …` restores v2 behavior: baton
  tracked, runtime artifacts ignored, mechanical sweep-commit per
  iteration. For teams that want baton history in git.
- Correctness is unaffected either way: every iteration reads the baton
  from DISK; git commits of `.loop/` were only durability polish. The
  sweep-commit is `|| true`-guarded and silently no-ops when ignored.

## What ignored mode costs (accepted)

- No git history of prd.json state transitions (iteration logs cover it).
- Baton doesn't travel on clone — a fresh clone re-runs `prd`.
- PRD not visible in the PR — put it in the PR description.

## What ignored mode fixes (beyond the noise)

The QUESTIONS.md branch-switch gap: tracked `.loop/` vanished from the
working tree when a shelved run restored the owner to main, so the
answer-file flow broke exactly when auto-shelve had triggered. Untracked
`.loop/` stays on disk across every branch switch — the answer file is
always where the report says it is.

## Revisit when

- A team explicitly wants PRD/baton review in PRs → they have
  `LOOP_GIT_MODE=tracked`; if many do, reconsider the default.
