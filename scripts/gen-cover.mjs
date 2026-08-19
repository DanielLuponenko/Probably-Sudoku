// Generates the cover photograph: the sudoku book shut on the desk.
//
// Meshy's public API has no video endpoint — image-to-video and text-to-video
// both 404 with NoMatchingRoute, though the feature exists in their web app.
// So the cover is a still, and the movement is done in the app: a slow drift
// and a lamp that breathes. That also keeps the asset around a megabyte
// instead of ten, and never stutters.
//
//   node scripts/gen-cover.mjs [out.png] [model] [aspect]
//
// Requires MESHY_API_KEY. gpt-image-2 costs 12 credits and is worth it here:
// the whole point is that the wood and the paper stock read as real.

import { writeFile } from 'node:fs/promises';

const API_KEY = process.env.MESHY_API_KEY;
if (!API_KEY) {
  console.error('MESHY_API_KEY not set. Try: export $(grep -v ^# ~/sudoku_plus/.env.local | xargs)');
  process.exit(1);
}

const OUT = process.argv[2] ?? 'App/Resources/cover.png';
const MODEL = process.argv[3] ?? 'gpt-image-2';
const ASPECT = process.argv[4] ?? '2:3';
const BASE = 'https://api.meshy.ai/openapi/v1/text-to-image';

// No lettering anywhere: generated type is always gibberish, and this book's
// title is set in the app over the top of the photograph.
const PROMPT = [
  'A photograph, shot from almost directly above, of a thick closed puzzle book',
  'lying on a dark polished walnut desk. The book has plain dark charcoal cloth',
  'boards with no lettering, no title, no writing and no markings of any kind,',
  'and a visible block of cream coloured paper edges along its fore-edge and',
  'foot, the individual leaves countable. Warm tungsten light rakes across from',
  'the upper left, so the book casts a long soft shadow down and to the right,',
  'and the wood grain catches the light. Muted, warm, desaturated palette:',
  'walnut browns, charcoal, cream paper. Quiet and still, like a desk at night.',
  'Shallow depth of field, fine grain, no people, no hands, no other objects,',
  'no text, no logos, no watermarks.',
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
  for (let attempt = 0; attempt < 90; attempt++) {
    const res = await fetch(`${BASE}/${id}`, { headers: { Authorization: `Bearer ${API_KEY}` } });
    const task = await res.json();
    if (task.status === 'SUCCEEDED') return task;
    if (task.status === 'FAILED' || task.status === 'CANCELED') {
      throw new Error(`task ${task.status}: ${JSON.stringify(task.task_error ?? {})}`);
    }
    process.stdout.write(`\r${task.status ?? '...'} ${task.progress ?? 0}%   `);
    await new Promise((r) => setTimeout(r, 2000));
  }
  throw new Error('timed out');
}

const id = await post();
console.log('task', id);
const task = await poll(id);
console.log('');

const url =
  task.image_url ??
  task.output?.image_url ??
  (Array.isArray(task.image_urls) ? task.image_urls[0] : undefined) ??
  task.result;
if (!url) throw new Error(`no image url in result: ${JSON.stringify(task).slice(0, 400)}`);

const image = await fetch(url);
await writeFile(OUT, Buffer.from(await image.arrayBuffer()));
console.log('wrote', OUT);
