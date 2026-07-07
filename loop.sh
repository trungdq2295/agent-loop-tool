#!/usr/bin/env bash
# loop.sh — loop-tool driver v3. Built from docs/driver.md (settled 2026-07-04).
# Dumb bash by design: spawns, checks, counts, decides mechanically.
# Rationale for every knob: docs/decisions/ — read before changing values.
#
# Usage:
#   loop.sh init <project-dir>                        scaffold .loop/ from templates (once per project)
#   loop.sh prd <project-dir>                         Phase 0: interactive PRD → new feature folder
#   loop.sh run <project-dir> [feature] [max-iters]   Phase 1: unattended loop (feature optional when only one is open)
#   loop.sh harvest <project-dir>                     Phase 3: librarian session (mines all features)
#
# Env overrides:
#   LOOP_TOOLS           run-mode allowed tools (default: Edit,Write,Read,Bash,Glob,Grep,Skill)
#   LOOP_MAX_TURNS       per-iteration turn cap (default: 80, D1)
#   LOOP_MODEL_EXEC      iteration model        (default: sonnet)
#   LOOP_MODEL_ESCALATE  attempt-3 model        (default: opus)
#   LOOP_MODEL_PRD       phase-0 model          (default: opus)
#   LOOP_LIMIT_BACKOFF   sleep after usage-limit death, seconds (default: 1200)
#   LOOP_GIT_MODE        init only — 'ignored' (default, .loop/ gitignored, D10)
#                        or 'tracked' (baton committed per iteration, v2 behavior)
set -euo pipefail

TOOL_DIR="$(cd "$(dirname "$0")" && pwd)"

die() { echo "loop: $*" >&2; exit 1; }

CMD="${1:-}"
[ -n "$CMD" ] || die "usage: loop.sh <init|prd|run|harvest> <project-dir> [feature] [max-iters]"
PROJECT="$(cd "${2:?usage: loop.sh $CMD <project-dir>}" && pwd)"

# Driver-owned state, OUTSIDE the project — agent sessions are confined
# to the project dir, so nothing here is reachable by them (D7).
STATE_DIR="$TOOL_DIR/state/$(basename "$PROJECT")-$(echo "$PROJECT" | shasum -a 256 | cut -c1-8)"

# Shared, feature-agnostic project state (D9).
LOOP_DIR="$PROJECT/.loop"
FEATURES_DIR="$LOOP_DIR/features"
PROMPT_MD="$LOOP_DIR/PROMPT.md"
VERIFY="$LOOP_DIR/verify.sh"
MODE_FILE="$LOOP_DIR/mode"

# Per-feature state — set by select_feature(); empty until then so a path
# bug fails loudly instead of touching the wrong feature.
SLUG=""
FEAT_DIR=""
PRD_JSON=""
SUM_FILE=""
LOGS=""
REPORT=""
QUESTIONS=""
QUESTIONS_ARCHIVE=""
STATE_FEAT=""
VERIFY_SNAPSHOT=""
VERIFY_SUM_FILE=""

# Auto-shelve state (JetBrains-shelf style): the owner's uncommitted work is
# saved to this dedicated ref — off the stash stack so it can't be popped by
# accident and is safe from GC — then restored on exit. Set in cmd_run.
SHELF_REF="refs/loop-tool/shelf"
SHELF_SHA=""       # populated only when something was shelved
ORIG_BRANCH=""     # branch to return the owner to
LOCK_FILE=""       # pid lockfile — one run per working tree (D9)

# Skill included so harvest-promoted skills (.claude/skills/) can fire
# in future loop sessions — push-based recall (harvest-step.md).
ALLOWED_TOOLS="${LOOP_TOOLS:-Edit,Write,Read,Bash,Glob,Grep,Skill}"
MAX_TURNS="${LOOP_MAX_TURNS:-80}"           # D1
MODEL_EXEC="${LOOP_MODEL_EXEC:-sonnet}"     # harness §5
MODEL_ESCALATE="${LOOP_MODEL_ESCALATE:-opus}"
MODEL_PRD="${LOOP_MODEL_PRD:-opus}"
FAIL_LIMIT=3                                # D1: per-loop circuit breaker
ATTEMPT_LIMIT=3                             # harness §4: per-story ladder
LIMIT_BACKOFF="${LOOP_LIMIT_BACKOFF:-1200}" # usage-limit sleep before retry

command -v jq >/dev/null     || die "jq required (brew install jq)"
command -v claude >/dev/null || die "claude CLI required"

criteria_sum() { jq -S '[.stories[].acceptance]' "$PRD_JSON" | shasum -a 256 | cut -d' ' -f1; }
verify_sum()   { shasum -a 256 "$VERIFY" | cut -d' ' -f1; }

# D10 git mode, recorded at init in an explicit marker — NEVER inferred from
# .gitignore at runtime: the owner's uncommitted .gitignore can get shelved
# away mid-run, silently flipping the inference and letting the sweep-commit
# track a dir that was meant to be invisible. Missing marker = tracked
# (v2 projects predate the marker and tracked their baton).
git_mode() { cat "$MODE_FILE" 2>/dev/null || echo tracked; }

