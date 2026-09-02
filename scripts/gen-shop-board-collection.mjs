// Generates one consistent Meshy board geometry and four unique 4K PBR skins.
//
//   node scripts/gen-shop-board-collection.mjs [output-directory]
//
// Requires MESHY_API_KEY. All requests, responses, source outputs and checksums
// are preserved so every runtime asset keeps direct provider lineage.

import { createHash } from 'node:crypto';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import path from 'node:path';

const API_KEY = process.env.MESHY_API_KEY;
if (!API_KEY) {
  console.error('MESHY_API_KEY not set');
  process.exit(1);
}

const OUT = process.argv[2] ?? '/tmp/numberclub-meshy-board-collection';
const SOURCE_MODEL = process.argv[3] ?? path.resolve(
  'Artwork/Generated/MeshyShopBoards/Meshy_AI_Midnight_Grid_0830061844_generate.glb',
);
const STYLE_REFERENCE_DIRECTORY = process.argv[4] ?? path.resolve(
  'Artwork/Generated/MeshyShopBoardCollection/StyleReferences',
);
const REMESH = 'https://api.meshy.ai/openapi/v1/remesh';
const RETEXTURE = 'https://api.meshy.ai/openapi/v1/retexture';
const STATE_PATH = path.join(OUT, '.meshy-state.json');

const SKINS = {
  stargazer: [
    'Deep midnight-navy enamel board with a complete fine aged-brass 9 by 9 grid,',
    'stronger brass 3 by 3 divisions, aged-brass frame and corner fasteners.',
    'Restrained hairline celestial constellation engravings and tiny warm star points',
    'between grid lines. Satin lacquer, subtle hand wear, premium 1930s observatory-',
    'library PBR materials. No digits, readable text, logo, glow, shadows or lighting.',
  ].join(' '),
  botanica: [
    'Deep bottle-green enamel board with a complete fine aged-brass 9 by 9 grid,',
    'stronger brass 3 by 3 divisions, aged-brass frame and corner fasteners.',
    'Restrained engraved fern leaves, seed pods and curling botanical vines confined',
    'inside selected empty cells without hiding the grid. Satin lacquer, subtle hand',
    'wear, premium private-library PBR materials. No digits, text, logo or lighting.',
  ].join(' '),
  scribes: [
    'Warm aged ivory vellum board with a complete precise sepia and aged-brass 9 by 9',
    'grid, stronger 3 by 3 divisions, narrow dark-walnut frame and brass fasteners.',
    'Faint illegible brown manuscript notes, botanical marginal sketches and several',
    'restrained red proofreader circles across the vellum. Archival realistic PBR',
    'materials. No readable words, digits, logo, glow, shadows or painted lighting.',
  ].join(' '),
  porcelain: [
    'Warm ivory porcelain-enamel board with a complete fine cobalt-blue and aged-brass',
    '9 by 9 grid, stronger 3 by 3 divisions, thin cobalt keyline, aged-brass frame',
    'and corner fasteners. Sparse hand-painted cobalt flourishes only in the outer',
    'corners, subtle ceramic depth and restrained period patina, premium realistic',
    'PBR materials. No digits, readable text, logo, glow or painted lighting.',
  ].join(' '),
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

async function createGeometry() {
  const sourceBytes = await readFile(SOURCE_MODEL);
  const sourceSHA256 = createHash('sha256').update(sourceBytes).digest('hex');
  const request = {
    model_url: `data:application/octet-stream;base64,${sourceBytes.toString('base64')}`,
    topology: 'triangle',
    target_polycount: 300_000,
    target_formats: ['glb', 'usdz'],
    alpha_thumbnail: true,
  };
  await writeFile(path.join(OUT, 'board-base-source.json'), `${JSON.stringify({
    sourceModel: SOURCE_MODEL,
    bytes: sourceBytes.byteLength,
    sha256: sourceSHA256,
    request: { ...request, model_url: 'data:application/octet-stream;base64,<preserved source file>' },
  }, null, 2)}\n`);
  const response = await requestJSON(REMESH, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(request),
  });
  return response.result;
}

