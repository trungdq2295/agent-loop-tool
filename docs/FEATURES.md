# Feature backlog

A place to park features we want, so ideas aren't lost and we can decide
what to build next as the tool scales. Add an entry when a feature idea
comes up; flesh it out when we scope it.

**Status:** `idea` · `planned` · `in-progress` · `done`

| # | Feature | Status |
|---|---|---|
| F1 | Cost telemetry in the run report | planned |
| F2 | Support for projects with no test suite | planned |
| F4 | Test-discipline enforcement | idea |

---

## F1 — Cost telemetry in the run report

- **Problem:** `REPORT.md` shows per-story outcomes but no cost. Finding
  out why a run was slow or expensive means reading raw session
  transcripts by hand.
- **What we want:** per-iteration duration + turn count written into the
  report, plus a run total. Token spend too if cheaply available.
- **Rough approach:** the driver already brackets each `claude -p` call —
  capture wall-clock per iteration, count turns from the iteration log,
  append a table to the report.
- **Open questions:** token numbers may need the session JSON, not just
  CLI output — decide whether wall-clock + turns is enough for v1.

## F2 — Support for projects with no test suite

- **Problem:** the tool trusts `verify.sh`, which assumes the project
  already has an objective check (tests / typecheck / lint). On a project
  with no tests, verify either fails from the start (loop halts) or
  degrades to build+lint, leaving the agent's `passes` claims unchecked.
- **What we want:** _(to scope)_
- **Open questions:** _(to scope)_

## F4 — Test-discipline enforcement

- **Problem:** PROMPT.md asks the agent to run narrow tests and avoid
  flake retry-loops, but nothing enforces it — a session can still burn
  turns on repeated full-suite runs.
- **What we want:** detect the anti-patterns from the iteration logs
  (repeated full-suite invocations, `for` loops around a test) and surface
  them in the report; maybe warn the next iteration.
- **Open questions:** detection heuristics vs. false positives.
