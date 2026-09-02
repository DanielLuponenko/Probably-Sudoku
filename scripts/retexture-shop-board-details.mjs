// Produces phone-scale-readable 4K PBR variants on the single audited 9x9
// Meshy board geometry. Every request, provider response, model, texture map,
// thumbnail and checksum is preserved beside the outputs.

import { createHash } from 'node:crypto';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import path from 'node:path';

const API_KEY = process.env.MESHY_API_KEY;
if (!API_KEY) throw new Error('MESHY_API_KEY not set');

const OUT = process.argv[2] ?? path.resolve(
  'Artwork/Generated/MeshyShopBoardCollection/DetailR1',
);
const SOURCE_MODEL = process.argv[3] ?? path.resolve(
  'Artwork/Generated/MeshyShopBoardCollection/RetextureSource/empty-grid-300k-uv.glb',
);
const API = 'https://api.meshy.ai/openapi/v1/retexture';
const STATE_PATH = path.join(OUT, '.meshy-state.json');

const PROMPTS = {
  stargazer: [
    'Luxury 1930s private-observatory Sudoku board. Deep midnight-navy vitreous',
    'enamel, crisp aged-brass grid and rim. Large high-contrast engraved celestial',
    'map circles, constellation arcs, star points and a few sunbursts visibly span',
    'selected cells without obscuring the exact grid. Motifs must read clearly at',
    'small product-thumbnail scale. Realistic worn PBR metal and enamel. No text,',
    'letters, numbers, logo, painted lighting, background or extra objects.',
  ].join(' '),
  botanica: [
    'Luxury 1930s botanical-library Sudoku board. Deep bottle-green enamel and',
    'aged-brass grid. Bold clearly visible engraved fern fronds, curling vines,',
    'seed pods and small leaf clusters cross selected cells while the exact grid',
    'stays dominant. Motifs must read at small product-thumbnail scale. Realistic',
    'PBR brass patina, enamel depth and hand-worn edges. No text, letters, numbers,',
    'logo, painted lighting, background or extra objects.',
  ].join(' '),
  scribes: [
    'Luxury archival manuscript Sudoku board. Warm aged ivory vellum, sepia exact',
    'grid, large legible-as-marks but deliberately unreadable calligraphic strokes,',
    'botanical marginal sketches, restrained red wax-pencil circles, underlines and',
    'proofreader marks clearly visible at small product-thumbnail scale. Dark walnut',
    'and aged-brass edge treatment, realistic PBR paper fibers and patina. No readable',
    'words, letters, digits, logo, painted lighting, background or extra objects.',
  ].join(' '),
  midnight: [
    'Luxury midnight edition Sudoku board distinct from a blue constellation board.',
    'Near-black obsidian lacquer with cool silver and pale-brass exact grid, bold moon',
    'phase discs, eclipse rings and sparse silver comet engravings visibly occupying',
    'selected cells. High contrast at small product-thumbnail scale, realistic PBR',
    'black lacquer, silver inlay and restrained wear. No text, letters, numbers, logo,',
    'painted lighting, background or extra objects.',
  ].join(' '),
  golden: [
    'Luxury Golden Grid Sudoku board. Deep oxblood-burgundy leather enamel with an',
    'aged-gold exact grid, bold embossed sunbursts, small heraldic rosettes and fine',
    'gold filigree visibly decorating selected cells. High contrast and readable at',
    'small product-thumbnail scale, realistic PBR leather grain, brass patina and',
    'hand-worn edges. No text, letters, numbers, logo, painted lighting, background',
    'or extra objects.',
  ].join(' '),
  neon: [
    'Luxury malachite Art Deco Sudoku board, not science fiction. Rich emerald and',
    'malachite stone enamel, aged-brass exact grid, bold turquoise-green geometric',
    'fan inlays, stepped corner motifs and diagonal Deco arcs clearly visible across',
    'selected cells at small product-thumbnail scale. Realistic PBR stone, enamel and',
    'brass. No glow, text, letters, numbers, logo, painted lighting, background or',
    'extra objects.',
  ].join(' '),
};

const wait = (milliseconds) => new Promise((resolve) => setTimeout(resolve, milliseconds));
const digest = (bytes) => createHash('sha256').update(bytes).digest('hex');

async function fetchWithRetry(url, options = {}) {
  let lastError;
  for (let attempt = 0; attempt < 8; attempt += 1) {
    try {
      const response = await fetch(url, {
        ...options,
        signal: AbortSignal.timeout(120_000),
      });
      if (response.status !== 429 && response.status < 500) return response;
      lastError = new Error(`temporary HTTP ${response.status}`);
    } catch (error) {
      lastError = error;
    }
    await wait(Math.min(2_000 * (attempt + 1), 12_000));
  }
  throw lastError;
}

