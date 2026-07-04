# Harness — design (settled 2026-07-04)

The loop system = 3 subsystems: **context store** (what agent knows),
**harness** (what agent may do), **driver** (when agents run). This doc
specifies the harness. Discussed and approved by owner; change only with
owner sign-off.

## What the harness is (and is not)

- Harness gates behavior **within** one iteration: what the agent may
  touch, spend, and claim.
- Harness does NOT decide loop exit. It produces **signals** — verify
  pass/fail, `passes` flags, checksum intact/broken, attempt counts,
  QUESTIONS/BLOCKED entries — and the **driver** reads signals and decides
  continue / escalate / halt / exit.
- Every rule here must be mechanical (permission config, checksum, cap,
  flag), never persuasive ("please don't"). Prompt text is a courtesy
  copy of the rule, not the enforcement.

## 1. Capabilities — "nothing deleted, nothing installed, laptop untouchable"

Three enforcement rings:

- Ring 1 — Claude Code permission rules (project `.claude/settings.json`),
  checked before every command:
  - DENY: `rm`, `rmdir`, package installs (`npm install/add`, `brew`,
    `pip`), network fetches (`curl`, `wget`), `git push`, anything
    touching paths outside the project dir.
  - ALLOW: edit/read within project, run tests, `git add/commit` on the
    loop branch.
- Ring 2 — driver-level: loop refuses dirty tree, refuses main/master,
  runs on an isolated `loop/run-*` branch. Bad run = delete branch;
  blast radius is one branch.
- Ring 3 — `--allowedTools` + `--max-turns` per session (already in
  loop.sh).

## 2. Test protection — update allowed, delete never

- An existing test exists for a reason. Agent may UPDATE a test when the
  story legitimately changes behavior; may never delete, skip
  (`.skip`/`xit`), or weaken assertions to get green.
- Mechanical backstop — the ratchet, in verify.sh: test COUNT never
  decreases between iterations. Count drops → verify fails → circuit
  breaker path, human sees it.
- Acceptance criteria are the extreme case: frozen, checksummed by the
  driver; any edit → hard halt (already in loop.sh).

## 2b. Commit-often + baton (resume protocol, [D5](decisions/D5-resume-baton.md))

- Every green sub-step = WIP commit on the loop branch (`wip(S3): ...`);
  squash at story end. Cutoff loses minutes, not the iteration.
- Before ANY session ends: update the story's `notes` — done / next /
  suspicion. Mandatory baton, not a diary; the next session resumes
  from it.

## 3. Scope — one story, discovered bugs triaged not chased

- One story per iteration. Nothing else.
- Agent discovers an adjacent bug:
  - Related to current story → STOP, write to `.loop/QUESTIONS.md`,
    story stays unfinished, human decides.
  - Unrelated → one line in `.loop/NOTES.md` (surfaces in morning
    report), continue current story. Never fix drive-by.

## 4. Timebox — per-story fail ladder

```
fail 1 → retry; next iteration's agent sees its own failure log
fail 2 → driver injects "2 attempts failed, try a different angle" into prompt
fail 3 → story marked BLOCKED in prd.json; loop moves to next story
all stories done-or-blocked → loop exits, writes morning report
```

- Session-level timebox = `--max-turns` per iteration.
- This ladder is per-STORY; the existing 3-consecutive-verify-fails
  circuit breaker is per-LOOP (codebase itself broken). Both live in the
  driver.

## 5. Model routing — budget layer

Optimization priority (owner call, 2026-07-04): **speed to done over token
shaving**, as long as token cost stays reasonable. A wasted iteration is
the most expensive thing in the system — it costs wall-clock, tokens, AND
human morning attention. Spend tokens freely when they buy fewer wasted
iterations (full context each iteration, early opus escalation); reject
token tricks that starve the agent of context.

Policy lives here; the driver enforces it by passing `--model` when it
spawns each session.

| Job | Model class | Why |
|---|---|---|
| PRD interview + distill | opus | one-shot, high leverage — bad PRD poisons every iteration |
| Loop iterations (test → implement → commit) | sonnet | repeated, well-scoped, ~5× cheaper; volume lives here |
| verify.sh | none | bash; free; the whole point |
| Morning report summary | haiku | log summarization |

- Escalation policy: escalate BRAIN before escalating to HUMAN. Story
  fails 2× on sonnet → attempt 3 runs opus → only then BLOCKED. Cheap
  brain for the happy path, expensive brain as a retry weapon, human as
  last resort.
- Ties into the fail ladder: fail-2's "different angle" injection and
  the opus escalation are the same driver branch.

## Recurring pattern (same as everywhere)

**Human defines truth → agent drafts/claims → machine checks → human
accepts.** The harness is the "machine checks" leg, made of dumb
mechanisms the agent cannot argue with.

## Not yet in loop.sh (settled here, needs wiring)

- Per-story fail ladder + BLOCKED story status in prd.json (loop.sh only
  has the per-loop circuit breaker today)
- Model routing (`--model` flag + escalation branch)
- Ring-1 permission DENY rules (project settings file)
- Test-count ratchet in verify.sh template
- QUESTIONS.md / NOTES.md conventions in PROMPT.md template
