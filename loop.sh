#!/usr/bin/env bash
# loop.sh — Ralph-style agent loop driver.
#
# Spawns a fresh `claude -p` session per iteration. State lives in the
# project's .loop/ directory, verification runs outside the agent's control.
#
# Usage:   ./loop.sh <project-dir> [max-iterations]
# Env:     LOOP_TOOLS      allowed tools (default: Edit,Write,Read,Bash,Glob,Grep)
#          LOOP_MAX_TURNS  per-iteration turn cap (default: 50)
set -euo pipefail

PROJECT="$(cd "${1:?usage: loop.sh <project-dir> [max-iterations]}" && pwd)"
MAX_ITERS="${2:-10}"
LOOP_DIR="$PROJECT/.loop"
PRD="$LOOP_DIR/prd.json"
PROMPT="$LOOP_DIR/PROMPT.md"
VERIFY="$LOOP_DIR/verify.sh"
LOGS="$LOOP_DIR/logs"
ALLOWED_TOOLS="${LOOP_TOOLS:-Edit,Write,Read,Bash,Glob,Grep}"
MAX_TURNS="${LOOP_MAX_TURNS:-50}"
FAIL_LIMIT=3

die() { echo "loop: $*" >&2; exit 1; }

[ -f "$PRD" ]    || die "missing $PRD"
[ -f "$PROMPT" ] || die "missing $PROMPT"
[ -x "$VERIFY" ] || die "missing or non-executable $VERIFY"
command -v jq >/dev/null     || die "jq required (brew install jq)"
command -v claude >/dev/null || die "claude CLI required"

mkdir -p "$LOGS"
cd "$PROJECT"

# --- safety rails ---------------------------------------------------------
[ -z "$(git status --porcelain)" ] || die "working tree dirty — commit or stash first"

BRANCH="$(git rev-parse --abbrev-ref HEAD)"
case "$BRANCH" in
  main|master)
    BRANCH="loop/run-$(date +%Y%m%d-%H%M%S)"
    git checkout -b "$BRANCH"
    echo "loop: created branch $BRANCH"
    ;;
esac

# Acceptance criteria are the human's exam questions — read-only to the agent.
criteria_sum() { jq -S '[.stories[].acceptance]' "$PRD" | shasum -a 256 | cut -d' ' -f1; }
FROZEN_SUM="$(criteria_sum)"

all_done() { jq -e '[.stories[].passes] | all' "$PRD" >/dev/null 2>&1; }

# --- the loop -------------------------------------------------------------
FAILS=0
for i in $(seq 1 "$MAX_ITERS"); do
  echo ""
  echo "=== iteration $i/$MAX_ITERS ($(date +%H:%M:%S), branch $BRANCH) ==="

  claude -p "$(cat "$PROMPT")" \
    --allowedTools "$ALLOWED_TOOLS" \
    --max-turns "$MAX_TURNS" \
    2>&1 | tee "$LOGS/iter-$i.log" || true

  if [ "$(criteria_sum)" != "$FROZEN_SUM" ]; then
    die "acceptance criteria modified by agent (iteration $i) — halted, inspect $PRD"
  fi

  if "$VERIFY" > "$LOGS/verify-$i.log" 2>&1; then
    echo "verify: PASS"
    FAILS=0
  else
    FAILS=$((FAILS + 1))
    echo "verify: FAIL ($FAILS/$FAIL_LIMIT) — see $LOGS/verify-$i.log"
    if [ "$FAILS" -ge "$FAIL_LIMIT" ]; then
      {
        echo "# Loop blocked — $(date)"
        echo ""
        echo "verify.sh failed $FAIL_LIMIT consecutive iterations. Last output:"
        echo '```'
        tail -50 "$LOGS/verify-$i.log"
        echo '```'
      } > "$LOOP_DIR/BLOCKED.md"
      die "stuck — wrote .loop/BLOCKED.md, human needed"
    fi
  fi

  # Exit only when the agent's claim AND the machine's verdict agree.
  if all_done && [ "$FAILS" -eq 0 ]; then
    echo ""
    echo "loop: COMPLETE — all stories pass, verify green (iteration $i)"
    exit 0
  fi
done

die "max iterations ($MAX_ITERS) reached without completion"