# Exact sentinel emitted by the template's unfilled Block 1. A frozen stub
# fails every story forever with no in-run recovery — several guards grep
# for this marker to refuse that state before it costs a run.
VERIFY_STUB_MARK='Block 1 not filled in yet'

# ------------------------------------------------------ feature plumbing ---
# D9: one folder per feature. Everything after select_feature() operates on
# that feature only; the agent is told the exact dir and reads nothing else.

slug_from_branch() { # "loop/copy-paste" → "copy-paste"
  basename "$1" | tr -c 'a-zA-Z0-9._-' '-' | sed 's/^-*//; s/-*$//'
}

select_feature() { # select_feature <slug>
  SLUG="$1"
  FEAT_DIR="$FEATURES_DIR/$SLUG"
  PRD_JSON="$FEAT_DIR/prd.json"
  SUM_FILE="$FEAT_DIR/criteria.sum"
  LOGS="$FEAT_DIR/logs"
  REPORT="$FEAT_DIR/REPORT.md"
  QUESTIONS="$FEAT_DIR/QUESTIONS.md"
  QUESTIONS_ARCHIVE="$FEAT_DIR/QUESTIONS-archive.md"
  STATE_FEAT="$STATE_DIR/$SLUG"
  VERIFY_SNAPSHOT="$STATE_FEAT/verify.sh"
  VERIFY_SUM_FILE="$STATE_FEAT/verify.sum"
}

