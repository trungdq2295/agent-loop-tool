# D1 — Circuit breaker 3, turn cap 80, iteration cap 25

Date: 2026-07-04 · Owner-approved

## Decision

- Per-loop circuit breaker: 3 consecutive verify.sh failures → halt, BLOCKED.md
- Per-iteration turn cap: `--max-turns 80`
- Per-run iteration cap: 25 default (CLI-overridable)

## Numbers behind it

Turn = one agent tool action. One-story session budget:
read context ~5, failing test ~5, implement ~10-30, run/fix ~10-30,
commit ~3 → typical 35-75. Cap 80 = comfortable ceiling, cuts only
pathological spinning.

Iteration = one session. 5-story feature: perfect = 5, realistic with
retries + ladder = 10-20. Cap 25 = overnight-sized.

## Rationale

- Caps are runaway INSURANCE, not scheduling. Early-stop of bad runs is
  the ladder's job (3 attempts/story) + breaker's job (3 fails/loop) —
  those trigger on evidence; caps only bound the worst case.
- Speed-first (D4): stingy caps cut honest work mid-story = wasted
  iteration = the most expensive event in the system.
- Owner hallucination concern: context rot comes from long MIXED
  sessions, not 80 turns on ONE story. Mitigated by story-size gate
  (prd-step.md), not by starving caps.

## Alternatives rejected

- turns 50 (v1 default): medium story touches ceiling
- turns 120: weakest runaway bound, no added benefit once stories sized right
- iters 10 (v1 default): real feature stops incomplete
- breaker 2: false halts on honest recovery; breaker 5: burns 5 iterations on broken codebase

## Revisit when (tuning signals)

- >20% of iterations hit turn cap → stories too big (fix PRD gate first, raise cap second)
- sessions produce off-story or incoherent work → lower turn cap
- runs regularly exit at iteration cap while progressing honestly → raise iter cap
- breaker fires on recoverable situations repeatedly → consider 4
