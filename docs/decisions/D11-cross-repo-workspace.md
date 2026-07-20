# D11 — Cross-repo via assembled workspace; spec precision scales with blast radius

Date: 2026-07-09 · Owner call (discussion logged before build)

## Decision

- **Cross-repo = one forced pattern, no generic multi-root.** User
  assembles a *workspace*: one git repo, needed repos cloned into
  subdirs, inner `.git` stripped. The workspace is just a repo, so the
  hardened core loop runs unmodified on it. Single-repo path untouched —
  workspace mode is additive, activated by detection.
- **Root repo map tells the AI which repo owns what.** Interim: a root
  `CLAUDE.md` in the workspace (per-repo responsibility, stack, verify
  command). Future: a central *engineering skill-builder* repo — org
  catalog (repo → URL, responsibility, verify cmd), change-flow
  knowledge ("API change: contract → server → client"), skills,
  and the design/assembly prompts.
- **Pipeline gains upstream stages:** Design → Assemble → PRD → Run →
  Harvest. Design doc decided *before* PRD; assembly prompt reads the
  design doc + repo map to pick and clone repos.
- **Design doc gate is conditional, not universal.** Principle: *spec
  precision scales with blast radius.* Small single-repo feature →
  prompt + PRD interview is enough (today's behavior, zero new
  friction). Cross-repo / workspace → `prd` refuses without
  `features/<slug>/DESIGN.md`; the design step *creates* the doc (AI
  drafts from repo map + flows, human approves), then it freezes with
  the criteria — same crank as PRD.
- **Build here now, extract later.** No v3 redesign of loop.sh. New
  intelligence (design prompt, assembly prompt, interview additions)
  is born as prompts/templates, never bash — so it can move into the
  skill-builder repo without surgery. loop.sh gains only mechanics:
  workspace detection in `init` auto-fill (per-repo verify blocks),
  `repos:` field awareness, DESIGN.md presence gate, gitlink guard.

## The spec spectrum (why the gate is conditional)

Prompt, PRD, design doc are the same species — a spec telling the AI
what to do — differing only in precision:

```
prompt      intent only            AI decides everything else
PRD         WHAT pinned            HOW still free
design doc  WHAT + HOW pinned      only implementation detail free
```

Each notch up converts an AI decision into an upfront human decision.
What makes a design doc "clearer" is verifiability: *done looks like Y,
checked by Z*. Where the spec is silent the agent decides — cheap when a
wrong guess costs one iteration, expensive when it costs cross-repo
rework. Hence: more blast radius → more required precision. The whole
tool is a spec-refinement machine (AI drafts → human gates → freeze) at
every altitude; the design step is one more turn of the same crank.

## Traps identified (design around, not after)

- **Gitlink trap:** nested `.git` inside the workspace → outer repo
  records gitlinks, inner files silently untracked, verify passes on
  the wrong tree. Assembly must strip inner `.git`; `init` should guard.
- **Token blowup:** skill-builder knowledge must be pull-based (index +
  per-story reads, like `learnings/`), never bulk-loaded per iteration —
  flat per-iteration cost is the tool's core economy.
- **Frozen-exam principle extends:** central skill repo pinned by commit
  SHA at PRD freeze; catalog verify command wins over auto-detection.

## Alternatives rejected

- Generic multi-root driver (keep nested `.git`, per-repo branches /
  shelving / verify): touches all ~27 git call sites in loop.sh for a
  case the workspace pattern already covers. Backlog, not now.
- Universal design-doc gate: pure friction for small features → team
  skips the tool (D8). Conditional gate instead.
- v3 rewrite of loop.sh (language or structure): the core loop is the
  most battle-tested asset; redesign is boundary-redrawing (evict
  intelligence to prompts), not engine replacement.

## Deferred

- `loop.sh export` — split workspace branch diff per subdir, apply back
  to original repos as PR-ready branches. Manual recipe in docs until
  then: `git diff main -- repo-a/ | git -C ../real-a apply`.
- Catalog staleness checks (owner per entry, periodic verify).
- Verify scoping per story (run only affected repos' blocks).

## Revisit when

- Skill-builder repo exists → move design/assembly prompts + repo-map
  convention there; loop.sh keeps only mechanics.
- A team needs same-workspace parallel features → worktree item in
  BACKLOG.md.