# Open = not all stories done. Blocked counts as open — an answered
# question must be able to revive it via plain `loop.sh run`.
open_features() {
  local d
  for d in "$FEATURES_DIR"/*/; do
    [ -f "$d/prd.json" ] || continue
    jq -e '[.stories[].status] | all(. == "done")' "$d/prd.json" >/dev/null \
      || basename "$d"
  done
}

resolve_feature() { # resolve_feature [requested-slug]
  local req="${1:-}"
  if [ -n "$req" ]; then
    [ -f "$FEATURES_DIR/$req/prd.json" ] \
      || die "no feature '$req' — have: $(ls "$FEATURES_DIR" 2>/dev/null | tr '\n' ' ')"
    select_feature "$req"
    return
  fi
  local OPEN N
  OPEN="$(open_features)"
  N="$(printf '%s' "$OPEN" | grep -c . || true)"
  [ "$N" -ge 1 ] || die "no open feature — plan one: loop.sh prd $PROJECT"
  [ "$N" -eq 1 ] || die "multiple open features — pick one: loop.sh run $PROJECT <feature>
$(echo "$OPEN" | sed 's/^/  - /')"
  select_feature "$OPEN"
}

# v2 → v3 upgrade: flat .loop/prd.json moves into features/<slug>/ with all
# its satellites; tool-side snapshot follows. Mid-flight features survive.
migrate_legacy() {
  [ -f "$LOOP_DIR/prd.json" ] || return 0
  local slug f
  slug="$(slug_from_branch "$(jq -r '.branch // "legacy"' "$LOOP_DIR/prd.json")")"
  [ -n "$slug" ] || slug="legacy"
  select_feature "$slug"
  [ -d "$FEAT_DIR" ] && die "legacy .loop/prd.json found but features/$slug already exists — resolve by hand"
  mkdir -p "$FEAT_DIR"
  for f in prd.json PRD.md criteria.sum QUESTIONS.md QUESTIONS-archive.md NOTES.md REPORT.md; do
    [ -f "$LOOP_DIR/$f" ] && mv "$LOOP_DIR/$f" "$FEAT_DIR/$f"
  done
  [ -d "$LOOP_DIR/logs" ] && mv "$LOOP_DIR/logs" "$LOGS"
  if [ -f "$STATE_DIR/verify.sh" ]; then
    mkdir -p "$STATE_FEAT"
    mv "$STATE_DIR/verify.sh" "$VERIFY_SNAPSHOT"
    [ -f "$STATE_DIR/verify.sum" ] && mv "$STATE_DIR/verify.sum" "$VERIFY_SUM_FILE"
  fi
  # v2 projects tracked their baton — record that so shelve/sweep behave.
  [ -f "$MODE_FILE" ] || echo tracked > "$MODE_FILE"
  echo "loop: migrated legacy flat .loop layout → .loop/features/$slug/"
}

# D7: freeze the exam script — snapshot outside the project + tripwire sum.
freeze_verify() {
  mkdir -p "$STATE_FEAT"
  cp "$VERIFY" "$VERIFY_SNAPSHOT"
  chmod +x "$VERIFY_SNAPSHOT"
  verify_sum > "$VERIFY_SUM_FILE"
}

# Edit prd.json safely (driver owns status/attempts — agent never touches them).
prd_set() { # prd_set <jq-filter> [--arg k v ...]
  local filter="$1"; shift
  jq "$@" "$filter" "$PRD_JSON" > "$PRD_JSON.tmp" && mv "$PRD_JSON.tmp" "$PRD_JSON"
}

# Restore the owner's auto-shelved work. Runs from an EXIT trap so it fires on
# every path — success, circuit-break, tamper-kill, or crash. Never loses data:
# if the apply hits a conflict the shelf ref is left in place with recovery
# instructions. Restore is conflict-free in the common case because the loop's
# commits land on a separate branch, so ORIG_BRANCH's tree is unchanged since
# shelve time.
unshelf() {
  [ -n "$SHELF_SHA" ] || return 0
  git checkout -q "$ORIG_BRANCH" 2>/dev/null || true
  # Report the branch we are ACTUALLY on — if the checkout was blocked the
  # shelf must not be claimed restored somewhere it isn't.
  local CUR; CUR="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo '?')"
  if git stash apply -q "$SHELF_SHA" 2>/dev/null; then
    git update-ref -d "$SHELF_REF" 2>/dev/null || true
    echo "loop: restored your shelved work on $CUR"
    [ "$CUR" = "$ORIG_BRANCH" ] || echo "loop: WARN could not return to $ORIG_BRANCH — you are on $CUR" >&2
  else
    echo "loop: WARN could not cleanly restore shelved work — it is SAFE at $SHELF_REF." >&2
    echo "loop:   recover with: git stash apply $SHELF_REF" >&2
  fi
  SHELF_SHA=""
}

# One run per working tree (D9): parallel runs in one tree fight over git
# checkout/shelve/files. True parallel = worktrees (docs/BACKLOG.md).
acquire_lock() {
  LOCK_FILE="$STATE_DIR/run.lock"
  mkdir -p "$STATE_DIR"
  if [ -f "$LOCK_FILE" ]; then
    local pid; pid="$(cat "$LOCK_FILE" 2>/dev/null || true)"
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
      die "another run is active on this project (pid $pid) — one run per working tree.
     Parallel features need worktrees: see docs/BACKLOG.md"
    fi
    echo "loop: removing stale lock (pid ${pid:-?} gone)"
  fi
  echo $$ > "$LOCK_FILE"
}

cleanup() {
  unshelf
  [ -z "$LOCK_FILE" ] || rm -f "$LOCK_FILE"
}

# --------------------------------------------------------------- init ------
cmd_init() {
  [ -d "$LOOP_DIR" ] && die ".loop/ already exists — refusing to overwrite"
  mkdir -p "$LOOP_DIR/learnings" "$FEATURES_DIR"
  cp "$TOOL_DIR/templates/PROMPT.md" "$LOOP_DIR/PROMPT.md"
  cp "$TOOL_DIR/templates/verify.sh" "$LOOP_DIR/verify.sh"
  chmod +x "$LOOP_DIR/verify.sh"

  # Auto-fill Block 1 by detecting the project's ecosystem — the unfilled
  # stub is the one mistake that dead-locks a whole run (frozen exam that
  # always fails), so the common cases must need zero hand-editing. First
  # marker wins; anything undetected keeps the stub + EDIT warning below.
  # Detectors today: npm, maven, gradle. Python/Go/Rust/Make: docs/BACKLOG.md.
  local FILLED="" CMDS=""
  if [ -f "$PROJECT/package.json" ]; then
    local s
    for s in test typecheck lint; do
      jq -e --arg s "$s" '.scripts[$s]' "$PROJECT/package.json" >/dev/null 2>&1 \
        && CMDS="${CMDS}npm run $s\n"
    done
    CMDS="${CMDS%\\n}"
  elif [ -f "$PROJECT/pom.xml" ]; then
    CMDS="mvn -q verify"
  elif [ -x "$PROJECT/gradlew" ]; then
    CMDS="./gradlew check"
  elif [ -f "$PROJECT/build.gradle" ] || [ -f "$PROJECT/build.gradle.kts" ]; then
    CMDS="gradle check"
  fi
  if [ -n "$CMDS" ]; then
    awk -v cmds="$CMDS" '
      /^# REPLACE this line/ { print "# Auto-filled by loop.sh init from detected project type — adjust if needed:"; next }
      index($0, "Block 1 not filled in yet") { print cmds; next }
      { print }
    ' "$LOOP_DIR/verify.sh" > "$LOOP_DIR/verify.sh.tmp" \
      && mv "$LOOP_DIR/verify.sh.tmp" "$LOOP_DIR/verify.sh"
    chmod +x "$LOOP_DIR/verify.sh"
    FILLED="$(printf '%b' "$CMDS" | tr '\n' ',' | sed 's/,/, /g')"
  fi

  # D10: invisible to git by default — one ignore line, zero repo noise.
  # LOOP_GIT_MODE=tracked keeps the v2 baton-in-git behavior.
  echo "${LOOP_GIT_MODE:-ignored}" > "$MODE_FILE"
  if [ "${LOOP_GIT_MODE:-ignored}" = "tracked" ]; then
    if ! grep -q '^\.loop/logs/' "$PROJECT/.gitignore" 2>/dev/null; then
      printf '\n# loop-tool runtime artifacts (LOOP_GIT_MODE=tracked)\n.loop/features/*/logs/\n.loop/features/*/REPORT.md\n.loop/test-count\n' >> "$PROJECT/.gitignore"
      echo "loop: tracked mode — runtime artifacts added to .gitignore"
    fi
  else
    if ! grep -q '^\.loop/$' "$PROJECT/.gitignore" 2>/dev/null; then
      printf '\n# loop-tool state (untracked by default, D10 — LOOP_GIT_MODE=tracked to keep in git)\n.loop/\n' >> "$PROJECT/.gitignore"
      echo "loop: .loop/ added to .gitignore — the loop leaves no trace in your repo"
    fi
  fi

  echo "loop: scaffolded $LOOP_DIR"
  if [ -n "$FILLED" ]; then
    echo "loop: verify.sh Block 1 auto-filled from detected project type: $FILLED — review it"
  else
    echo "loop: EDIT $LOOP_DIR/verify.sh — fill Block 1 with this project's real checks"
  fi
  echo "loop: then run: loop.sh prd $PROJECT"
}

# ---------------------------------------------------------------- prd ------
cmd_prd() {
  mkdir -p "$FEATURES_DIR"
  cd "$PROJECT"
  [ -f "$TOOL_DIR/templates/PRD-PROMPT.md" ] || die "missing templates/PRD-PROMPT.md"
  [ -x "$VERIFY" ] || die "missing or non-executable $VERIFY — run 'loop.sh init' and fill Block 1 first"
  # Refuse BEFORE the interactive session: freezing an unfilled exam would
  # dead-lock every future run (always-red verify, no in-run recovery).
  ! grep -qF "$VERIFY_STUB_MARK" "$VERIFY" \
    || die "verify.sh Block 1 is still the template stub — fill it with this project's real checks first"
  # Exam-quality gate (owner call 2026-07-06): Block 1 must invoke a test
  # runner. Without one, green degrades to "it compiles" and the agent's
  # passes-claim becomes the only correctness signal — self-grading, the
  # exact failure this tool exists to prevent. The suite may start EMPTY
  # (red-first grows it story by story); only the invocation is required.
  # Comments are stripped first so the template's example lines can't pass.
  # Goal-specific on purpose: `mvn compile` / `gradlew compileJava` build
  # without running tests and must NOT satisfy the gate.
  local RUNNER_PATTERN='npm (run )?test|npx (vitest|jest|mocha)|yarn test|pnpm test|mvn .*(test|verify|install|package)|gradlew? .*(check|test|build)|go test|pytest|cargo test|make test|dotnet test|phpunit|rspec'
  if [ "${LOOP_NO_TEST_GATE:-0}" != "1" ] \
    && ! grep -vE '^[[:space:]]*#' "$VERIFY" | grep -qE "$RUNNER_PATTERN"; then
    die "no test-runner invocation in verify.sh — the exam would only prove 'it compiles'.
     Wire one (npm test / mvn -q verify / ./gradlew check / pytest / go test ./...);
     the suite may start empty — the loop grows it story by story.
     Genuinely exotic runner? LOOP_NO_TEST_GATE=1 skips this gate."
  fi

  echo "loop: starting interactive PRD session ($MODEL_PRD) — say 'approved' to finish"
  claude --model "$MODEL_PRD" "$(cat "$TOOL_DIR/templates/PRD-PROMPT.md")"

  # Phase 0 exit gate (prd-step.md): validate, then relocate + freeze.
  # The PRD agent writes flat .loop/prd.json + .loop/PRD.md; the driver owns
  # the features/ layout, so it derives the slug and moves them into place.
  local FLAT="$LOOP_DIR/prd.json"
  [ -f "$FLAT" ] || die "PRD session ended without $FLAT"
  jq -e '.feature and .branch and (.stories | length > 0)' "$FLAT" >/dev/null \
    || die "prd.json invalid: need feature, branch, stories[]"
  jq -e '[.stories[] | select((.id and .story and (.acceptance|length>0)) | not)] | length == 0' \
    "$FLAT" >/dev/null || die "prd.json invalid: every story needs id, story, acceptance[]"

  local slug; slug="$(slug_from_branch "$(jq -r '.branch' "$FLAT")")"
  [ -n "$slug" ] || die "could not derive a feature slug from branch '$(jq -r '.branch' "$FLAT")'"
  select_feature "$slug"
  [ -d "$FEAT_DIR" ] && die "feature '$slug' already exists (features/$slug) — pick a different branch name in the PRD"
  mkdir -p "$FEAT_DIR"
  mv "$FLAT" "$PRD_JSON"
  [ -f "$LOOP_DIR/PRD.md" ] && mv "$LOOP_DIR/PRD.md" "$FEAT_DIR/PRD.md"

  # Normalize driver-owned fields regardless of what the agent wrote.
  prd_set '.stories[] |= (.passes = false | .status = "todo" | .attempts = 0 | .notes //= "")'

  criteria_sum > "$SUM_FILE"
  freeze_verify

  echo "loop: ready — feature '$slug', $(jq '.stories | length' "$PRD_JSON") stories, criteria + verify frozen"
  echo "loop: next: loop.sh run $PROJECT"
}

# ---------------------------------------------------------------- run ------
# Answer-file protocol: blocked stories revive via QUESTIONS.md, no manual
# prd.json surgery. Agent writes "## <id>: question" + "ANSWER: (pending)";
# human fills the ANSWER line; next `loop.sh run` picks it up mechanically.

# Print the filled answer for a story's section, nothing when unanswered.
answer_for() { # answer_for <story-id>
  awk -v sid="$1" '
    /^## /              { insec = (index($0, "## " sid ":") == 1); inans = 0; next }
    insec && /^ANSWER:/ { inans = 1; sub(/^ANSWER:[[:space:]]*/, "")
                          if (length) buf = buf $0 " "; next }
    insec && inans && length { buf = buf $0 " " }
    END {
      gsub(/[[:space:]]+$/, "", buf)
      if (buf != "" && buf != "(pending)") print buf
    }
  ' "$QUESTIONS"
}

