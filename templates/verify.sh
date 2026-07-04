#!/usr/bin/env bash
# .loop/verify.sh — machine truth for THIS project. See loop-tool docs/verify.md.
#
# Contract with the driver:
#   - exit 0 = healthy, non-zero = fail; driver reads nothing else
#   - driver runs this with CWD = project root (do NOT self-cd)
#   - frozen at prd time (snapshot + checksum, D7) — editing it mid-run
#     kills the run; improve it BETWEEN runs, then re-freeze
set -euo pipefail

# ── Block 1: LAYER-1 INVARIANTS — the ONLY per-project part ─────────────
# "Is the codebase still healthy?" Feature-agnostic, permanent, 2-4 lines.
# First failing command fails the whole script (set -e) — that IS the gate.
#
# REPLACE these with your project's real checks:
echo "verify.sh: Block 1 not filled in yet" >&2; exit 1
# npm test
# npx tsc --noEmit
# npm run lint

# ── Block 2: TEST-COUNT RATCHET — generic, keep as-is ────────────────────
# Backstop against test deletion (harness §2): count may grow, never shrink.
COUNT_FILE=".loop/test-count"
count_tests() {  # adjust the pattern to your test framework if needed
  grep -rE '^\s*(it|test)\(' --include='*.test.*' --include='*.spec.*' . \
    2>/dev/null | wc -l | tr -d ' '
}
NOW="$(count_tests)"
if [ -f "$COUNT_FILE" ]; then
  BEFORE="$(cat "$COUNT_FILE")"
  if [ "$NOW" -lt "$BEFORE" ]; then
    echo "RATCHET: test count dropped $BEFORE → $NOW — tests were deleted or skipped" >&2
    exit 1
  fi
fi
echo "$NOW" > "$COUNT_FILE"

# ── Block 3: LAYER-2 GRADUATES — documentation only ──────────────────────
# Finished stories' acceptance tests already run inside Block 1's suite.
# Today's acceptance criteria protect tomorrow's loops. Nothing to add here.

echo "verify: all green ($NOW tests)"
