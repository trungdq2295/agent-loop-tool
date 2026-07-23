# UI gate — objective browser checks for UI work

The default `verify.sh` gate proves a codebase *compiles and its unit tests
pass*. For UI work that isn't enough: the thing that matters ("the Live badge is
green", "Approve shows only on a live-request row", "the row opens a modal") is
**behavior in a rendered page**, invisible to a unit test. The UI gate closes
that — objectively, so it stays a gate the agent can't talk its way past.

## What it is

A real browser (puppeteer-core, installed locally in `.loop/ui-gate/`) driven
against the running app. `init` scaffolds it for a detected UI project:

```
.loop/ui-gate/
├── gate.mjs          # RUNNER (frozen harness — do not edit). Loads + runs checks.
├── checks/*.mjs      # per-story acceptance checks (agent writes, red-first)
├── node_modules/     # local puppeteer-core (gitignored with .loop/)
└── shots/            # failure screenshots
```

and injects a boot→wait→drive→teardown block into `.loop/verify.sh`.

## The one rule: assert SEMANTICS / INTENT, never pixels

Reducible-to-objective UI facts are the gate's domain:

- **role / text / label** — what the user perceives (`getByRole`-style).
- **intent-encoding class** — `ant-tag-green` means "this is Live". The class
  *is* the requirement, so asserting it is asserting intent, not markup.
- **computed style in a real browser** — `getComputedStyle(el).color`. A unit
  test in jsdom **cannot** do this (no layout/CSS engine); that's why the gate
  needs a real browser.
- **behavior** — click opens a modal, nav changes the URL.

Banned as gates (they pass trivially on first run → prove nothing → break
red-first): **screenshot baselines, DOM snapshots (`toMatchSnapshot`), exact
padding/margins**. That's regression theater, not acceptance.

Aesthetic quality ("looks polished", "matches the mockup") is **not** reducible
and is **not** the gate's job — that's a human/vision-review concern, kept
advisory so the loop's determinism survives.

## Repo knowledge (you fill this — the tool stays generic)

The tool hardcodes nothing app-specific. Two places carry the facts:

1. **`.loop/verify.sh` UI block** — the machine-usable values:
   - `UI_BOOT_CMD` — command that starts the app (e.g. `npm start`, `npm run dev`).
   - `UI_GATE_BASE_URL` — the app's origin **incl. port** (e.g. `http://localhost:3000`).
   - `UI_GATE_CHROME` — optional; auto-detected across common OS paths otherwise.
2. **`CLAUDE.md` `## Loop UI gate`** — the same facts in prose (boot / url /
   route / chrome), so every fresh iteration reads them.

## Writing a check (per story, red-first)

Copy `checks/_example.mjs` to a real name. Default-export `async (page, ctx)`;
**throw** on failure. `ctx.goto(route)` navigates `UI_GATE_BASE_URL + route`.

```js
export default async function (page, ctx) {
  await ctx.goto('/#/feature-config-v2');
  const badges = await page.$$eval('.ant-tag', (e) => e.map((x) => x.className));
  if (!badges.some((c) => /ant-tag-green/.test(c))) throw new Error('no green Live badge');
}
```

Red-first still holds: the check must **fail** (element absent / wrong text)
before the story is built, and go green after. A check that passed before you
wrote the feature is testing nothing.

## How the runner stays honest

`gate.mjs` (the runner) is **frozen** alongside `verify.sh` (`verify_sum` hashes
both) — the agent can't neuter the harness. The `checks/*.mjs` are the test
layer: agent-authored, red-first, protected by the same PROMPT rules + ratchet as
any test file (never delete/skip/weaken to go green).

## Faster path (optional)

Booting a dev server every verify is the general default (works when a repo needs
live proxying). When the app can run from a static build, a repo can instead
serve its built output and have checks fulfil any bootstrap request via
puppeteer request-interception — fewer moving parts, no compile per iteration.
That's a repo choice expressed entirely in its `UI_BOOT_CMD` + checks; the runner
doesn't care.

## Non-UI repos

`init` only scaffolds this when it detects a UI framework. Everything else gets
the plain `verify.sh` — zero UI noise.
