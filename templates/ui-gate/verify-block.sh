# ── UI GATE — browser behavioral checks ─────────────────────────────────────
# Runs .loop/ui-gate/checks/*.mjs against the running app in a real browser
# (puppeteer-core). Assert SEMANTICS/INTENT (role, text, intent-class like
# `ant-tag-green`, computed color, behavior) — NEVER pixels/snapshots. See
# loop-tool docs/ui-gate.md. This block is injected by `init` for UI repos only.
#
# REPO KNOWLEDGE — fill these two for THIS app (also record them in CLAUDE.md):
export UI_GATE_BASE_URL="http://localhost:3000"   # ← this app's origin + PORT
UI_BOOT_CMD="npm start"                            # ← command that starts the app
# export UI_GATE_CHROME=/path/to/chrome            # ← optional; auto-detected if unset
#
# ---- generic boot → wait → drive → teardown (no need to edit below) ----------
if [ -d .loop/ui-gate/checks ]; then
  # CHECK-COUNT RATCHET — the checks/*.mjs are the UI test layer; the general
  # Block-2 ratchet can't see them (wrong glob), so they get their own: count
  # may grow, never shrink. Without this an agent could delete a red check to
  # make the gate vacuously green (0 checks = pass) with no mechanical trace.
  UI_CHECK_COUNT_FILE=".loop/ui-gate/.check-count"
  UI_NOW="$(find .loop/ui-gate/checks -maxdepth 1 -type f -name '*.mjs' ! -name '_*' 2>/dev/null | wc -l | tr -d ' ')"
  if [ -f "$UI_CHECK_COUNT_FILE" ]; then
    UI_BEFORE="$(cat "$UI_CHECK_COUNT_FILE")"
    if [ "$UI_NOW" -lt "$UI_BEFORE" ]; then
      echo "RATCHET: UI check count dropped $UI_BEFORE → $UI_NOW — a check was deleted" >&2
      exit 1
    fi
  fi
  echo "$UI_NOW" > "$UI_CHECK_COUNT_FILE"

  ( eval "$UI_BOOT_CMD" ) >.loop/ui-gate/boot.log 2>&1 &
  UI_PID=$!
  # Kill the whole process tree on exit: `npm start` forks node/esbuild children
  # that outlive a bare `kill $UI_PID`, orphaning the port and poisoning the next
  # verify run. pgrep -P exists on macOS + Linux.
  _ui_killtree() {
    local _p="$1" _c
    for _c in $(pgrep -P "$_p" 2>/dev/null); do _ui_killtree "$_c"; done
    kill "$_p" 2>/dev/null || true
  }
  trap '_ui_killtree "$UI_PID"' EXIT
  UI_READY=0
  for _ in $(seq 1 60); do
    if curl -fsS -o /dev/null "$UI_GATE_BASE_URL"; then UI_READY=1; break; fi
    if ! kill -0 "$UI_PID" 2>/dev/null; then
      echo "UI gate: app process died during boot — see .loop/ui-gate/boot.log" >&2
      tail -20 .loop/ui-gate/boot.log >&2; exit 1
    fi
    sleep 2
  done
  [ "$UI_READY" = 1 ] || { echo "UI gate: app never became ready at $UI_GATE_BASE_URL (120s)" >&2; exit 1; }
  node .loop/ui-gate/gate.mjs
fi
