# D8 — Team adoption is a design constraint

Date: 2026-07-05 · Owner call

## Context

The tool's end goal is rollout to the owner's team, not solo use. A
skeptical teammate's first objections will be git-shaped: "why is your
tool committing `.loop/` into our repo?" Design decisions must survive
that conversation.

## Decision

- Team adoption friction is a first-class design input from now on.
- No code path may hard-assume `.loop/` is git-tracked. The baton is
  read from DISK each iteration; git commits are durability, not
  correctness. (Already true today: the mechanical commit is
  `|| true`-guarded and no-ops when `.loop/` is ignored.)
- Nothing more is built on speculation (D4: speed-first). A
  configurable git strategy is BACKLOG, not supported — see
  docs/BACKLOG.md. Build it only when a real teammate objection
  defines which mode is needed.

## Revisit when

- First teammate onboards → collect the actual objection, pull the
  matching backlog item.
- Tool gets a second real user → also revisit onboarding docs (the
  "only command you retype is `loop.sh run`" principle becomes the
  pitch).
