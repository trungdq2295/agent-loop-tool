# Features — supported, assumed, planned

What loop-tool does today, what it assumes about the target project, and
what is on the roadmap. This is the honest scope of the tool; read the
"Requirements & assumptions" and "Known limitations" sections before
pointing it at a new project.

## Supported today

### Phases (subcommands of `loop.sh`)

| Command | Phase | What it does |
|---|---|---|
| `init <dir>` | scaffold | Creates `.loop/` from templates, appends runtime artifacts to the project's `.gitignore`. |
| `prd <dir>` | 0 — plan | Interactive session (opus) that turns a rough ask into stories + acceptance criteria, then freezes them. |
| `run <dir> [max]` | 1 — loop | Unattended loop: one fresh session per iteration, verify after each, until done or capped. |
| `harvest <dir>` | 3 — learn | Read-only librarian session that promotes durable lessons into draft skills. |

### Loop mechanics

- **Fresh session per iteration.** Each iteration is a new `claude -p`
  with no memory of the last — files and git are the only continuity.
- **One story per iteration.** The driver names exactly one story; the
  agent is told to touch nothing else.
- **Dual-condition exit.** A story is done only when the agent claims
  `passes: true` AND the driver's own `verify.sh` is green. Neither alone.
- **Per-story attempt ladder.** Fail once → retry with the failure log
  injected. Fail twice → prompt demands a different angle. Fail three
  times → story marked `blocked`, loop moves on.
- **Model escalation.** Iterations run on a cheap model (sonnet); a
  story's third attempt escalates to a stronger one (opus) — brain before
  human.
- **Circuit breaker.** Three consecutive verify failures halt the whole
  run (the codebase itself is likely broken) and write a report.
- **Caps.** Max iterations (CLI arg, default 25) and a per-iteration
  turn cap (`LOOP_MAX_TURNS`, default 80).
- **Morning report.** Every exit (complete, blocked, capped, killed)
  writes `.loop/REPORT.md`: per-story outcome, attempts, notes.

### Integrity / anti-gaming

- **Frozen acceptance criteria.** Checksummed at plan time; if the agent
  edits any story's criteria mid-run, the loop is killed.
- **Verify snapshot outside the project.** The exam (`verify.sh`) is
  copied to driver-owned state the agent can't reach, and checksummed. The
  driver always runs the snapshot, never the in-project copy.
- **Tamper tripwire.** If the in-project `verify.sh` is modified during a
  run, the loop is killed.
- **Test-count ratchet.** Test count may grow, never shrink — a backstop
  against deleting or skipping tests to force green.
- **Branch isolation.** Refuses to run on `main`/`master`; auto-creates a
  loop branch. Refuses a dirty working tree (`.loop/` is exempted).

### Resilience

- **Usage-limit backoff.** If a session dies on an API usage limit, no
  attempt is counted; the driver sleeps (`LOOP_LIMIT_BACKOFF`) and retries.
- **Baton durability.** The driver sweep-commits `.loop/` after each
  iteration, so its own state changes and any agent notes survive a crash.
- **Green-unclaimed recovery.** If verify is green but the agent forgot to
  flip the `passes` flag, the next iteration is told the work is likely
  done and to just confirm + flip — no full re-derivation.

### Knowledge compounding

- **Learnings.** Pull-based notes in `.loop/learnings/`, loaded per story
  so a fresh session doesn't rediscover known facts.
- **Failure-driven skill promotion.** Harvest mines stories that cost ≥2
  attempts (plus their failure logs) first, and drafts reusable skills from
  the expensive mistakes. Drafts are staged, never auto-live — a human
  approves each into `.claude/skills/`.

## Requirements & assumptions

- **`claude` CLI, `jq`, and git** installed.
- **A git repo** with a clean working tree at start.
- **An existing, objective check surface.** This is the big one: the tool
  is only as trustworthy as `verify.sh`, and `verify.sh` is only as strong
  as the checks the project already has. loop-tool assumes the project has
  a runnable test/typecheck/lint/build command to wire into `verify.sh`.
- **Acceptance criteria that can be expressed as runnable checks.** A
  criterion the machine can't test is not loop-able; it belongs in human
  review, not the unattended loop.

## Known limitations

- **Testless projects are the weak case.** With no test framework:
  - If `verify.sh` runs a test command, it fails from the start → the
    circuit breaker halts the run almost immediately.
  - If `verify.sh` checks only build + lint, machine truth degrades to
    "it compiles and lints." The agent's `passes` claims are then
    effectively unchecked, and false greens can ship. The dual-condition
    guarantee is only as strong as the exam behind it.
  - The red-first TDD protocol also assumes a framework exists; without
    one the agent must improvise, which is non-deterministic.
  - Mitigations: seed a test harness before looping (or make it story
    S0), lean `verify.sh` on whatever objective signal exists (e2e,
    integration, a boot/smoke check), and keep un-encodable criteria as
    human-review-only.
- **One project, one feature, sequential stories.** No parallelism across
  stories or projects yet — by design, until it hurts.
- **Report has outcomes, not cost telemetry.** `REPORT.md` shows what
  happened per story, but not per-iteration turn counts or token spend —
  today that requires reading the session transcripts by hand.

## Planned / roadmap

- **Cost telemetry in the report** — per-iteration duration + turn count,
  so a run is self-evaluating without transcript archaeology.
- **Testless-project bootstrap** — a first-class path (or bootstrap story
  template) for standing up a harness before the loop proper.
- **Verify-proposal loop** — harvest already notes where the exam looked
  weak or flaky; feed those proposals back to strengthen `verify.sh`
  between runs.
- **Enforcement teeth for test discipline** — detect repeated full-suite
  runs / flake retry-loops from the logs and surface them, not just ask
  the prompt nicely.

> Roadmap items are intentions, not commitments. The bar for v1 is
> correctness of the guarantees above, not breadth.
