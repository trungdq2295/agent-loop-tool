# Validation run — does the tool beat interactive at target size?

Status: protocol registered 2026-07-13, run not yet executed.

The doubt (owner, 2026-07-13): "with a design doc covering
implementation, interactive Claude handles it — tool adds nothing."
Prior testing used small features, where interactive genuinely wins
(positioning doc: 1-iteration features feel identical to interactive).
This run tests the tool at its claimed sweet spot. Criteria below are
pre-registered — decided BEFORE the run, so the outcome can't be
argued into a win afterwards.

## Feature selection (all required)

- Real production feature with a real, approved design doc that pins
  implementation (HOW), not just intent
- ≥ 8 stories after PRD splitting — smaller invalidates the test
- Single repo (D11 workspace mode not built yet)
- Objective verify surface: test suite runnable from CLI. Backend-leaning
  preferred; if UI-heavy, land the Playwright verify additions first
- Owner can estimate honestly what the same feature would cost
  interactively (hours of attention) — this is the baseline

## Protocol

1. Fill `.loop/verify.sh` Block 1 for the repo; confirm it runs green
   on main BEFORE the PRD session.
2. `loop.sh prd <project>` — hand the agent the design doc
   (PRD-PROMPT.md §1b: validation mode, translate-or-flag, demote HOW,
   drift check). Approve read-back. Criteria freeze.
3. Record: minutes of human attention spent in the PRD session.
4. `loop.sh <project>` — run unattended (overnight is the honest test).
   Record every human intervention: what, why, minutes.
5. Phase 2 review: read acceptance TESTS against the PRD checklist
   (never implementation). Record review minutes.
6. `loop.sh harvest` regardless of outcome — failure log is a
   deliverable either way.

## Measurements

| Metric | How |
|---|---|
| Human-attention minutes | PRD + interventions + review, logged as they happen |
| Stories done / blocked | prd.json final state |
| Iterations, wall-clock | driver log |
| Test honesty | red-first honored? assertions real, not gutted? |
| Would-you-merge | owner judgment after Phase 2, yes/no per story |
| Interactive baseline | owner's pre-run estimate, written down in step 1 |

## Pre-registered verdict

**Tool wins** iff ALL:
- ≥ 80% of stories done unattended (no mid-run human help)
- total human-attention minutes < 1/3 of the interactive baseline
- Phase 2 finds no gamed tests (red-first held, assertions meaningful)

**Tool loses** if ANY:
- babysitting minutes exceed the interactive baseline
- gamed tests found (ratchet held but assertions gutted)
- fail ladder blocks ≥ 1/3 of stories

**Middle** = neither → harvest log names the weak layer (examiner,
env contract, prompts); fix, re-run before any D11 investment.

Lose or middle does NOT mean abandon — it means the failure log, not
intuition, decides what gets built next. Win → demo material for team
rollout + green light for D11.
