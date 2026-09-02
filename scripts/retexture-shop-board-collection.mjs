// Creates four consistent 4K PBR board editions from one UV-preserving GLB.
// The source GLB and all style images are sent directly to Meshy's Retexture API.

import { createHash } from 'node:crypto';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import path from 'node:path';

const API_KEY = process.env.MESHY_API_KEY;
if (!API_KEY) throw new Error('MESHY_API_KEY not set');

const OUT = process.argv[2] ?? '/tmp/numberclub-meshy-board-retextures';
const SOURCE_MODEL = process.argv[3] ?? path.resolve(
  'Artwork/Generated/MeshyShopBoardCollection/RetextureSource/empty-grid-300k-uv.glb',
);
const STYLE_DIRECTORY = process.argv[4] ?? path.resolve(
  'Artwork/Generated/MeshyShopBoardCollection/StyleReferences',
);
const API = 'https://api.meshy.ai/openapi/v1/retexture';
const STATE_PATH = path.join(OUT, '.meshy-state.json');
const NAMES = (process.argv[5] ?? 'stargazer,botanica,scribes,porcelain')
  .split(',')
  .map((name) => name.trim())
  .filter(Boolean);

const wait = (milliseconds) => new Promise((resolve) => setTimeout(resolve, milliseconds));
const digest = (bytes) => createHash('sha256').update(bytes).digest('hex');

async function fetchWithRetry(url, options = {}) {
  let lastError;
  for (let attempt = 0; attempt < 8; attempt += 1) {
    try {
      const response = await fetch(url, { ...options, signal: AbortSignal.timeout(120_000) });
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

async function createTask(name, modelBytes, styleBytes) {
  const request = {
    model_url: `data:application/octet-stream;base64,${modelBytes.toString('base64')}`,
    image_style_url: `data:image/png;base64,${styleBytes.toString('base64')}`,
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
    image_style_url: 'data:image/png;base64,<preserved style reference>',
    sourceModel: SOURCE_MODEL,
    sourceSHA256: digest(modelBytes),
    styleReference: path.join(STYLE_DIRECTORY, `${name}.png`),
    styleReferenceSHA256: digest(styleBytes),
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
  return { filename: path.basename(destination), bytes: bytes.byteLength, sha256: digest(bytes) };
}

await mkdir(OUT, { recursive: true });
const modelBytes = await readFile(SOURCE_MODEL);
const styleBytes = Object.fromEntries(await Promise.all(NAMES.map(async (name) => [
  name,
  await readFile(path.join(STYLE_DIRECTORY, `${name}.png`)),
])));
const state = await loadState();
state.tasks ??= {};

for (const name of NAMES) {
  if (!state.tasks[name]) {
    state.tasks[name] = await createTask(name, modelBytes, styleBytes[name]);
    await saveState(state);
    console.log(`${name}: direct UV-preserving Meshy task ${state.tasks[name]}`);
  }
}

const tasks = Object.fromEntries(await Promise.all(NAMES.map(async (name) => {
  const task = await awaitTask(state.tasks[name], name);
  await writeFile(path.join(OUT, `${name}-response.json`), `${JSON.stringify(task, null, 2)}\n`);
  return [name, task];
})));

const manifest = {
  provider: 'Meshy',
  model: 'meshy-7-retexture-4k-pbr',
  sourceModel: SOURCE_MODEL,
  sourceSHA256: digest(modelBytes),
  sourceUVPolicy: 'preserve-original',
  assets: {},
};

for (const name of NAMES) {
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
    outputs[mapName] = await download(url, path.join(OUT, `${name}-${mapName.replaceAll('_', '-')}.png`));
  }
  manifest.assets[name] = {
    retextureTaskID: state.tasks[name],
    styleReference: path.join(STYLE_DIRECTORY, `${name}.png`),
    styleReferenceSHA256: digest(styleBytes[name]),
    outputs,
  };
  console.log(`${name}: preserved models, thumbnail, and PBR maps`);
}

await writeFile(path.join(OUT, 'manifest.json'), `${JSON.stringify(manifest, null, 2)}\n`);
console.log(`wrote ${OUT}`);
