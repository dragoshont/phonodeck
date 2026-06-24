#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${1:-$ROOT_DIR/.architrave/screenshots/phase7}"
CDP_DIR="${PHONODECK_CDP_DIR:-$HOME/.phonodeck-cdp}"
EDGE_BIN="/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge"

mkdir -p "$OUT_DIR"

if [[ ! -d "$ROOT_DIR/ui-lab/storybook-static" ]]; then
  echo "SCREENSHOT: Storybook static build missing. Run: cd ui-lab && npm run build-storybook" >&2
  exit 2
fi

if ! command -v screencapture >/dev/null 2>&1; then
  echo "SCREENSHOT: macOS screencapture command not available" >&2
  exit 2
fi

if [[ ! -d "$CDP_DIR/node_modules/playwright-core" ]]; then
  echo "SCREENSHOT: playwright-core missing. Expected local harness at $CDP_DIR" >&2
  exit 2
fi

if [[ ! -x "$EDGE_BIN" ]]; then
  echo "SCREENSHOT: Microsoft Edge missing at $EDGE_BIN" >&2
  exit 2
fi

index_file="$OUT_DIR/README.md"
cat > "$index_file" <<'MARKDOWN'
# Phase 7 Screenshot Evidence

This directory is created by `scripts/screenshot.sh`.

The script verifies that the Storybook static build exists and captures representative Storybook golden stories with Playwright Core and Microsoft Edge.

Required target matrix is tracked in `docs/qa/phase7-ux-accessibility-performance-checklist.md`.
MARKDOWN

capture_script="$OUT_DIR/capture-storybook.cjs"
cat > "$capture_script" <<'NODE'
const fs = require('fs');
const http = require('http');
const path = require('path');

const root = process.env.PHONODECK_ROOT;
const out = process.env.PHONODECK_SCREENSHOT_OUT;
const cdpDir = process.env.PHONODECK_CDP_DIR;
const edgeBin = process.env.PHONODECK_EDGE_BIN;
const { chromium } = require(path.join(cdpDir, 'node_modules', 'playwright-core'));
const staticDir = path.join(root, 'ui-lab', 'storybook-static');

const stories = [
  ['screens--home', 'screens-home'],
  ['screens--library', 'screens-library'],
  ['screens--search', 'screens-search'],
  ['screens--settings', 'screens-settings'],
  ['now-playing-panel--no-selection', 'nowplaying-no-selection'],
  ['now-playing-panel--you-tube-visible-iframe-direct', 'nowplaying-youtube-iframe'],
  ['phase-5-readiness-states--albums-limited-derived', 'phase5-albums-limited'],
  ['phase-5-readiness-states--artists-limited-derived', 'phase5-artists-limited'],
  ['phase-6-operational-surfaces--storage-populated', 'phase6-storage-populated'],
  ['phase-6-operational-surfaces--devices-native-route', 'phase6-devices-native'],
  ['phase-6-operational-surfaces--provider-lab-both-success', 'phase6-providerlab-success'],
  ['phase-6-operational-surfaces--provider-lab-both-failed', 'phase6-providerlab-failed']
];

const viewports = [
  ['min', { width: 940, height: 640 }],
  ['standard', { width: 1200, height: 760 }],
  ['wide', { width: 1400, height: 900 }]
];

(async () => {
  const server = http.createServer((req, res) => {
    const requestUrl = new URL(req.url, 'http://127.0.0.1');
    const rawPath = decodeURIComponent(requestUrl.pathname === '/' ? '/index.html' : requestUrl.pathname);
    const filePath = path.normalize(path.join(staticDir, rawPath));
    if (!filePath.startsWith(staticDir)) {
      res.writeHead(403);
      res.end('Forbidden');
      return;
    }
    fs.readFile(filePath, (error, data) => {
      if (error) {
        res.writeHead(404);
        res.end('Not found');
        return;
      }
      const ext = path.extname(filePath);
      const type = ext === '.html' ? 'text/html' : ext === '.js' ? 'text/javascript' : ext === '.css' ? 'text/css' : ext === '.svg' ? 'image/svg+xml' : ext === '.json' ? 'application/json' : 'application/octet-stream';
      res.writeHead(200, { 'Content-Type': type });
      res.end(data);
    });
  });
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const { port } = server.address();
  const browser = await chromium.launch({ executablePath: edgeBin, headless: true });
  const base = `http://127.0.0.1:${port}/iframe.html`;
  const results = [];
  try {
    for (const [storyId, slug] of stories) {
      for (const [viewportName, viewport] of viewports) {
        const page = await browser.newPage({ viewport });
        const url = `${base}?id=${encodeURIComponent(storyId)}&viewMode=story`;
        await page.goto(url, { waitUntil: 'networkidle' });
        await page.waitForSelector('.pd', { timeout: 15000 });
        await page.waitForFunction(() => {
          const root = document.querySelector('.pd');
          const rendered = document.querySelector('.pd .window, .pd .npp, .pd .ops-page, .pd .limited-empty, .pd .empty, .pd .panel, .pd .ready-callout, .pd .card, .pd .srcchips');
          return root && rendered && root.innerText.trim().length > 30;
        }, { timeout: 15000 });
        const file = `${slug}-${viewportName}.png`;
        const outputPath = path.join(out, file);
        await page.screenshot({ path: outputPath, fullPage: true });
        const stats = fs.statSync(outputPath);
        if (stats.size < 10000) {
          throw new Error(`Screenshot appears blank or incomplete: ${file} (${stats.size} bytes)`);
        }
        results.push({ storyId, viewport: viewportName, file, bytes: stats.size });
        await page.close();
      }
    }
  } finally {
    await browser.close();
    await new Promise((resolve) => server.close(resolve));
  }
  fs.writeFileSync(path.join(out, 'storybook-screenshots.json'), JSON.stringify({ capturedAt: new Date().toISOString(), results }, null, 2));
})().catch((error) => {
  console.error(error);
  process.exit(1);
});
NODE

PHONODECK_ROOT="$ROOT_DIR" \
PHONODECK_SCREENSHOT_OUT="$OUT_DIR" \
PHONODECK_CDP_DIR="$CDP_DIR" \
PHONODECK_EDGE_BIN="$EDGE_BIN" \
node "$capture_script"

rm -f "$capture_script"

cat >> "$index_file" <<'MARKDOWN'

## Captured

- `storybook-screenshots.json` — manifest for captured Storybook stories and viewports.
- `*.png` — representative Storybook screenshots for Phase 5/6 surfaces at minimum, standard, and wide viewports.

## Storybook Static Build

- `ui-lab/storybook-static/index.html`

## Follow-up Manual Targets

See `docs/qa/phase7-ux-accessibility-performance-checklist.md` for the native app and manual accessibility/performance target matrix.
MARKDOWN

echo "SCREENSHOT: wrote $OUT_DIR"