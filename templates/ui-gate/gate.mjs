// .loop/ui-gate/gate.mjs — UI browser-gate RUNNER (frozen harness; do NOT edit).
//
// GENERIC. Knows nothing about any specific app. All repo-specific facts arrive
// as ENV (set by verify.sh's UI block, which is where a repo records them):
//   UI_GATE_BASE_URL   required — the running app's origin, e.g. http://localhost:3000
//   UI_GATE_CHROME     optional — path to a Chrome/Chromium binary; auto-detected if unset
//
// Contract:
//   - verify.sh has ALREADY started the app + waited until UI_GATE_BASE_URL is ready.
//   - This runner drives a real browser (puppeteer-core, installed locally in
//     .loop/ui-gate/node_modules) and runs every check in ./checks/*.mjs.
//   - Each check is a per-story ACCEPTANCE test the agent writes red-first (like any
//     test file). A check throws on failure. This runner is the harness, not an
//     assertion — assertions live in the checks.
//   - Exit 0 = all checks passed; non-zero = a check failed / setup error.
//
// Assert SEMANTICS / INTENT (role, text, intent-encoding class, computed color in a
// real browser, behavior). NEVER pixels, DOM snapshots, or exact padding — those pass
// trivially on first run (regression theater, violates red-first).
import { createRequire } from 'module';
import { readdirSync, existsSync, mkdirSync, statSync } from 'fs';
import { fileURLToPath } from 'url';
import path from 'path';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const require = createRequire(path.join(HERE, '/'));

const BASE_URL = process.env.UI_GATE_BASE_URL;
if (!BASE_URL) {
  console.error('GATE ERROR: UI_GATE_BASE_URL is not set (verify.sh UI block must export it).');
  process.exit(2);
}

// Chrome: explicit env wins; else probe the usual per-OS locations.
function resolveChrome() {
  if (process.env.UI_GATE_CHROME) return process.env.UI_GATE_CHROME;
  const candidates = [
    '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
    '/Applications/Chromium.app/Contents/MacOS/Chromium',
    '/usr/bin/google-chrome',
    '/usr/bin/google-chrome-stable',
    '/usr/bin/chromium',
    '/usr/bin/chromium-browser',
    'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe',
  ];
  for (const c of candidates) { try { if (statSync(c).isFile()) return c; } catch {} }
  return null;
}
const CHROME = resolveChrome();
if (!CHROME) {
  console.error('GATE ERROR: no Chrome/Chromium found. Set UI_GATE_CHROME to the binary path.');
  process.exit(2);
}

let puppeteer;
try {
  puppeteer = require('puppeteer-core');
} catch {
  console.error('GATE ERROR: puppeteer-core not installed in .loop/ui-gate/node_modules');
  console.error('  fix: (cd .loop/ui-gate && npm i puppeteer-core@21)');
  process.exit(2);
}

const checksDir = path.join(HERE, 'checks');
const files = existsSync(checksDir)
  ? readdirSync(checksDir).filter((f) => f.endsWith('.mjs') && !f.startsWith('_')).sort()
  : [];
if (files.length === 0) {
  console.log('UI gate: no checks in .loop/ui-gate/checks/ yet — passing (0 checks).');
  process.exit(0);
}

const SHOT_DIR = path.join(HERE, 'shots');
if (!existsSync(SHOT_DIR)) mkdirSync(SHOT_DIR, { recursive: true });

const browser = await puppeteer.launch({
  executablePath: CHROME,
  headless: 'new',
  args: ['--no-sandbox', '--disable-dev-shm-usage'],
});

let failed = 0;
try {
  for (const file of files) {
    const mod = await import(path.join(checksDir, file));
    const check = mod.default;
    if (typeof check !== 'function') {
      console.error(`  ✗ ${file}: no default-exported async (page, ctx) function`);
      failed++;
      continue;
    }
    const page = await browser.newPage();
    await page.setViewport({ width: 1440, height: 900 });
    const pageErrors = [];
    page.on('pageerror', (e) => pageErrors.push(String(e)));
    const ctx = {
      baseUrl: BASE_URL,
      goto: (route = '/') =>
        page.goto(BASE_URL + route, { waitUntil: 'networkidle2', timeout: 45000 }),
      pageErrors,
    };
    try {
      await check(page, ctx);
      console.log(`  ✓ ${file}`);
    } catch (e) {
      console.error(`  ✗ ${file}: ${e.message}`);
      failed++;
      try {
        await page.screenshot({ path: path.join(SHOT_DIR, file.replace(/\.mjs$/, '.fail.png')) });
      } catch {}
    } finally {
      await page.close();
    }
  }
} finally {
  // Always tear down Chrome, even if a check module fails to import or a page
  // fails to open outside the per-check try — otherwise the process exits with
  // an orphaned browser.
  await browser.close();
}

if (failed) {
  console.error(`UI gate: ${failed}/${files.length} check(s) FAILED`);
  process.exit(1);
}
console.log(`UI gate: all ${files.length} check(s) green`);
process.exit(0);