# Move a story's answered section out of QUESTIONS.md into the archive, so
# the same answer is never applied twice and open questions stay visible.
archive_question() { # archive_question <story-id>
  awk -v sid="$1" -v arch="$QUESTIONS_ARCHIVE" '
    /^## / { insec = (index($0, "## " sid ":") == 1) }
    insec  { print >> arch; next }
    { print }
  ' "$QUESTIONS" > "$QUESTIONS.tmp" && mv "$QUESTIONS.tmp" "$QUESTIONS"
  # nothing left but whitespace → drop the file (keeps REPORT.md clean)
  grep -q '[^[:space:]]' "$QUESTIONS" 2>/dev/null || rm -f "$QUESTIONS"
}

# Blocked story + filled answer → back to todo with a FRESH attempt budget:
# the old failures were missing-info failures; the answer changes the task
# (and stale attempts would re-block after a single try). Answer lands in
# the story's notes — the baton the next fresh session reads first.
auto_unblock() {
  [ -f "$QUESTIONS" ] || return 0
  local sid ans
  for sid in $(jq -r '.stories[] | select(.status == "blocked") | .id' "$PRD_JSON"); do
    ans="$(answer_for "$sid")"
    [ -n "$ans" ] || continue
    prd_set '(.stories[] | select(.id == $id))
             |= (.status = "todo" | .attempts = 0
                 | .notes = ((.notes // "") + " | HUMAN ANSWER: " + $ans))' \
      --arg id "$sid" --arg ans "$ans"
    archive_question "$sid"
    echo "loop: $sid unblocked — human answer found, attempts reset"
  done
}

next_story() { jq -r '[.stories[] | select(.status == "todo")][0].id // empty' "$PRD_JSON"; }
story_field() { jq -r --arg id "$1" ".stories[] | select(.id == \$id) | .$2" "$PRD_JSON"; }
all_settled() { jq -e '[.stories[].status] | all(. == "done" or . == "blocked")' "$PRD_JSON" >/dev/null; }
all_done()    { jq -e '[.stories[].status] | all(. == "done")' "$PRD_JSON" >/dev/null; }

write_report() { # write_report <iterations-used> <outcome>
  {
    echo "# Morning report — feature '$SLUG' — $(date)"
    echo
    echo "Outcome: **$2** after $1 iteration(s), branch \`$BRANCH\`"
    echo
    echo "| story | status | attempts | notes |"
    echo "|---|---|---|---|"
    jq -r '.stories[] | "| \(.id) | \(.status) | \(.attempts) | \(.notes | gsub("\\|"; "/") | .[0:120]) |"' "$PRD_JSON"
    echo
    if [ -f "$FEAT_DIR/NOTES.md" ]; then
      echo "## Out-of-scope notes (triage me)"
      cat "$FEAT_DIR/NOTES.md"
    fi
    if [ -f "$QUESTIONS" ]; then
      echo "## Open questions (blocked on you)"
      echo "Fill the ANSWER lines in \`.loop/features/$SLUG/QUESTIONS.md\`, then re-run \`loop.sh run\`."
      echo
      cat "$QUESTIONS"
    fi
  } > "$REPORT"
  echo "loop: report written — $REPORT"
}

cmd_run() {
  # arg 3 = feature slug or max-iters (numeric); arg 4 = max-iters after a slug
  local FEAT_ARG="" MAX_ITERS=25   # D1
  case "${3:-}" in
    '')          ;;
    *[!0-9]*)    FEAT_ARG="$3"; MAX_ITERS="${4:-25}" ;;
    *)           MAX_ITERS="$3" ;;
  esac
  resolve_feature "$FEAT_ARG"
  echo "loop: feature '$SLUG'"

  [ -f "$PRD_JSON" ]  || die "missing $PRD_JSON — run 'loop.sh prd' first"
  [ -f "$PROMPT_MD" ] || die "missing $PROMPT_MD"
  [ -x "$VERIFY" ]    || die "missing or non-executable $VERIFY"
  [ -f "$SUM_FILE" ]  || die "criteria not frozen — run 'loop.sh prd' first (prd-step exit gate)"
  [ "$(criteria_sum)" = "$(cat "$SUM_FILE")" ] || die "criteria changed since freeze — re-run prd phase"
  # An unfilled exam fails every story forever — refuse before spawning anything.
  ! grep -qF "$VERIFY_STUB_MARK" "$VERIFY" \
    || die "verify.sh Block 1 is still the template stub — fill it with real checks, then re-run (you'll be offered a re-freeze)"
  # Half-frozen state: criteria froze (checked above) but the snapshot is
  # missing/incomplete — prd's exit gate was interrupted between its freeze
  # steps (crash, permission denial). The PRD itself is approved and valid;
  # finish the freeze here instead of demanding a full interactive prd re-run.
  if [ ! -x "$VERIFY_SNAPSHOT" ] || [ ! -f "$VERIFY_SUM_FILE" ]; then
    echo "loop: criteria are frozen but the verify.sh snapshot is missing — prd's freeze was interrupted."
    echo "loop: verify.sh Block 1 as it stands:"
    sed -n '/── Block 1/,/── Block 2/p' "$VERIFY" | grep -vE '^[[:space:]]*(#|$)' | sed 's/^/loop:   | /'
    [ -t 0 ] || die "verify not frozen — approve the freeze from a terminal (or re-run 'loop.sh prd')"
    printf "loop: freeze this verify.sh as the exam and continue? [y/N] "
    read -r REPLY
    case "$REPLY" in
      y|Y|yes|YES) freeze_verify; echo "loop: verify.sh frozen" ;;
      *) die "declined — re-run 'loop.sh prd' to freeze properly" ;;
    esac
  # Between-runs improvement path (D7 gated channel): verify.sh changed while
  # no run was live → show the diff, one keystroke re-freezes. The mid-run
  # tamper kill further down is untouched — this runs before any agent spawns.
  elif [ "$(verify_sum)" != "$(cat "$VERIFY_SUM_FILE")" ]; then
    echo "loop: verify.sh differs from the frozen snapshot:"
    diff -u "$VERIFY_SNAPSHOT" "$VERIFY" || true
    [ -t 0 ] || die "verify.sh changed since freeze — approve the re-freeze from a terminal (or restore the file)"
    printf "loop: re-freeze this verify.sh as the new exam? [y/N] "
    read -r REPLY
    case "$REPLY" in
      y|Y|yes|YES) freeze_verify; echo "loop: verify.sh re-frozen" ;;
      *) die "declined — restore verify.sh (or approve the re-freeze) to run" ;;
    esac
  fi

  mkdir -p "$LOGS"
  cd "$PROJECT"

  acquire_lock
  trap cleanup EXIT

  # Ring 2 (harness §1): isolation. Instead of refusing a dirty tree, we
  # auto-shelve the owner's uncommitted work (JetBrains "shelve" style) so a
  # run is never blocked — and restore it on exit. .loop/ is EXCLUDED from the
  # shelf: it's driver/agent state the run needs on disk (prd.json, PROMPT.md,
  # verify.sh, learnings) — shelving it would break the run and hide the PRD.
  ORIG_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
  if git rev-parse --verify -q "$SHELF_REF" >/dev/null; then
    die "a previous shelf exists at $SHELF_REF (a prior run likely crashed mid-restore).
     Recover it first:  git stash apply $SHELF_REF  &&  git update-ref -d $SHELF_REF"
  fi
  # In ignored mode (D10 default) git never sees .loop, and naming an
  # ignored path in a stash pathspec makes git error out — exclude it
  # only in tracked mode. Decided by the init-time marker, not by live
  # gitignore state (see git_mode).
  local SHELF_SPEC=(-- .)
  [ "$(git_mode)" = "tracked" ] && SHELF_SPEC=(-- . ':(exclude).loop')
  if [ -n "$(git status --porcelain "${SHELF_SPEC[@]}")" ]; then
    git stash push --include-untracked -q -m "loop-tool auto-shelf" "${SHELF_SPEC[@]}"
    git update-ref "$SHELF_REF" "$(git rev-parse stash@{0})"  # keep alive off-stack
    SHELF_SHA="$(git rev-parse "$SHELF_REF")"
    git stash drop -q                                         # clear the stash stack
    echo "loop: shelved your uncommitted work → $SHELF_REF (restored on exit)"
  fi

  BRANCH="$ORIG_BRANCH"
  case "$BRANCH" in
    main|master)
      BRANCH="$(jq -r '.branch' "$PRD_JSON")"
      git checkout -b "$BRANCH" 2>/dev/null || git checkout "$BRANCH"
      echo "loop: on branch $BRANCH"
      ;;
  esac

  # Answer-file protocol: answered questions revive blocked stories, so
  # resuming after a blocked exit is always just: fill ANSWER → loop.sh run.
  # AFTER the branch checkout — in tracked mode (D10) QUESTIONS.md and
  # prd.json live on the feature branch; touching them earlier would edit
  # the wrong tree and could make the checkout itself conflict.
  auto_unblock

  local FROZEN_SUM; FROZEN_SUM="$(cat "$SUM_FILE")"
  local FAILS=0

  for i in $(seq 1 "$MAX_ITERS"); do
    local SID; SID="$(next_story)"
    if [ -z "$SID" ]; then break; fi   # nothing todo — settled check below
    local ATTEMPTS; ATTEMPTS="$(story_field "$SID" attempts)"

    # Model routing (harness §5): escalate brain before human — attempt 3 runs opus.
    local MODEL="$MODEL_EXEC"
    [ "$ATTEMPTS" -ge 2 ] && MODEL="$MODEL_ESCALATE"

    # Build prompt: base + driver directive + ladder injection (D5 baton).
    local PROMPT_TEXT; PROMPT_TEXT="$(cat "$PROMPT_MD")

