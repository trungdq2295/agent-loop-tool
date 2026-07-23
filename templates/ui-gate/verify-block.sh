# ── UI GATE — browser behavioral checks ─────────────────────────────────────
# Runs .loop/ui-gate/checks/*.mjs against the running app in a real browser
# (puppeteer-core). Assert SEMANTICS/INTENT (role, text, intent-class like
# `ant-tag-green`, computed color, behavior) — NEVER pixels/snapshots. See
# loop-tool docs/ui-gate.md. This block is injected by `init` for UI repos only.
#
# REPO KNOWLEDGE — fill these two for THIS app (also record them in CLAUDE.md):
export UI_GATE_BASE_URL="http://localhost:3000"   # ← this app's origin + PORT
UI_BOOT_CMD="npm start"                            # ← command that starts the app
# UI_GATE_CHROME=/path/to/chrome                   # ← optional; auto-detected if unset
#
# ---- generic boot → wait → drive → teardown (no need to edit below) ----------
if [ -d .loop/ui-gate/checks ]; then
  ( eval "$UI_BOOT_CMD" ) >.loop/ui-gate/boot.log 2>&1 &
  UI_PID=$!
  trap 'kill "$UI_PID" 2>/dev/null || true' EXIT
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