async function requestJSON(url, options = {}) {
  const response = await fetchWithRetry(url, options);
  const body = await response.json();
  if (!response.ok) throw new Error(`${response.status} ${JSON.stringify(body)}`);
  return body;
}

async function loadState() {
  try {
    return JSON.parse(await readFile(STATE_PATH, 'utf8'));
  } catch {
    return { tasks: {} };
  }
}

async function saveState(state) {
  await writeFile(STATE_PATH, `${JSON.stringify(state, null, 2)}\n`);
}

async function createTask(name, modelBytes) {
  const request = {
    model_url: `data:application/octet-stream;base64,${modelBytes.toString('base64')}`,
    text_style_prompt: PROMPTS[name],
    ai_model: 'meshy-7',
    enable_original_uv: true,
    enable_pbr: true,
    texture_resolution: '4k',
    target_formats: ['glb', 'usdz'],
    alpha_thumbnail: true,
  };
  await writeFile(path.join(OUT, `${name}-request.json`), `${JSON.stringify({
    ...request,
    model_url: 'data:application/octet-stream;base64,<preserved source model>',
    sourceModel: SOURCE_MODEL,
    sourceSHA256: digest(modelBytes),
  }, null, 2)}\n`);
  const response = await requestJSON(API, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(request),
  });
  return response.result;
}

async function awaitTask(id, name) {
  for (let attempt = 0; attempt < 180; attempt += 1) {
    const task = await requestJSON(`${API}/${id}`, {
      headers: { Authorization: `Bearer ${API_KEY}` },
    });
    if (task.status === 'SUCCEEDED') return task;
    if (task.status === 'FAILED' || task.status === 'CANCELED') {
      throw new Error(`${name} ${task.status}: ${JSON.stringify(task.task_error ?? {})}`);
    }
    if (attempt % 8 === 0) console.log(`${name}: ${task.progress ?? 0}%`);
    await wait(4_000);
  }
  throw new Error(`${name} timed out`);
}

async function download(url, destination) {
  const response = await fetchWithRetry(url);
  if (!response.ok) throw new Error(`download ${response.status}: ${destination}`);
  const bytes = Buffer.from(await response.arrayBuffer());
  await writeFile(destination, bytes);
  return {
    filename: path.basename(destination),
    bytes: bytes.byteLength,
    sha256: digest(bytes),
  };
}

await mkdir(OUT, { recursive: true });
const modelBytes = await readFile(SOURCE_MODEL);
const state = await loadState();
state.tasks ??= {};

for (const name of Object.keys(PROMPTS)) {
  if (!state.tasks[name]) {
    state.tasks[name] = await createTask(name, modelBytes);
    await saveState(state);
    console.log(`${name}: Meshy task ${state.tasks[name]}`);
  }
}

const tasks = Object.fromEntries(await Promise.all(
  Object.keys(PROMPTS).map(async (name) => {
    const task = await awaitTask(state.tasks[name], name);
    await writeFile(path.join(OUT, `${name}-response.json`), `${JSON.stringify(task, null, 2)}\n`);
    return [name, task];
  }),
));

const manifest = {
  provider: 'Meshy',
  model: 'meshy-7-retexture-4k-pbr',
  sourceModel: SOURCE_MODEL,
  sourceSHA256: digest(modelBytes),
  sourceUVPolicy: 'preserve-original',
  assets: {},
};

for (const name of Object.keys(PROMPTS)) {
  const task = tasks[name];
  const outputs = {};
  for (const format of ['glb', 'usdz']) {
    const url = task.model_urls?.[format];
    if (!url) throw new Error(`${name}: missing ${format}`);
    outputs[format] = await download(url, path.join(OUT, `${name}.${format}`));
  }
  const thumbnailURL = task.alpha_thumbnail_url ?? task.thumbnail_url;
  outputs.thumbnail = await download(thumbnailURL, path.join(OUT, `${name}.png`));
  for (const [mapName, url] of Object.entries(task.texture_urls?.[0] ?? {})) {
    const suffix = mapName.replaceAll('_', '-');
    outputs[mapName] = await download(url, path.join(OUT, `${name}-${suffix}.png`));
  }
  manifest.assets[name] = {
    retextureTaskID: state.tasks[name],
    textStylePrompt: PROMPTS[name],
    outputs,
  };
  console.log(`${name}: preserved models, thumbnail, PBR maps and checksums`);
}

await writeFile(path.join(OUT, 'manifest.json'), `${JSON.stringify(manifest, null, 2)}\n`);
console.log(`wrote ${OUT}`);
