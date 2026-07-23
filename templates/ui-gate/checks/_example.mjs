// EXAMPLE check — leading underscore means the runner SKIPS it. Copy to a real
// name (e.g. `status-badges.mjs`) and write your story's acceptance.
//
// A check is a per-story acceptance test. Default-export an async (page, ctx)
// function; THROW on failure. Assert SEMANTICS / INTENT, never pixels:
//   - role / text / label          (what the user perceives)
//   - intent-encoding class         e.g. `ant-tag-green` = "this badge is Live"
//   - computed style in a real DOM  getComputedStyle(...).color  (jsdom can't)
//   - behavior                      click → modal opens, nav → URL changes
// Do NOT assert exact padding, DOM snapshots, or screenshots — they pass on
// first run and prove nothing (regression theater, breaks red-first).
export default async function (page, ctx) {
  await ctx.goto('/');                          // baseUrl + route
  await page.waitForSelector('.ant-menu', { timeout: 20000 });

  const menuNodes = await page.$$eval(
    '.ant-menu .ant-menu-item, .ant-menu .ant-menu-submenu',
    (els) => els.length
  );
  if (menuNodes < 1) throw new Error(`expected a rendered menu, got ${menuNodes} nodes`);

  // intent-class example: a Live badge must carry the green class
  // const badges = await page.$$eval('.ant-tag', (e) => e.map((x) => x.className));
  // if (!badges.some((c) => /ant-tag-green/.test(c))) throw new Error('no green Live badge');
}
