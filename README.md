# loop-tool

Ralph-style agent loop driver. A dumb bash loop spawns a fresh `claude -p`
session per iteration; state lives in files; an objective verifier — outside
the agent's control — gates every iteration.

```
┌─> fresh agent reads .loop/prd.json + LEARNINGS.md + git log
│   does ONE story: failing test first → implement → green → commit
│   flips that story's passes flag (a claim, not a verdict)
│   agent exits, memory gone
│   driver runs .loop/verify.sh  ← machine truth, agent can't touch it
└── exit only when ALL stories pass AND verify is green
```

## Setup (once per project)

```bash
mkdir my-project/.loop
cp templates/PROMPT.md templates/LEARNINGS.md my-project/.loop/
cp templates/verify.sh my-project/.loop/   # edit: this project's real checks
chmod +x my-project/.loop/verify.sh
cp templates/prd.json my-project/.loop/    # edit: stories + acceptance criteria
```

## Run

```bash
./loop.sh ~/code/my-project 15        # max 15 iterations
LOOP_MAX_TURNS=60 ./loop.sh ~/code/my-project
```

Requires: `claude` CLI, `jq`, clean git tree. Refuses to run on main/master —
auto-creates a `loop/run-*` branch. Bad run = delete branch.

## Guarantees

- **Fresh context per iteration** — no context rot; files are the only memory
- **Dual-condition exit** — agent's `passes` claims AND green `verify.sh`, never one alone
- **Frozen acceptance criteria** — checksummed at start; agent edits them → hard halt
- **Circuit breaker** — 3 consecutive verify failures → halt, writes `.loop/BLOCKED.md`
- **Caps** — max iterations (arg 2) and per-iteration `--max-turns`

## Division of labor

| Phase | Who |
|---|---|
| PRD + acceptance criteria | human (agent drafts, human approves) |
| Build, test, commit, repeat | machine, unattended |
| Final spot-check + rollout | human |

The human defines truth, the agent claims, the machine checks, the human accepts.

## What "Ralph-style" means

Ralph is a loop pattern for coding agents (popularized by Geoffrey
Huntley): run the agent in a plain `while` loop where **each iteration is
a fresh, throwaway session** and the **only memory that survives between
iterations is files + git** — never conversation history.

Every iteration wakes up blank, reads the current state off disk, does one
small unit of work, commits, and dies. The next one starts clean. Three
consequences this tool is built around:

- **No context rot.** A fresh session can't accumulate stale history,
  hallucinated state, or a 200K-token transcript. It reasons only over
  what's actually on disk right now.
- **The driver is dumb bash.** It spawns, checks, counts, and decides
  mechanically — zero intelligence, nothing to persuade, no tokens spent.
  All the smarts live in the agent (does the work) and the files (hold the
  truth).
- **Files are the baton.** `prd.json` records what's done, `learnings/`
  what was discovered, git commits the work itself. A session cut off
  mid-story loses only since-last-commit work — the next fresh session
  resumes from the files, it doesn't restart.

This tool is a hardened version of that pattern: it adds an objective
`verify.sh` the agent can't touch, checksum-frozen acceptance criteria,
and a circuit breaker — the guardrails a bare Ralph loop leaves out.

## Glossary

- **Iteration** — one turn of the loop: a single fresh `claude -p` session
  spawned by the driver. It does one story, commits, and exits. The next
  iteration is a brand-new session with no memory of this one.
- **Story** — the smallest unit of planned work, defined in `prd.json`.
  One story per iteration. Has an `id`, a description, and acceptance
  criteria.
- **Acceptance criteria** — the concrete, testable conditions a story must
  meet to count as done. Human-approved, then checksum-frozen; the agent
  can never edit them (doing so halts the run).
- **`passes` flag** — the agent's *claim* that a story is done. A claim,
  not a verdict — the driver still runs its own verifier before believing
  it. A story is done only when `passes` is true AND verify is green.
- **`verify.sh`** — the objective health check (tests, typecheck, lint),
  run by the driver *outside* the agent's reach. Machine truth. Frozen at
  planning time so the agent can't weaken the exam mid-run.
- **Driver** — the dumb bash loop (`loop.sh`) that spawns iterations,
  runs `verify.sh`, counts attempts, and decides when to stop. Holds no
  intelligence and spends no tokens.
- **Attempt / circuit breaker** — each failed try at a story counts as an
  attempt; after the limit the story is marked `blocked` and the loop moves
  on. Separately, N consecutive verify failures trip the circuit breaker
  and halt the whole run.
- **Learnings** — notes the agent writes to `.loop/learnings/` so a future
  fresh session doesn't rediscover the same fact. Pull-based memory.
- **Baton** — the state handed from one iteration to the next: `prd.json`,
  learnings, and git commits. Files survive; sessions don't.
- **PRD phase** — the up-front planning session where the human and agent
  agree on stories and acceptance criteria before the unattended loop runs.
- **Harvest** — the post-run step that promotes durable lessons into
  reusable skills, so a mistake is never paid for twice.