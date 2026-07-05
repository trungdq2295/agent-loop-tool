# loop-tool

Ralph-style agent loop driver. A dumb bash loop spawns a fresh `claude -p`
session per iteration; state lives in files; an objective verifier — outside
the agent's control — gates every iteration.

```
┌─> fresh agent reads .loop/prd.json + .loop/learnings/ + git log
│   does ONE story: failing test first → implement → green → commit
│   flips that story's passes flag (a claim, not a verdict)
│   agent exits, memory gone
│   driver runs .loop/verify.sh  ← machine truth, agent can't touch it
└── exit only when ALL stories pass AND verify is green
```

## Usage

Requires `claude` CLI, `jq`, and git. The target project must have an
objective check to gate on (tests / typecheck / lint / build) — the tool is
only as trustworthy as its `verify.sh`.

The tool has four subcommands, run in order. `PROJECT` is the path to the
repo you're working on.

### 1. `init` — scaffold (once per feature)

```bash
loop.sh init PROJECT
```

Creates `PROJECT/.loop/` from templates (`PROMPT.md`, `verify.sh`) and adds
the loop's runtime artifacts to the project's `.gitignore`. Refuses if
`.loop/` already exists — remove a stale one first.

**Then edit `PROJECT/.loop/verify.sh`** — fill Block 1 with this project's
real health checks (e.g. `npm test`, `npm run typecheck`, `npm run lint`).
This is the exam the agent can't touch.

### 2. `prd` — plan the work (interactive)

```bash
loop.sh prd PROJECT
```

Opens an interactive session: describe the feature in plain language, the
agent drafts stories + acceptance criteria, reads them back, and you say
**"approved"** when they're right. On approval the criteria and `verify.sh`
are checksum-frozen. This phase needs you at the keyboard.

### 3. `run` — the unattended loop

```bash
loop.sh run PROJECT            # default cap: 25 iterations
loop.sh run PROJECT 15         # cap at 15 iterations
```

One fresh session per iteration, one story at a time, verify after each,
until every story is done or a cap/breaker stops it. Refuses a dirty tree
(`.loop/` is exempt) and refuses to run on `main`/`master` — it checks out
the branch named in the PRD. Writes `.loop/REPORT.md` on every exit.

### 4. `harvest` — capture lessons (optional)

```bash
loop.sh harvest PROJECT
```

A read-only session that turns the run's expensive mistakes into draft
skills under `.claude/skills-proposed/`. Nothing goes live — you approve
drafts into `.claude/skills/` yourself.

### Common knobs

```bash
LOOP_MAX_TURNS=60 loop.sh run PROJECT     # per-iteration turn cap (default 80)
LOOP_MODEL_EXEC=opus loop.sh run PROJECT  # iteration model (default sonnet)
```

Bad run? The work is on its own branch — just delete it.

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