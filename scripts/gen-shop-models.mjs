// Generates the authored 3D display fixture used by the Club Shop.
//
//   node scripts/gen-shop-models.mjs [output-directory]
//
// Requires MESHY_API_KEY. The pipeline uses Meshy 7 Ultra for geometry and
// Meshy 7 PBR refinement, while capping geometry for an iPhone runtime asset.

import { mkdir, readFile, writeFile } from 'node:fs/promises';
import path from 'node:path';

const API_KEY = process.env.MESHY_API_KEY;
if (!API_KEY) {
  console.error('MESHY_API_KEY not set');
  process.exit(1);
}

const OUT = process.argv[2] ?? '/tmp/numberclub-meshy-club-turntable';
const BASE = 'https://api.meshy.ai/openapi/v2/text-to-3d';
const STATE_PATH = path.join(OUT, '.meshy-state.json');

const MODELS = {
  club_turntable: {
    prompt: [
      'Single isolated compact 1930s British museum display turntable for tiny',
      'bookbinder samples. A low circular platter on a softly beveled octagonal',
      'base, one concentric registration ring, four tiny index ticks, and a',
      'subtle hidden motor housing. Completely empty, unobstructed flat top.',
      'Symmetrical, stable, premium small-object proportions, clean watertight',
      'geometry and crisp bevels. No sample object, no text, no letters, no logo,',
      'no ground plane, no room, no extra objects.',
    ].join(' '),
    texture: [
      'Deep bottle-green enamel platter, warm dark walnut beveled base, restrained',
      'aged-brass registration ring and index ticks, subtle hand-worn edges and',
      'fine physically based material response. Quiet 1930s British clubroom',
      'object, premium rather than ornate. Blank top, no text or logos.',
    ].join(' '),
  },
};

const wait = (milliseconds) => new Promise((resolve) => setTimeout(resolve, milliseconds));

async function fetchWithRetry(url, options = {}) {
  let lastError;
  for (let attempt = 0; attempt < 8; attempt += 1) {
    try {
      const response = await fetch(url, {
        ...options,
        signal: AbortSignal.timeout(60_000),
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

async function createPreview(prompt) {
  const body = await requestJSON(BASE, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      mode: 'preview',
      prompt,
      model_type: 'standard',
      ai_model: 'meshy-7',
      ultra_mode: true,
      should_remesh: true,
      topology: 'triangle',
      target_polycount: 12_000,
      target_formats: ['usdz'],
      alpha_thumbnail: true,
      moderation: true,
    }),
  });
  return body.result;
}

async function createRefine(previewID, texturePrompt) {
  const body = await requestJSON(BASE, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      mode: 'refine',
      preview_task_id: previewID,
      ai_model: 'meshy-7',
      enable_pbr: true,
      texture_resolution: '4k',
      texture_prompt: texturePrompt,
      target_formats: ['usdz'],
      alpha_thumbnail: true,
      moderation: true,
    }),
  });
  return body.result;
}

async function awaitTask(id, label) {
  for (let attempt = 0; attempt < 180; attempt += 1) {
    const task = await requestJSON(`${BASE}/${id}`, {
      headers: { Authorization: `Bearer ${API_KEY}` },
    });
    if (task.status === 'SUCCEEDED') return task;
    if (task.status === 'FAILED' || task.status === 'CANCELED') {
      throw new Error(`${label} ${task.status}: ${JSON.stringify(task.task_error ?? {})}`);
    }
    if (attempt % 8 === 0) console.log(`${label}: ${task.progress ?? 0}%`);
    await wait(4_000);
  }
  throw new Error(`${label} timed out`);
}

async function download(url, destination) {
  const response = await fetchWithRetry(url);
  if (!response.ok) throw new Error(`download ${response.status}: ${destination}`);
  await writeFile(destination, Buffer.from(await response.arrayBuffer()));
}

async function loadState() {
  try {
    return JSON.parse(await readFile(STATE_PATH, 'utf8'));
  } catch {
    return {};
  }
}

async function saveState(state) {
  await writeFile(STATE_PATH, `${JSON.stringify(state, null, 2)}\n`);
}

await mkdir(OUT, { recursive: true });
const state = await loadState();

for (const [name, specification] of Object.entries(MODELS)) {
  state[name] ??= {};
  if (!state[name].previewID) {
    state[name].previewID = await createPreview(specification.prompt);
    await saveState(state);
    console.log(`${name}: Ultra preview task ${state[name].previewID}`);
  }
}

const previews = Object.fromEntries(await Promise.all(
  Object.entries(MODELS).map(async ([name]) => [
    name,
    await awaitTask(state[name].previewID, `${name} preview`),
  ]),
));

for (const [name, specification] of Object.entries(MODELS)) {
  if (!state[name].refineID) {
    state[name].refineID = await createRefine(state[name].previewID, specification.texture);
    await saveState(state);
    console.log(`${name}: PBR refine task ${state[name].refineID}`);
  }
}

const refined = Object.fromEntries(await Promise.all(
  Object.entries(MODELS).map(async ([name]) => [
    name,
    await awaitTask(state[name].refineID, `${name} refine`),
  ]),
));

const manifest = {};
for (const [name, specification] of Object.entries(MODELS)) {
  const task = refined[name];
  const modelURL = task.model_urls?.usdz;
  const thumbnailURL = task.alpha_thumbnail_url ?? task.thumbnail_url;
  if (!modelURL || !thumbnailURL) throw new Error(`${name}: missing output URL`);
  await Promise.all([
    download(modelURL, path.join(OUT, `${name}.usdz`)),
    download(thumbnailURL, path.join(OUT, `${name}.png`)),
  ]);
  manifest[name] = {
    previewID: state[name].previewID,
    refineID: state[name].refineID,
    geometryPrompt: specification.prompt,
    texturePrompt: specification.texture,
    previewCredits: previews[name].consumed_credits,
    refineCredits: task.consumed_credits,
  };
  console.log(`${name}: wrote Ultra USDZ and thumbnail`);
}

await writeFile(path.join(OUT, 'manifest.json'), `${JSON.stringify(manifest, null, 2)}\n`);
console.log(`wrote ${OUT}`);
