# Driver — design (settled 2026-07-04)

The loop system = 3 subsystems: **context store** (what agent knows),
**harness** (what agent may do), **driver** (when agents run). This doc
specifies the driver. All knobs owner-approved 2026-07-04; rationale and
tuning signals live in docs/decisions/ — read the relevant D-page BEFORE
changing any value here.

## What the driver is

Dumb bash. Zero intelligence by design:

- Agent cannot be trusted to judge itself — driver holds the stopwatch
  and the exam.
- Bash cannot hallucinate, cannot be persuaded, costs no tokens.
- All intelligence lives in the agent (does work) or files (hold truth).
  The driver only spawns, checks, counts, and decides mechanically.

## Responsibilities — SETTLED

1. **Spawn** one fresh `claude -p` session per iteration (fresh context,
   no rot; files are the only memory).
2. **Verify** after every iteration by running `.loop/verify.sh` —
   outside the agent's reach, machine truth.
3. **Guard criteria** — checksum acceptance criteria at start; recheck
   every iteration.
4. **Exit** only on dual condition: all stories claimed passing
   (`passes` flags) AND verify green. Never one alone.
5. **Circuit-break** — consecutive verify failures → halt, write
   `.loop/BLOCKED.md` for the human.
6. **Isolate** — run on a `loop/run-*` branch, never main/master. Bad
   run = delete branch.
7. **Log** every iteration (agent output + verify output) to
   `.loop/logs/`.

Settled today (harness.md, prd-step.md — driver enforces):

8. **Per-story fail ladder** — driver owns `attempts`/`status` in
   prd.json: fail 1 retry, fail 2 inject "different angle", fail 3 mark
   story `blocked`, move on. All done-or-blocked → exit + morning report.
9. **Model routing** — pass `--model` per session; escalate sonnet →
   opus on a story's attempt 3 (brain before human).
10. **Phase 0 subcommand** — `loop.sh prd <project>` spawns the
    interactive PRD session (opus). Loop mode refuses a project with no
    frozen-checksum record.
11. **Morning report** — on any exit (complete, blocked, cap), write
    `.loop/REPORT.md`: per-story outcome, attempts, notes, NOTES.md
    items, cost/iteration count.

## Knobs — SETTLED (owner-approved 2026-07-04)

| # | Knob | Value | Rationale |
|---|---|---|---|
| P1 | Per-loop circuit breaker | 3 consecutive verify fails | [D1](decisions/D1-caps-and-breaker.md) |
| P2 | `--max-turns` per iteration | 80 | [D1](decisions/D1-caps-and-breaker.md) — typical story 35-75 turns |
| P3 | Max iterations default | 25 (CLI-overridable) | [D1](decisions/D1-caps-and-breaker.md) — overnight-sized |
| P4 | Criteria edited by agent | kill whole loop | [D2](decisions/D2-criteria-edit-kill.md) |
| P5 | Dirty tree at start | refuse on modified TRACKED files; `.loop/` + untracked exempt | safer, discardable run; untracked files don't threaten isolation (branch delete leaves them) |
| P6 | Allowed tools | Edit,Write,Read,Bash,Glob,Grep | default accepted; Bash constrained by harness ring-1 DENY rules |

## Resume protocol (mid-story continuity — [D5](decisions/D5-resume-baton.md))

Sessions disposable; continuity in files. Interrupted story (turn cap,
crash) resumes next iteration via:

1. WIP commits survive on the loop branch (commit-often rule, harness.md)
2. story `notes` = handoff baton (done / next / suspicion)
3. driver injects failure-log tail into the retry prompt (fail ladder)

A cutoff therefore loses only since-last-commit work — the next fresh
session continues the story, it does not restart it.

## Speed-first alignment

Owner priority: speed to done over token shaving (harness.md §5). Driver
implications: caps generous rather than stingy (a story cut off at turn
50 is a wasted iteration), escalation early (opus at attempt 3, not
attempt 5), report rich (human decision next morning takes minutes, not
archaeology).

## Recurring pattern

**Human defines truth → agent drafts/claims → machine checks → human
accepts.** The driver is the "machine checks" leg at loop scale, as
verify.sh is at iteration scale.
