# Context Store — design (settled 2026-07-04)

The loop system = 3 subsystems: **context store** (what agent knows),
**harness** (what agent may do), **driver** (when agents run). This doc
specifies the context store. Discussed and approved by owner; change only
with owner sign-off.

## Principles

- Agent sessions are mortal; files are the only memory.
- Every artifact has ONE owner: human, agent, or machine-generated.
- Human never needs to read/write JSON or markdown — input is conversation;
  files are agent-authored records the human approves via read-back.
- Token cost of context must stay ~constant as project knowledge grows
  (index + pages, load on demand — never one growing flat file).

## Artifacts

### PRD flow (per feature)

```
PM speaks / rough prompt              ← actual input, any shape
        ▼ agent interviews, distills
.loop/PRD.md                          ← agent-AUTHORED meeting minutes; the contract
        ▼ agent reads back as plain checklist
PM approves verbally ("yes, but #3 wrong")
        ▼ agent compiles
.loop/prd.json                        ← machine state; never shown to PM
```

- PRD.md is the frozen record of what was agreed. On any disagreement,
  PRD.md wins over prd.json.
- prd.json: stories with `id`, `story`, `acceptance` (frozen, checksummed,
  read-only to agent), `passes` (agent's claim), `notes` (agent's, free).
- Acceptance criteria compile into tests (test-first rule): layer-2
  feature criteria become layer-1 suite invariants once merged. Today's
  acceptance tests protect tomorrow's loops.

### Git history

Secondary store, not primary:

- `prd.json` passes flags → primary current-state, 1-line read
- `git log --oneline -15` → cheap recent-activity skim
- `git diff / show` → forensic detail on demand
- Rule: story ID in every commit message (`feat(S3): ...`) so
  criteria → commit → diff is one grep.
- Git records *what*, poorly *why-not* — dead ends belong in learnings.

### Learnings — dictionary, not flat file

```
project/.loop/learnings/
  INDEX.md              ← always loaded; one line per topic
  <topic>.md            ← loaded only when story-relevant

~/loop-tool/learnings/  ← GLOBAL: stack-level, cross-project
  INDEX.md, vitest.md, react.md, ...
```

- Iteration protocol: always read both INDEX files; open only pages
  matching the current story.
- Index line = decision hook telling agent WHEN to open the page
  ("read BEFORE writing any test touching storage"), not a label.
- Topic granularity ≈ one subsystem per page; merge cousin pages —
  a 50-page index is the new bloat.
- Global learnings compound across projects: project 2 starts knowing
  every trap project 1 paid to discover.

### Lifecycle (per feature)

```
iteration learnings → .loop/learnings/ (working memory)
feature done:
  durable project truths → promote to CLAUDE.md/AGENTS.md (human approves)
  stack-level truths     → promote to ~/loop-tool/learnings/
  the rest               → archive .loop/archive/<feature>/ (never auto-read)
PRD.md → stays; future PRD sessions read past PRDs for product context
```

## Verification layers (context ↔ harness boundary)

- Layer 1 — project invariants: suite, typecheck, lint. Feature-agnostic,
  permanent, lives in verify.sh. "Is the codebase still healthy?"
- Layer 2 — acceptance criteria: per-story, human-approved intent.
  "Did you build the right thing?" Compiled into tests, joins layer 1.
- Unclosable-by-machine gap: is the test a faithful translation of the
  criteria? Human Phase-3 review = read acceptance TEST FILES, not
  implementation. Concrete criteria ("expired token → 410") translate
  faithfully; vague ones ("handles errors gracefully") invite weak tests.

## Recurring pattern (applies to every artifact)

**Human defines truth → agent drafts/claims → machine checks → human accepts.**
PRD, verify.sh, code, learnings promotion — same shape everywhere.