## Driver directive — iteration $i
Your feature directory is \`.loop/features/$SLUG/\` — its prd.json,
QUESTIONS.md and NOTES.md are YOURS; do not read other feature folders.
Shared learnings stay in \`.loop/learnings/\`.
Work ONLY story $SID. One story per iteration, nothing else."
    if [ "$ATTEMPTS" -ge 1 ] && [ -f "$LOGS/verify-last-$SID.log" ]; then
      PROMPT_TEXT="$PROMPT_TEXT

Previous attempt(s) on $SID failed: $ATTEMPTS so far. Last verify output tail:
\`\`\`
$(tail -30 "$LOGS/verify-last-$SID.log")
\`\`\`"
    fi
    [ "$ATTEMPTS" -ge 2 ] && PROMPT_TEXT="$PROMPT_TEXT

2 attempts failed. Do NOT repeat the same approach — try a DIFFERENT angle. Re-read the story's notes and question your prior assumption."
    # Verify green but claim missing after last session → work is likely
    # done, only the flag flip is owed. Say so — saves a full re-derivation.
    if [ -f "$LOGS/green-unclaimed-$SID" ]; then
      PROMPT_TEXT="$PROMPT_TEXT

Verify is ALREADY GREEN after the previous session on $SID, but the story's
\"passes\" flag was never set. The work is most likely complete and only the
claim is missing. Confirm the acceptance criteria are genuinely met (run the
story's own tests once), then set \"passes\": true in your feature's prd.json
and commit. Do NOT rewrite or re-implement anything."
    fi

    echo ""
    echo "=== iteration $i/$MAX_ITERS — feature $SLUG story $SID attempt $((ATTEMPTS + 1)) ($MODEL, $(date +%H:%M:%S)) ==="

    claude -p "$PROMPT_TEXT" \
      --model "$MODEL" \
      --allowedTools "$ALLOWED_TOOLS" \
      --max-turns "$MAX_TURNS" \
      2>&1 | tee "$LOGS/iter-$i.log" || true

    # Usage-limit death is not the story's fault: no attempt counted, no
    # verify run (session may have died mid-edit). Sleep and retry the
    # same story — burns an iteration slot, never a ladder rung.
    if grep -qiE "hit your (session|usage) limit" "$LOGS/iter-$i.log"; then
      echo "loop: usage limit hit — sleeping ${LIMIT_BACKOFF}s, attempt NOT counted"
      sleep "$LIMIT_BACKOFF"
      continue
    fi

    # D2: gaming the exam kills the run.
    if [ "$(criteria_sum)" != "$FROZEN_SUM" ]; then
      write_report "$i" "KILLED — acceptance criteria modified by agent"
      die "acceptance criteria modified (iteration $i) — halted, inspect $PRD_JSON"
    fi
    # D7 tripwire: edit to project's verify.sh = tamper attempt = kill.
    if [ "$(verify_sum)" != "$(cat "$VERIFY_SUM_FILE")" ]; then
      write_report "$i" "KILLED — verify.sh modified by agent"
      die "verify.sh tampered (iteration $i) — halted, inspect $VERIFY"
    fi

    # Machine truth — ALWAYS the driver-owned snapshot, never the project copy (D7).
    rm -f "$LOGS/green-unclaimed-$SID"
    if "$VERIFY_SNAPSHOT" > "$LOGS/verify-$i.log" 2>&1; then
      echo "verify: PASS"
      FAILS=0
      # Dual condition per story: agent's claim AND green verify → done.
      if [ "$(story_field "$SID" passes)" = "true" ]; then
        prd_set '(.stories[] | select(.id == $id) | .status) = "done"' --arg id "$SID"
        echo "story $SID: DONE"
      else
        # Verify green but story not claimed — count attempt, keep story
        # todo, and flag it so the next prompt says "just flip the claim".
        prd_set '(.stories[] | select(.id == $id) | .attempts) += 1' --arg id "$SID"
        touch "$LOGS/green-unclaimed-$SID"
        echo "story $SID: verify green but unclaimed — next attempt told to confirm+flip"
      fi
    else
      FAILS=$((FAILS + 1))
      cp "$LOGS/verify-$i.log" "$LOGS/verify-last-$SID.log"
      prd_set '(.stories[] | select(.id == $id) | .attempts) += 1' --arg id "$SID"
      echo "verify: FAIL (loop breaker $FAILS/$FAIL_LIMIT) — see $LOGS/verify-$i.log"
      # D1: codebase itself broken → halt whole loop.
      if [ "$FAILS" -ge "$FAIL_LIMIT" ]; then
        write_report "$i" "BLOCKED — $FAIL_LIMIT consecutive verify failures"
        die "circuit breaker — see $REPORT"
      fi
    fi

    # Harness §4 ladder: attempt limit → block story, move on.
    ATTEMPTS="$(story_field "$SID" attempts)"
    if [ "$(story_field "$SID" status)" = "todo" ] && [ "$ATTEMPTS" -ge "$ATTEMPT_LIMIT" ]; then
      prd_set '(.stories[] | select(.id == $id) | .status) = "blocked"' --arg id "$SID"
      echo "story $SID: BLOCKED after $ATTEMPTS attempts — moving on"
    fi

    # Baton durability (tracked mode only, D10): the driver's own prd.json
    # mutations and anything the agent forgot to commit must survive in git.
    # In ignored mode disk is the baton and git must never see .loop —
    # gated on the marker, NOT on gitignore state, which can be shelved away.
    if [ "$(git_mode)" = "tracked" ]; then
      git add .loop 2>/dev/null || true
      git commit -qm "chore(loop): $SLUG iter $i state — $SID" -- .loop 2>/dev/null || true
    fi

    if all_settled; then break; fi
  done

  if all_done; then
    write_report "$i" "COMPLETE"
    echo "loop: COMPLETE — feature '$SLUG' done, verify green"
    exit 0
  elif all_settled; then
    write_report "$i" "PARTIAL — blocked stories need you"
    if [ -f "$QUESTIONS" ]; then
      echo "loop: to resume — fill the ANSWER lines in .loop/features/$SLUG/QUESTIONS.md, then re-run: loop.sh run $PROJECT"
    fi
    exit 2
  else
    write_report "$i" "CAPPED — max iterations reached"
    die "max iterations ($MAX_ITERS) reached — see $REPORT"
  fi
}

# ------------------------------------------------------------- harvest -----
cmd_harvest() {
  [ -f "$TOOL_DIR/templates/HARVEST-PROMPT.md" ] || die "missing templates/HARVEST-PROMPT.md"
  cd "$PROJECT"
  mkdir -p "$PROJECT/.claude/skills-proposed"

  # Failure-driven promotion (owner call 2026-07-05): the driver already
  # knows which stories hurt — inject that evidence so the librarian
  # mines postmortems first instead of hoping it digs them up.
  # v3: evidence spans ALL features — cross-feature recurrence is exactly
  # what makes a lesson skill-worthy (harvest-step.md bar #1).
  local EVIDENCE="" pj slug HARD_STORIES f
  for pj in "$FEATURES_DIR"/*/prd.json; do
    [ -f "$pj" ] || continue
    slug="$(basename "$(dirname "$pj")")"
    HARD_STORIES="$(jq -r '.stories[] | select(.attempts >= 2)
      | "- \(.id) [\(.status)] attempts=\(.attempts): \(.notes | .[0:200])"' "$pj")"
    [ -n "$HARD_STORIES" ] || continue
    EVIDENCE="$EVIDENCE

## Driver evidence — feature '$slug', stories that cost >=2 attempts (mine these FIRST)
$HARD_STORIES"
    for f in "$(dirname "$pj")/logs"/verify-last-*.log; do
      [ -f "$f" ] || continue
      EVIDENCE="$EVIDENCE

### $slug/$(basename "$f") — last failure tail
\`\`\`
$(tail -15 "$f")
\`\`\`"
    done
  done

  echo "loop: librarian session — drafts land in .claude/skills-proposed/, nothing goes live"
  claude -p "$(cat "$TOOL_DIR/templates/HARVEST-PROMPT.md")$EVIDENCE" \
    --model "$MODEL_EXEC" \
    --allowedTools "Read,Write,Glob,Grep" \
    --max-turns "$MAX_TURNS"
  echo "loop: harvest done — review .claude/skills-proposed/ and approve manually"
}

# ---------------------------------------------------------------- main -----
case "$CMD" in
  init)    cmd_init ;;
  prd)     migrate_legacy; cmd_prd ;;
  run)     migrate_legacy; cmd_run "$@" ;;
  harvest) migrate_legacy; cmd_harvest ;;
  *)       die "unknown command '$CMD' — use init | prd | run | harvest" ;;
esac
