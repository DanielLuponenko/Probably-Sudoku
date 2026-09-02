// Generates the shared high-detail physical board body used by every Club Shop
// skin. The front reference establishes real frame, grid-rail and fastener
// geometry; later Meshy retexture tasks preserve this one physical silhouette.
//
//   node scripts/gen-shop-board-hardware-base.mjs [output-directory] [reference-image]
//
// Requires MESHY_API_KEY. Requests, provider responses, maps, checksums and
// source references are preserved for auditable production lineage.

import { createHash } from 'node:crypto';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import path from 'node:path';

const API_KEY = process.env.MESHY_API_KEY;
if (!API_KEY) throw new Error('MESHY_API_KEY not set');

const OUT = process.argv[2] ?? path.resolve(
  'Artwork/Generated/MeshyShopBoardCollection/HardwareBaseV1',
);
const REFERENCE = process.argv[3] ?? path.resolve(
  'Artwork/Generated/MeshyShopBoardCollection/StyleReferencesR4/classic.png',
);
const API = 'https://api.meshy.ai/openapi/v1/image-to-3d';
const STATE_PATH = path.join(OUT, '.meshy-state.json');

const wait = (milliseconds) => new Promise((resolve) => setTimeout(resolve, milliseconds));
const sha256 = (bytes) => createHash('sha256').update(bytes).digest('hex');

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

async function download(url, destination) {
  const response = await fetchWithRetry(url);
  if (!response.ok) throw new Error(`download ${response.status}: ${destination}`);
  const bytes = Buffer.from(await response.arrayBuffer());
  await writeFile(destination, bytes);
  return { bytes: bytes.byteLength, sha256: sha256(bytes) };
}

async function readState() {
  try {
    return JSON.parse(await readFile(STATE_PATH, 'utf8'));
  } catch {
    return {};
  }
}

async function writeState(state) {
  await writeFile(STATE_PATH, `${JSON.stringify(state, null, 2)}\n`);
}

await mkdir(OUT, { recursive: true });
const referenceBytes = await readFile(REFERENCE);
const state = await readState();

const request = {
  image_url: `data:image/png;base64,${referenceBytes.toString('base64')}`,
  model_type: 'standard',
  ai_model: 'meshy-7',
  ultra_mode: true,
  should_texture: true,
  enable_pbr: true,
  texture_resolution: '4k',
  image_enhancement: false,
  should_remesh: true,
  save_pre_remeshed_model: true,
  topology: 'triangle',
  target_polycount: 150_000,
  target_formats: ['glb', 'usdz'],
  alpha_thumbnail: true,
  multi_view_thumbnails: true,
  moderation: true,
};

await writeFile(path.join(OUT, 'request.json'), `${JSON.stringify({
  ...request,
  image_url: 'data:image/png;base64,<preserved reference image>',
  referencePath: REFERENCE,
  referenceSHA256: sha256(referenceBytes),
  intent: 'One square Sudoku board body with raised 9x9 grid rails, stronger 3x3 rails, a narrow frame and physical corner fasteners.',
}, null, 2)}\n`);

if (!state.taskID) {
  const created = await requestJSON(API, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(request),
  });
  state.taskID = created.result;
  await writeState(state);
  console.log(`hardware base task ${state.taskID}`);
}

let task;
for (let attempt = 0; attempt < 240; attempt += 1) {
  task = await requestJSON(`${API}/${state.taskID}`, {
    headers: { Authorization: `Bearer ${API_KEY}` },
  });
  if (task.status === 'SUCCEEDED') break;
  if (task.status === 'FAILED' || task.status === 'CANCELED') {
    throw new Error(`${task.status}: ${JSON.stringify(task.task_error ?? {})}`);
  }
  if (attempt % 8 === 0) console.log(`hardware base: ${task.progress ?? 0}%`);
  await wait(5_000);
}
if (!task || task.status !== 'SUCCEEDED') throw new Error('hardware base timed out');

await writeFile(path.join(OUT, 'response.json'), `${JSON.stringify(task, null, 2)}\n`);
const outputs = {};
for (const format of ['glb', 'usdz']) {
  const url = task.model_urls?.[format];
  if (url) outputs[format] = await download(url, path.join(OUT, `board-base.${format}`));
}
const thumbnailURL = task.alpha_thumbnail_url ?? task.thumbnail_url;
if (thumbnailURL) outputs.thumbnail = await download(
  thumbnailURL,
  path.join(OUT, 'board-base.png'),
);
const textureSet = task.texture_urls?.[0] ?? {};
for (const [name, url] of Object.entries(textureSet)) {
  if (!url) continue;
  outputs[name] = await download(url, path.join(OUT, `board-base-${name.replaceAll('_', '-')}.png`));
}

const manifest = {
  provider: 'Meshy',
  model: 'meshy-7-image-to-3d-ultra-4k-pbr',
  taskID: state.taskID,
  consumedCredits: task.consumed_credits,
  reference: {
    path: REFERENCE,
    sha256: sha256(referenceBytes),
  },
  outputs,
};
await writeFile(path.join(OUT, 'manifest.json'), `${JSON.stringify(manifest, null, 2)}\n`);
console.log(`wrote ${OUT}`);
