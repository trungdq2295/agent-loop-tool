# Changelog

Notable changes. Releases are tagged automatically on merge to `main`;
this file records the human-facing highlights.

## Unreleased

### Added

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
