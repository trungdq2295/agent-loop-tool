# PRD Step (Phase 0) — design (settled 2026-07-04)

The step BEFORE the loop: PM conversation → frozen machine-checkable
contract. Interactive — the only phase where human and agent talk live.
Discussed and approved by owner; change only with owner sign-off.

Why this phase gets the expensive brain and unlimited patience: it is the
biggest speed lever in the system. One vague acceptance criterion = N
wasted loop iterations downstream. Cheapest place to catch ambiguity is
the interview; most expensive is production.

## Ownership (the gap this doc closes)

- context store owns the artifact FORMATS (PRD.md, prd.json — see
  context-store.md)
- harness owns the RULES (opus model, criteria frozen after approval)
- driver owns the INVOCATION (`loop.sh prd <project>` subcommand)
- this doc owns the STEP — protocol, gates, exit condition

## Protocol

```
loop.sh prd <project>
  → spawns INTERACTIVE claude session (opus, templates/PRD-PROMPT.md)

1. INTERVIEW   agent asks until concrete: scope, users, edge cases,
               error cases, what "done" means. PM answers in any shape.
2. DISTILL     agent writes .loop/PRD.md — meeting minutes, the human
               contract. On disagreement PRD.md wins over prd.json.
3. READ-BACK   agent presents plain-language checklist. PM approves
               verbally ("yes, but #3 wrong" → revise → read back again).
               Loop until explicit "approved".
4. COMPILE     agent writes .loop/prd.json — machine state. Never shown
               to PM.
5. HANDOFF     driver checksums acceptance criteria (frozen from here),
               confirms branch name, reports "ready: N stories".
```

## The concreteness gate (step 1-3, non-negotiable)

Agent is FORBIDDEN to accept a criterion that is not observable:

- ✅ "expired token → request returns 410"
- ✅ "empty cart → checkout button disabled"
- ❌ "handles errors gracefully" — agent must push back and ask
  "gracefully = what, exactly? what does the user see?"
- Test: a criterion is concrete iff a test could fail it. If the agent
  cannot imagine the failing test, it keeps interviewing.

Second gate — **story size** ([D5](decisions/D5-resume-baton.md)): a
story must fit one session comfortably (~30-60 turns). Too big → agent
splits it in the interview ("this is 3 stories, not 1"). Scope-down
happens at PRD time, never by starving driver caps.

PM writes nothing, reads no JSON/MD. Input is conversation; approval is
conversation. (PM may read PRD.md if curious — it is written for humans —
but the read-back checklist is the official approval surface.)

## prd.json schema (compile target)

templates/prd.json, plus two fields added for the fail ladder:

```json
{
  "feature": "...", "branch": "loop/...",
  "stories": [{
    "id": "S1",
    "story": "As a user, I can ...",
    "acceptance": ["observable behavior", "..."],   // FROZEN, checksummed
    "passes": false,        // agent's claim
    "status": "todo",       // todo | blocked | done — driver-owned
    "attempts": 0,          // driver-owned, drives the fail ladder
    "notes": ""             // agent's free memory
  }]
}
```

## Exit condition

Phase 0 ends only when ALL true:
- PM said "approved" to the read-back (explicit, not implied)
- every acceptance criterion passes the concreteness gate
- prd.json validates (jq parses, required fields present)
- checksum taken → criteria frozen

Then and only then may `loop.sh <project>` run. Loop refuses a project
whose prd.json has no checksum record.

## Speed-first alignment

- Opus + long interview = tokens spent ONCE to protect every iteration
  after. Aligned with owner priority: speed to done over token shaving.
- PRD.md stays after feature ships; future PRD sessions read past PRDs
  for product context (see context-store.md lifecycle).
