# Harvest Step (Phase 3) — design (settled 2026-07-04)

The step AFTER a feature ships: mistakes and lessons → durable knowledge,
so no mistake is paid for twice. Extends the promotion lifecycle in
context-store.md with a third target: **skills**.

Phases: 0 PRD → 1 loop → 2 human review → **3 harvest**.

## Learning vs skill

```
learnings page = FACT, pull-based
                 "vitest resets mocks between files"
                 read when INDEX decision-hook matches the story
skill          = PROCEDURE, push-based
                 "BEFORE writing storage tests, do X, Y, Z"
                 auto-fires by description match; cannot be forgotten
```

## Pipeline

```
during loop   mistakes recorded free-form: failure logs, attempts
              counts, story notes, learnings pages (working memory)
                    ▼
feature done  loop.sh harvest → LIBRARIAN session (cheap model, read-only
              on code; writes only knowledge artifacts)
              reads: .loop/learnings/, logs/, blocked stories, attempts
              classifies each item:
                one-off fact           → learnings page (project or global)
                repeated OR procedural → DRAFT skill → .claude/skills-proposed/
                    ▼
morning       human reviews report → approve → move to .claude/skills/ (live)
```

Skills are STAGED, never auto-live. A wrong skill auto-fires in every
future session and silently steers all work — worse than no skill.
Same recurring pattern: agent drafts, human accepts.

## Promotion bar (high, deliberately)

Item becomes a skill draft only if ALL:

1. Cost ≥2 iterations OR recurred across ≥2 stories/features
2. Countermeasure is procedural ("do X before Y"), not a bare fact
3. Trigger fits one line — the skill description is a decision hook,
   same principle as a learnings INDEX line

Fails any → stays a learnings page. Rationale: every live skill's
description loads into every future session — permanent context tax.
One good skill preventing a repeated mistake pays for itself; ten vague
skills are pure tax. 50 skills = the 50-page-index disease.

## Scope — project skills only (owner call)

- Skills created by harvest go to the PROJECT's `.claude/skills/` only.
- Global (`~/.claude/skills/`) = personal, human-curated, outside
  loop-tool automation. Stack-level lessons still promote to global
  LEARNINGS (`~/loop-tool/learnings/`) as already settled — they just
  don't become global skills automatically.
- Goal: minimize always-on context; knowledge loads only where and when
  needed.

## Layer ownership

- context store — artifact formats (skill = folder + SKILL.md,
  frontmatter name/description + body)
- harness — staging rule (skills-proposed/, never direct-to-live),
  librarian is read-only on code
- driver — invocation (`loop.sh harvest <project>`)

## Startup mode (owner call, reinforces D4)

Make it work first; optimize cost later. Don't gold-plate the librarian
or meter its tokens in v1 — correctness of promotion (right lessons,
high bar, staged) is the v1 quality bar.
