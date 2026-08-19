// Generates the shelf's background: the desk itself, empty, in phone format.
//
// The Book is drawn on top of this, so the desk must have nothing on it — a
// generated book here would sit under the real one and read as two books.
//
//   node scripts/gen-desk.mjs [out.png] [model] [aspect]

import { writeFile } from 'node:fs/promises';

const API_KEY = process.env.MESHY_API_KEY;
if (!API_KEY) { console.error('MESHY_API_KEY not set'); process.exit(1); }

const OUT = process.argv[2] ?? 'App/Assets.xcassets/Desk.imageset/desk.png';
const MODEL = process.argv[3] ?? 'gpt-image-2';
const ASPECT = process.argv[4] ?? '9:16';
const BASE = 'https://api.meshy.ai/openapi/v1/text-to-image';

const PROMPT = [
  'A tall vertical photograph looking straight down at an empty dark polished',
  'walnut desk at night. The desk surface fills the entire frame, its grain',
  'running from top to bottom. A warm tungsten desk lamp is out of shot to the',
  'upper left, so light falls brightly across the top-left corner and the wood',
  'darkens gradually towards the bottom right, ending almost black at the',
  'bottom edge. Scattered near the very edges of the frame, small and far apart:',
  'a green pencil, a worn white eraser, and a pale ceramic coffee cup, all',
  'partly cropped by the frame. The wide middle of the desk is completely bare.',
  'Muted, warm, desaturated: walnut browns, deep shadow. Fine photographic',
  'grain, shallow depth of field. No book, no paper, no notebook, no text,',
  'no lettering, no logos, no people, no hands.',
].join(' ');

async function post() {
  const res = await fetch(BASE, {
    method: 'POST',
    headers: { Authorization: `Bearer ${API_KEY}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ ai_model: MODEL, prompt: PROMPT, aspect_ratio: ASPECT }),
  });
  const body = await res.json();
  if (!res.ok) throw new Error(`${res.status} ${JSON.stringify(body)}`);
  return body.result ?? body.id ?? body;
}

async function poll(id) {
  for (let attempt = 0; attempt < 120; attempt++) {
    const res = await fetch(`${BASE}/${id}`, { headers: { Authorization: `Bearer ${API_KEY}` } });
    const task = await res.json();
    if (task.status === 'SUCCEEDED') return task;
    if (task.status === 'FAILED' || task.status === 'CANCELED') {
      throw new Error(`task ${task.status}: ${JSON.stringify(task.task_error ?? {})}`);
    }
    await new Promise((r) => setTimeout(r, 2000));
  }
  throw new Error('timed out');
}

const id = await post();
console.log('task', id, 'aspect', ASPECT);
const task = await poll(id);
const url = task.image_url ?? task.output?.image_url ??
  (Array.isArray(task.image_urls) ? task.image_urls[0] : undefined) ?? task.result;
if (!url) throw new Error(`no image url: ${JSON.stringify(task).slice(0, 300)}`);
const image = await fetch(url);
await writeFile(OUT, Buffer.from(await image.arrayBuffer()));
console.log('wrote', OUT);
