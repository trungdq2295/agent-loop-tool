# Feature backlog

A place to park features we want, so ideas aren't lost and we can decide
what to build next as the tool scales. Add an entry when a feature idea
comes up; flesh it out when we scope it.

**Status:** `idea` · `planned` · `in-progress` · `done`

| # | Feature | Status |
|---|---|---|
| F1 | Support for projects with no test suite | idea |

---

## F1 — Support for projects with no test suite

- **Problem:** the tool trusts `verify.sh`, which assumes the project
  already has an objective check (tests / typecheck / lint). On a project
  with no tests, verify either fails from the start (loop halts) or
  degrades to build+lint, leaving the agent's `passes` claims unchecked.
- **What we want:** _(to scope)_
- **Open questions:** _(to scope)_