async function createRetexture(name, inputTaskID, prompt) {
  const styleReferencePath = path.join(STYLE_REFERENCE_DIRECTORY, `${name}.png`);
  const styleReference = await readFile(styleReferencePath);
  const styleReferenceSHA256 = createHash('sha256').update(styleReference).digest('hex');
  const request = {
    input_task_id: inputTaskID,
    image_style_url: `data:image/png;base64,${styleReference.toString('base64')}`,
    ai_model: 'meshy-7',
    // The source is a geometry-only GLB, so it has no texture UVs worth keeping.
    // A fresh Meshy unwrap is required for the image reference to map as detail
    // instead of collapsing to its average surface color.
    enable_original_uv: false,
    enable_pbr: true,
    texture_resolution: '4k',
    target_formats: ['glb', 'usdz'],
    alpha_thumbnail: true,
  };
  await writeFile(path.join(OUT, `${name}-request.json`), `${JSON.stringify({
    ...request,
    image_style_url: 'data:image/png;base64,<preserved style reference>',
    styleReferencePath,
    styleReferenceSHA256,
    intendedStylePrompt: prompt,
  }, null, 2)}\n`);
  const response = await requestJSON(RETEXTURE, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(request),
  });
  return response.result;
}

async function awaitTask(baseURL, id, label) {
  for (let attempt = 0; attempt < 180; attempt += 1) {
    const task = await requestJSON(`${baseURL}/${id}`, {
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
  const data = Buffer.from(await response.arrayBuffer());
  await writeFile(destination, data);
  return createHash('sha256').update(data).digest('hex');
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

if (!state.geometryID && process.env.MESHY_BASE_TASK_ID) {
  state.geometryID = process.env.MESHY_BASE_TASK_ID;
  await saveState(state);
  console.log(`reusing clean Meshy remesh task ${state.geometryID}`);
}

if (!state.geometryID) {
  state.geometryID = await createGeometry();
  await saveState(state);
  console.log(`board base: Meshy 7 Ultra task ${state.geometryID}`);
}

const geometry = await awaitTask(REMESH, state.geometryID, 'board base');
await writeFile(path.join(OUT, 'board-base-response.json'), `${JSON.stringify(geometry, null, 2)}\n`);

state.retextures ??= {};
for (const [name, prompt] of Object.entries(SKINS)) {
  if (!state.retextures[name]) {
    state.retextures[name] = await createRetexture(name, state.geometryID, prompt);
    await saveState(state);
    console.log(`${name}: Meshy 7 4K PBR retexture task ${state.retextures[name]}`);
  }
}

const tasks = Object.fromEntries(await Promise.all(
  Object.entries(state.retextures).map(async ([name, id]) => {
    const task = await awaitTask(RETEXTURE, id, name);
    await writeFile(path.join(OUT, `${name}-response.json`), `${JSON.stringify(task, null, 2)}\n`);
    return [name, task];
  }),
));

const manifest = {
  provider: 'Meshy',
  geometryModel: 'Meshy Remesh 300k triangle',
  textureModel: 'meshy-7-retexture-4k-pbr',
  geometryTaskID: state.geometryID,
  sourceModel: SOURCE_MODEL,
  sourceSHA256: createHash('sha256').update(await readFile(SOURCE_MODEL)).digest('hex'),
  assets: {},
};

for (const [name, task] of Object.entries(tasks)) {
  const styleReferencePath = path.join(STYLE_REFERENCE_DIRECTORY, `${name}.png`);
  const styleReference = await readFile(styleReferencePath);
  const outputs = {};
  for (const format of ['glb', 'usdz']) {
    const url = task.model_urls?.[format];
    if (!url) continue;
    const filename = `${name}.${format}`;
    outputs[format] = {
      filename,
      sha256: await download(url, path.join(OUT, filename)),
    };
  }
  const thumbnailURL = task.alpha_thumbnail_url ?? task.thumbnail_url;
  if (!thumbnailURL) throw new Error(`${name}: missing thumbnail URL`);
  outputs.thumbnail = {
    filename: `${name}.png`,
    sha256: await download(thumbnailURL, path.join(OUT, `${name}.png`)),
  };
  manifest.assets[name] = {
    retextureTaskID: state.retextures[name],
    texturePrompt: SKINS[name],
    styleReference: {
      path: styleReferencePath,
      sha256: createHash('sha256').update(styleReference).digest('hex'),
    },
    outputs,
  };
  console.log(`${name}: preserved GLB/USDZ/thumbnail`);
}

await writeFile(path.join(OUT, 'manifest.json'), `${JSON.stringify(manifest, null, 2)}\n`);
console.log(`wrote ${OUT}`);
