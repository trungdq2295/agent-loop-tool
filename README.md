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
