// Extends a Book's cover photograph into a phone-format scene.
//
// The cover ships at 2:3 lying on its own wooden board. Compositing it onto a
// separate desk stacks two woods; cutting it out fragments the index tabs,
// which are thin and the same colour family as the desk. Neither is right.
//
// Instead the whole scene is regenerated at 9:16 from the cover as reference:
// one image, one desk, no seam and nothing to mask.
//
//   node scripts/gen-shelf-scene.mjs <in.png> <out.png> [model] [aspect]

import { readFile, writeFile } from 'node:fs/promises';
import path from 'node:path';

const API_KEY = process.env.MESHY_API_KEY;
if (!API_KEY) { console.error('MESHY_API_KEY not set'); process.exit(1); }

const IN = process.argv[2];
const OUT = process.argv[3] ?? 'scene.png';
const MODEL = process.argv[4] ?? 'nano-banana-pro';
const ASPECT = process.argv[5] ?? '9:16';
const BASE = 'https://api.meshy.ai/openapi/v1/image-to-image';

const PROMPT = [
  'Keep this exact book completely unchanged and recognisable: the same cover,',
  'the same title lettering, the same sticky notes, the same coloured index',
  'tabs down its right edge, the same green cloth spine. Do not redraw, reword',
  'or restyle anything printed on it.',
  'Re-frame the photograph as a tall vertical phone-shaped image: the same book',
  'lying flat on the same dark polished walnut desk, seen from directly above,',
  'centred, with much more bare desk visible above and below it than at the',
  'sides. Warm tungsten lamp light from the upper left, the desk falling away',
  'into near-black at the bottom of the frame. The book keeps a soft natural',
  'shadow underneath it. No people, no hands, no other objects, and no extra',
  'text or lettering anywhere.',
].join(' ');

const bytes = await readFile(IN);
const mime = path.extname(IN).toLowerCase() === '.png' ? 'image/png' : 'image/jpeg';
const dataUri = `data:${mime};base64,${bytes.toString('base64')}`;

const res = await fetch(BASE, {
  method: 'POST',
  headers: { Authorization: `Bearer ${API_KEY}`, 'Content-Type': 'application/json' },
  body: JSON.stringify({
    ai_model: MODEL,
    prompt: PROMPT,
    reference_image_urls: [dataUri],
    aspect_ratio: ASPECT,
  }),
});
const body = await res.json();
if (!res.ok) throw new Error(`${res.status} ${JSON.stringify(body)}`);
const id = body.result ?? body.id;
console.log('task', id, MODEL, ASPECT);

let task;
for (let attempt = 0; attempt < 120; attempt++) {
  const poll = await fetch(`${BASE}/${id}`, { headers: { Authorization: `Bearer ${API_KEY}` } });
  task = await poll.json();
  if (task.status === 'SUCCEEDED') break;
  if (task.status === 'FAILED' || task.status === 'CANCELED') {
    throw new Error(`task ${task.status}: ${JSON.stringify(task.task_error ?? {})}`);
  }
  await new Promise((r) => setTimeout(r, 2000));
}
const url = task.image_url ?? task.output?.image_url ??
  (Array.isArray(task.image_urls) ? task.image_urls[0] : undefined) ?? task.result;
if (!url) throw new Error(`no image url: ${JSON.stringify(task).slice(0, 300)}`);
await writeFile(OUT, Buffer.from(await (await fetch(url)).arrayBuffer()));
console.log('wrote', OUT);
