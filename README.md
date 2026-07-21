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

The tool has four subcommands. `PROJECT` is the path to the repo you're
working on. Lifecycle: `init` once per project, then per feature:
`prd` → `run` → merge → `prd` again. Each feature lives in its own
folder under `.loop/features/<slug>/`; `verify.sh`, `PROMPT.md` and
`learnings/` are shared across features (learnings from feature 1 make
feature 2 cheaper).

### 1. `init` — scaffold (once per project)

```bash
loop.sh init PROJECT
```

Creates `PROJECT/.loop/` from templates (`PROMPT.md`, `verify.sh`) and
gitignores the whole `.loop/` dir — **the loop leaves zero trace in your
repo** (no status noise, no chore commits, nothing in PRs). Want the
baton in git anyway? `LOOP_GIT_MODE=tracked loop.sh init PROJECT`.
Refuses if `.loop/` already exists.

`verify.sh` Block 1 — the exam the agent can't touch — is **auto-filled**
by project-type detection: `package.json` scripts (`npm run test/
typecheck/lint`), `pom.xml` (`mvn -q verify`), or gradle (`./gradlew
check`). Review it. Other stacks (python, go, …) fill Block 1 by hand —
any command works, the driver only reads the exit code. `prd` refuses to
freeze an unfilled stub, so this can't be silently skipped.

If the repo has **CI** (`.github/workflows`, `.gitlab-ci.yml`, a
`Jenkinsfile`, …), `init` says so and warns that Block 1 must **mirror
the CI test command** — CI is the reproducibility oracle. A `verify.sh`
that goes green only on your laptop gates on nothing (D12).

`init` also seeds a **`CLAUDE.md`** stub when the repo has none — the
file every loop iteration auto-loads to learn how the repo tests, builds,
and what it deliberately does *not* do. An existing `CLAUDE.md` is never
touched; the `prd` session helps enrich it. This is what keeps a build
agent from inventing a test setup or reshaping code to make it testable
(D12).

### 2. `prd` — plan the work (interactive)

```bash
loop.sh prd PROJECT copy-paste    # label = folder + branch name
loop.sh prd PROJECT               # prompts for a label; blank → timestamp
```

The label is a *working* name (like a branch name — rough is fine; the
interview settles the real feature name). The driver creates
`.loop/features/<label>/` **before** the session and the agent writes
`prd.json`/`PRD.md` directly into it; the branch is forced to
`loop/<label>`. Describe the feature in plain language, the agent drafts
stories + acceptance criteria, and you say **"approved"** when they're
right. On approval the criteria and `verify.sh` are checksum-frozen for
that feature. Needs you at the keyboard.

Existing labels are protected: an open feature → refuse + show status; a
completed one → refuse, pick `<label>-v2`; a feature whose freeze was
interrupted mid-write → one y/N finishes it, no new interview.

Refuses to start while `verify.sh` Block 1 is still the template stub — a
frozen always-red exam would fail every story forever with no in-run
recovery. Also refuses when Block 1 invokes **no test runner**: without
one, green only proves "it compiles" and the agent grades itself. The
suite may start empty — the loop grows it story by story (red-first);
only the runner invocation is required. Exotic runner?
`LOOP_NO_TEST_GATE=1` skips the gate.

### 3. `run` — the unattended loop

```bash
loop.sh run PROJECT                  # one open feature → auto-picked; cap 25
loop.sh run PROJECT 15               # same, cap at 15 iterations
loop.sh run PROJECT copy-paste       # several open features → name one
loop.sh run PROJECT copy-paste 15
```

One fresh session per iteration, one story at a time, verify after each,
until every story is done or a cap/breaker stops it. Auto-shelves a dirty
tree (restored on exit) and checks out the feature's branch when started
from `main`/`master`. Writes `features/<slug>/REPORT.md` on every exit.
A pid lockfile allows only ONE run per working tree — parallel features
need worktrees (see `docs/BACKLOG.md`). The iteration agent reads only
its own feature folder, so per-iteration token cost stays flat no matter
how many features accumulate.

**`run` is the only command you ever re-type.** It self-heals on start:

- *Blocked stories with answered questions revive automatically.* When the
  agent gets stuck it writes a question to its feature's `QUESTIONS.md`
  with an `ANSWER: (pending)` line. Fill that line, re-run `loop.sh run` —
  the story flips back to todo with a fresh attempt budget and your answer
  in its notes. Answered questions move to `QUESTIONS-archive.md`.
- *Old flat `.loop/` layout?* Auto-migrated into `features/<slug>/` on the
  next `prd`/`run`/`harvest` — mid-flight features survive the upgrade.
- *`verify.sh` improved between runs?* `run` shows the diff against the
  frozen snapshot and asks one y/N to re-freeze — no PRD re-run needed.
  (Mid-run edits still kill the run; only the pre-start window is gated
  by you.)
- *`prd`'s freeze interrupted?* (crash, permission denial mid-write) —
  `run` detects the half-frozen state, shows Block 1, and offers the
  same y/N to finish the freeze. The approved PRD is never redone.

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
- **Circuit breaker** — 3 consecutive verify failures → halt, report written to the feature's `REPORT.md`
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