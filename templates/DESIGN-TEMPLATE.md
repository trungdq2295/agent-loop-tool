# <Feature name> — design doc

<!-- Loop-ready design doc. Fill every section; delete the comments.
     Litmus test for the whole doc: a random engineer with no context
     can say, for each requirement, "done looks like Y, checked by Z".
     Consumed by the PRD session (PRD-PROMPT.md §1b): requirements it
     cannot convert into a failable criterion get flagged back to you
     mid-session — pre-convert them here and the session is short. -->

## Goal

<!-- 2-3 sentences: user problem, why now. -->

## Non-goals

<!-- Explicit exclusions. Stops the build agent inventing scope. -->

## Requirements — each with its observable outcome

<!-- One row per requirement. "Observable" = a test could FAIL it.
     Good: "POST /orders with expired token → 401, code AUTH_EXPIRED"
     Good: "duplicate submit → 409, no second row in orders"
     Bad:  "handles errors gracefully" -->

| # | Requirement | Done looks like (observable) |
|---|---|---|
| R1 | | |

## Edge & error cases

<!-- The biggest source of vague criteria. Enumerate: invalid input,
     duplicates, timeouts, idempotency, empty states, auth failures.
     Same observable form as above. -->

## Implementation decisions (the HOW)

<!-- Libraries, schema, patterns you'd reject an alternative to.
     These become GUIDANCE for the build agent, not acceptance
     criteria — unless you name a machine check next to one
     (arch test, lint rule, benchmark). If it matters enough to
     gate, write the check. -->

## Story slicing (suggested)

<!-- Pre-slice into chunks that each fit one agent session
     (~30-60 tool actions). Natural backend seams: migration /
     endpoint / validation / edge cases / integration.
     The validation-run bar is ≥8 stories — fewer means the feature
     is too small to test the tool honestly. -->

1. S1 —

## Current-state assumptions

<!-- Which files/modules this doc read, and when. The PRD session
     runs a drift check against the live code; dating assumptions
     surfaces staleness at PRD time, not at story 6. -->

- As of <date>, `<path>` does <assumption>.

## Runtime / env contract

<!-- What verify.sh Block 1 needs to run green headless on main:
     test command, services that must be up (DB, docker compose),
     seed data, env vars (names only — never values). -->

- Test command:
- Requires:
