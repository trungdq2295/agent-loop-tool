# D4 — Optimize speed-to-done over token shaving

Date: 2026-07-04 · Owner-approved (explicit owner call)

## Decision

When speed and token cost conflict: choose speed, as long as token cost
stays reasonable. Wasted iteration = the most expensive event
(wall-clock + tokens + human morning attention).

## Consequences already applied

- Agent reads WHOLE prd.json + learnings INDEX + git log every
  iteration (~1-2k tokens) — informed agent, fewer blind retries
- Current-story-only prompt injection REJECTED — saves tokens, starves context
- Opus escalation at story attempt 3 — pricier call, faster unblock than
  sonnet flailing + human morning
- Fresh session per iteration — re-pay context each time, buy zero rot
- Caps generous (D1)

## Rule of thumb

Token spending that PREVENTS wasted iterations = cheap.
Token shaving that CAUSES wasted iterations = expensive.

## Revisit when

- Real runs show token cost per feature materially painful → revisit the
  cheapest-impact levers first (report verbosity, log tails), context
  richness LAST
