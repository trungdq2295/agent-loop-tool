# Changelog

Notable changes. Releases are tagged automatically on merge to `main`;
this file records the human-facing highlights.

## Unreleased

### Added

- **Cooperate with repo knowledge; tests conform to the code (D12).** Born
  from a real-use failure where the tool reshaped production code to make it
  testable and leaked machine-specific setup into ship code.
  - The build agent now has hard rules (`PROMPT.md`): never refactor
    production code solely to make it testable, never add platform branching
    (`os === "macOS"`, host paths) to shipped code for a test, and follow the
    repo's `CLAUDE.md` conventions. If a unit test can't be added following
    the codebase's existing convention, the story ships **untested-but-honest**
    with the reason logged to `QUESTIONS.md` — the codebase is never bent to
    serve a test.
  - `init` **seeds a `CLAUDE.md`** stub when the repo has none (auto-loaded by
    every iteration; documents how the repo tests/builds and what it does NOT
    do). An existing `CLAUDE.md` is never overwritten; the `prd` session helps
    enrich it.
  - `init` detects **CI** and warns that `verify.sh` Block 1 must mirror the CI
    test command — CI is the reproducibility oracle, so a laptop-only green
    can't pass the gate.
  - `prd` gained a **convention gate**: a criterion that could only be verified
    by reshaping code or adding a pattern the repo lacks is flagged to the PM
    up front, not discovered mid-run.

- **Auto-shelve uncommitted work.** `loop.sh run` no longer refuses a dirty
  working tree. It automatically shelves the owner's uncommitted changes
  (both tracked and untracked, JetBrains "shelve" style) before the run and
  restores them on exit — including on a crash, circuit-break, or tamper-kill,
  via an EXIT trap. You never have to `git stash` by hand.
  - The `.loop/` directory is **excluded** from the shelf, so `prd.json`,
    `PRD.md`, `PROMPT.md`, `verify.sh`, and `learnings/` stay on disk — the
    PRD is never hidden or lost.
  - Shelved work is stored on a dedicated ref (`refs/loop-tool/shelf`), off
    the stash stack and safe from garbage collection. If a restore ever hits
    a conflict, the ref is left in place with recovery instructions — work is
    never lost.
  - Restore is conflict-free in the common case: the loop's commits land on a
    separate branch, so the branch you started on is unchanged since shelve
    time.
