# Feature backlog

A living list of features we *want* — the place to park an idea so it
isn't lost, and to reason about what to build next as the tool scales.
This is intent, not commitment; ordering is rough priority, not a promise.

**Status legend:** `idea` (captured, not scoped) · `planned` (agreed,
scoped) · `in-progress` · `done` (shipped, kept here for history).

| # | Feature | Status | Why it matters |
|---|---|---|---|
| F1 | Cost telemetry in the report | planned | A run should be self-evaluating without transcript archaeology. |
| F2 | Testless-project bootstrap | planned | The tool's weak case today — it assumes a test suite exists. |
| F3 | Verify-proposal feedback loop | idea | Harvest already spots a weak exam; feed that back to strengthen it. |
| F4 | Test-discipline enforcement | idea | Prompt asks nicely; nothing enforces it. |
| F5 | Parallel stories / multi-project | idea | Sequential only today; parallelism is the obvious scale axis. |
| F6 | Cross-project (global) skill promotion | idea | Lessons compound across repos, not just within one. |
| F7 | Run notifications | idea | Unattended runs need a "done / blocked" ping. |

---

## F1 — Cost telemetry in the report

- **Problem:** `REPORT.md` shows per-story outcomes but no cost. Finding
  out why a run was slow or expensive means reading raw session
  transcripts by hand.
- **What we want:** per-iteration duration + turn count (and token spend
  if cheaply available) written into the report, plus a run total.
- **Rough approach:** the driver already brackets each `claude -p` call;
  capture wall-clock per iteration, count turns from the iteration log,
  append a table to the report.
- **Open questions:** token numbers may need the session JSON, not just
  the CLI output — decide whether wall-clock + turns is enough for v1.

## F2 — Testless-project bootstrap

- **Problem:** loop-tool is only as trustworthy as `verify.sh`, which
  assumes an objective check surface. Point it at a project with no tests
  and either verify fails from the start (instant circuit-breaker halt) or
  it degrades to build+lint, leaving the agent's `passes` claims unchecked.
- **What we want:** a first-class path for standing up a harness before
  the loop proper — e.g. a bootstrap-story template ("set up test
  framework + one smoke test") or an `init` mode that scaffolds it.
- **Rough approach:** detect absence of a test command; offer to seed a
  minimal harness; document leaning `verify.sh` on e2e/integration/smoke
  when unit tests are absent.
- **Open questions:** how much to automate vs. leave to the human, given
  framework choice is project-specific.

## F3 — Verify-proposal feedback loop

- **Problem:** the harvest step notes where the exam looked weak or flaky,
  but those notes just sit in `.loop/verify-proposals.md`.
- **What we want:** a reviewed path to fold proposals back into
  `verify.sh` between runs, so the exam strengthens over time.
- **Open questions:** keep it human-gated (propose, human applies) to
  preserve the frozen-exam guarantee — never let a run edit its own exam.

## F4 — Test-discipline enforcement

- **Problem:** PROMPT.md asks the agent to run narrow tests and avoid
  flake retry-loops, but nothing enforces it — a session can still burn
  turns on repeated full-suite runs.
- **What we want:** detect the anti-patterns from the iteration logs
  (repeated full-suite invocations, `for` loops around a test) and surface
  them in the report, maybe warn the next iteration.
- **Open questions:** detection heuristics vs. false positives.

## F5 — Parallel stories / multi-project

- **Problem:** one project, one feature, sequential stories. Fine until it
  hurts; parallelism is the obvious next scale axis.
- **What we want:** independent stories running concurrently (worktree
  isolation), and/or multiple projects driven at once.
- **Open questions:** conflict handling, verify contention, cost blowup —
  significant design work; do not start before the sequential path is
  proven across several real runs.

## F6 — Cross-project (global) skill promotion

- **Problem:** harvest promotes skills into the *project's*
  `.claude/skills/` only. A lesson learned in project A doesn't help
  project B.
- **What we want:** a curated path to promote genuinely stack-level
  lessons to a global skills location.
- **Open questions:** keep human-curated — a wrong global skill poisons
  every repo. Global learnings already promote; skills are higher-risk.

## F7 — Run notifications

- **Problem:** an overnight run finishes or blocks silently; the human
  finds out next morning.
- **What we want:** a pluggable "done / blocked / killed" notification
  (webhook, desktop, chat) at run exit.
- **Open questions:** transport choice; keep it optional and config-driven.

---

## Shipped (history)

Kept so the backlog doubles as a record of what already landed.

- **Usage-limit backoff** — session dies on an API limit → no attempt
  counted, sleep and retry. `done`
- **Green-unclaimed recovery** — verify green but `passes` unflipped →
  next iteration just confirms + flips instead of re-deriving. `done`
- **Baton durability** — driver sweep-commits `.loop/` each iteration so
  state survives a crash. `done`
- **Failure-driven skill promotion** — harvest mines ≥2-attempt stories
  and their failure logs first. `done`
- **`.loop/` dirty-tree exemption + gitignore on init** — the tool's own
  artifacts no longer block its runs. `done`
