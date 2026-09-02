// Generates the modular Meshy props needed to bring the physical Club Shop
// merchandising in line with the approved private-bookstore mockup.
//
//   node scripts/gen-shop-merchandising.mjs [output-directory]
//
// Requires MESHY_API_KEY. Source responses and both GLB/USDZ outputs are
// preserved so runtime integration never depends on expiring provider URLs.

import { mkdir, readFile, writeFile } from 'node:fs/promises';
import path from 'node:path';

const API_KEY = process.env.MESHY_API_KEY;
if (!API_KEY) {
  console.error('MESHY_API_KEY not set');
  process.exit(1);
}

const OUT = process.argv[2] ?? '/tmp/numberclub-meshy-merchandising';
const BASE = 'https://api.meshy.ai/openapi/v2/text-to-3d';
const STATE_PATH = path.join(OUT, '.meshy-state.json');

const MODELS = {
  shop_board_classic: {
    prompt: [
      'Single isolated square luxury Sudoku board edition plaque, exact one-to-one',
      'square silhouette and very shallow depth. Warm ivory enamel playing surface',
      'with an exact regular 9 by 9 grid made from fine raised aged-brass rules,',
      'stronger brass divisions after every third row and column, tiny round brass',
      'nodes at intersections, four small brass corner screws, and a very thin dark',
      'walnut and brass perimeter frame. Front-facing, perfectly orthographic and',
      'symmetrical, refined 1930s private-library craftsmanship. No numbers, no',
      'letters, no text, no logo, no stand, no wall, no ground plane, no other object.',
    ].join(' '),
    texture: [
      'Warm ivory enamel or vellum playing field, aged brushed brass grid nodes frame',
      'and screws, narrow dark walnut edge, subtle handmade patina, premium realistic',
      'PBR materials, no painted lighting, no text, no numbers.',
    ].join(' '),
    polycount: 14_000,
  },
  shop_board_stargazer: {
    prompt: [
      'Single isolated square luxury Sudoku board edition plaque, exact one-to-one',
      'square silhouette and very shallow depth. Deep midnight-navy enamel playing',
      'surface, an exact regular 9 by 9 aged-brass grid with stronger divisions every',
      'third row and column, tiny brass corner screws, and delicate engraved celestial',
      'constellation lines and small star points woven between but never replacing the',
      'grid. Thin aged-brass perimeter frame. Front-facing, orthographic, symmetrical,',
      '1930s observatory-library style. No numbers, letters, text, logo, stand, wall,',
      'ground plane or extra objects.',
    ].join(' '),
    texture: [
      'Very dark midnight blue enamel, fine aged-brass grid frame screws and celestial',
      'engraving, sparse warm star points, subtle lacquer wear, realistic premium PBR',
      'materials, no painted shadows, no text or numbers.',
    ].join(' '),
    polycount: 15_000,
  },
  shop_board_botanica: {
    prompt: [
      'Single isolated square luxury Sudoku board edition plaque, exact one-to-one',
      'square silhouette and very shallow depth. Deep bottle-green enamel playing',
      'surface, an exact regular 9 by 9 aged-brass grid with stronger divisions every',
      'third row and column, four small brass corner screws, and restrained engraved',
      'botanical vines, fern leaves and seed motifs curling through selected empty cells',
      'without obscuring the grid. Thin aged-brass perimeter frame. Front-facing,',
      'orthographic, symmetrical, private botanical-library craftsmanship. No numbers,',
      'letters, text, logo, stand, wall, ground plane or extra objects.',
    ].join(' '),
    texture: [
      'Deep matte bottle-green enamel, warm aged-brass grid frame screws and engraved',
      'botanical details, lightly hand-worn edges, realistic premium PBR materials, no',
      'painted lighting, no text or numbers.',
    ].join(' '),
    polycount: 15_000,
  },
  shop_board_scribes: {
    prompt: [
      'Single isolated square luxury Sudoku board edition plaque, exact one-to-one',
      'square silhouette and very shallow depth. Aged warm vellum manuscript playing',
      'surface mounted inside a thin dark walnut and aged-brass frame, an exact regular',
      '9 by 9 sepia-ink grid with stronger divisions every third row and column, four',
      'small brass corner screws, subtle handwritten proofreader marks, faded botanical',
      'marginalia and a few restrained red wax-pencil annotations around empty cells.',
      'Front-facing, orthographic, symmetrical, archival 1930s private-library object.',
      'No readable words, no numbers, no logo, no stand, no wall, no ground plane, no',
      'extra objects.',
    ].join(' '),
    texture: [
      'Warm mottled vellum, sepia ink grid, faint illegible manuscript marginalia, small',
      'restrained red proof marks, dark walnut and aged brass frame with corner screws,',
      'realistic premium PBR materials, no painted lighting, no readable text or digits.',
    ].join(' '),
    polycount: 15_000,
  },
  shop_board_scribes_v2: {
    prompt: [
      'Single isolated square antique manuscript Sudoku board plaque, exactly one-to-one',
      'square and very shallow. The entire front is visibly aged cream vellum densely',
      'covered with faded illegible brown calligraphic notes, proofreader symbols, tiny',
      'botanical marginal sketches, ink stains and several obvious restrained red wax-',
      'pencil circles and correction marks. A complete regular 9 by 9 sepia grid remains',
      'clearly visible over the manuscript, with stronger lines every third row and column.',
      'Thin aged-brass inner keyline, narrow dark-walnut frame, four brass corner screws.',
      'Front-facing, orthographic, symmetrical, archival private-library craftsmanship.',
      'No readable words, no modern typography, no logo, no stand, no wall, no floor, no',
      'other objects.',
    ].join(' '),
    texture: [
      'Highly visible aged cream vellum manuscript with dense faded illegible sepia notes',
      'and sketches across every area, several restrained but clearly visible red proofing',
      'circles and stamps, sepia 9 by 9 grid, dark walnut and aged brass trim, realistic',
      'premium PBR materials, no painted lighting, no readable words or digits.',
    ].join(' '),
    polycount: 15_000,
  },
  shop_product_box_v2: {
    prompt: [
      'Single isolated upright premium product box for a collectible Sudoku board',
      'edition, exact four-to-five width-to-height proportion, noticeably broad rather',
      'than tall and skinny. Closed rigid clothbound slipcase with shallow depth, deep',
      'bottle-green book cloth, crisp beveled edges, thin aged-brass piping, a large',
      'centered empty square recessed display window on the upper front, and a blank',
      'shallow title area below it. Front-facing, symmetrical, stable, refined 1930s',
      'private-bookstore packaging. No text, letters, logo, board, shelf, ground plane',
      'or other objects.',
    ].join(' '),
    texture: [
      'Deep bottle-green woven book cloth, thin aged-brass edge piping and window trim,',
      'dark inset backing, restrained hand wear, premium realistic PBR materials, no',
      'painted lighting, no text or logo.',
    ].join(' '),
    polycount: 9_000,
  },
  shop_nameplate_v2: {
    prompt: [
      'Single isolated compact horizontal product nameplate, exact three-to-one width',
      'to height and extremely shallow depth. Deep bottle-green enamel center dominates',
      'the face, surrounded by one very thin aged-brass keyline and a narrow dark-walnut',
      'outer bevel, with only two tiny brass mounting pins at the far left and right.',
      'Blank center for dynamic two-line product text. Front-facing, symmetrical, refined',
      '1930s private-library cabinet hardware. No text, letters, logo, wall, shelf, ground',
      'plane or extra objects.',
    ].join(' '),
    texture: [
      'Deep matte bottle-green enamel, thin aged-brass keyline and pins, dark walnut bevel,',
      'subtle period patina, premium realistic PBR materials, no painted lighting or text.',
    ].join(' '),
    polycount: 5_000,
  },
  shop_featured_board_v2: {
    prompt: [
      'Single isolated luxury fold-open Sudoku demonstration board. Broad four-to-three',
      'landscape silhouette: two rigid warm-ivory vellum panels opened nearly flat with',
      'a visible aged-brass center hinge, dark-brown leather edge and brass corners.',
      'One complete regular 9 by 9 raised brass grid spans both panels, with stronger',
      'divisions every third row and column and tiny brass intersection nodes. Seven',
      'small dark-walnut square number tiles sit in scattered cells, each with one crisp',
      'ivory digit chosen from 1 2 3 6 and 8. Tilted back twenty degrees, front-facing,',
      'symmetrical 1930s private-library craft. No stand, platform, table, wall, logo,',
      'readable words or extra objects.',
    ].join(' '),
    texture: [
      'Warm ivory vellum panels, dark hand-tooled brown leather edge, aged brushed brass',
      'hinge grid nodes and corners, dark walnut number tiles with crisp ivory embossed',
      'digits, subtle hand wear, premium realistic PBR materials, no painted lighting.',
    ].join(' '),
    polycount: 18_000,
  },
  shop_side_lamp: {
    prompt: [
      'Single isolated small 1930s private-library table lamp. Compact warm-ivory',
      'pleated fabric bell shade, slender aged-brass stem, small dark-brass weighted',
      'round base and a tiny pull chain. Upright, front-facing, refined realistic',
      'craftsmanship, designed as subtle background dressing beside a walnut display',
      'cabinet. The bulb is hidden inside the shade. No table, shelf, wall, floor,',
      'books, text, logo, cord or extra objects.',
    ].join(' '),
    texture: [
      'Warm ivory pleated fabric with subtle weave, aged satin brass stem and base,',
      'soft period patina, premium realistic PBR materials, no painted light rays,',
      'no glowing halo, no text or logo.',
    ].join(' '),
    polycount: 9_000,
  },
  shop_side_globe: {
    prompt: [
      'Single isolated small antique celestial globe for a 1930s private library.',
      'Cream parchment sphere with restrained sepia celestial-map markings, held by',
      'one thin aged-brass meridian ring on a compact turned brass pedestal and dark',
      'walnut circular base. Upright, front-facing, symmetrical, premium realistic',
      'craftsmanship, designed as subtle background dressing beside a display cabinet.',
      'No table, shelf, wall, floor, books, readable text, logo or extra objects.',
    ].join(' '),
    texture: [
      'Warm aged parchment sphere, faint illegible sepia constellations, aged satin',
      'brass ring and pedestal, dark walnut base, premium realistic PBR materials,',
      'no painted lighting, no readable labels.',
    ].join(' '),
    polycount: 10_000,
  },
  shop_board_frame: {
    prompt: [
      'Single isolated square wall-mounted presentation frame for one luxury',
      '9 by 9 Sudoku board material sample. Thin aged-brass outer frame, four',
      'small round brass corner screw heads, shallow dark walnut backing, and a',
      'large empty square center recess intended to hold a separate board.',
      'Front-facing, perfectly symmetrical, very shallow depth, crisp bevels,',
      '1930s private bookstore cabinet hardware. No board, no grid, no text, no',
      'letters, no logo, no wall, no stand, no ground plane, no extra objects.',
    ].join(' '),
    texture: [
      'Aged brushed brass trim and screw heads, dark polished walnut backing,',
      'restrained hand-worn edges, realistic PBR response, no painted shadows,',
      'no text, no logo, empty center recess.',
    ].join(' '),
    polycount: 7_000,
  },
  shop_product_box: {
    prompt: [
      'Single isolated upright premium product box for a collectible Sudoku',
      'board edition, like a 1930s private bookstore presentation slipcase.',
      'Tall rectangular dark clothbound box, gently beveled edges, thin aged',
      'brass piping, a centered empty square recessed display window on the',
      'front, and one small blank inset nameplate area near the bottom.',
      'Closed rigid box, front-facing, symmetrical, stable proportions. No',
      'text, no letters, no logo, no board inside the window, no shelf, no',
      'ground plane, no other objects.',
    ].join(' '),
    texture: [
      'Deep bottle-green book cloth with subtle weave, aged brass edge piping,',
      'dark green inset window backing, tiny warm wear on corners, premium',
      'realistic PBR materials, no painted lighting, no text or logo.',
    ].join(' '),
    polycount: 7_000,
  },
  shop_nameplate: {
    prompt: [
      'Single isolated small horizontal nameplate body for a luxury bookstore',
      'cabinet display. Thin aged-brass rectangular frame with clipped corners,',
      'deep bottle-green enamel center, four tiny brass rivets, shallow mounting',
      'depth, front-facing and perfectly symmetrical. Blank center for dynamic',
      'product text. No text, no letters, no logo, no wall, no shelf, no ground',
      'plane, no extra objects.',
    ].join(' '),
    texture: [
      'Aged brushed brass frame and rivets, deep matte bottle-green enamel',
      'center, refined 1930s private-club patina, realistic PBR materials, no',
      'painted highlights, no lettering.',
    ].join(' '),
    polycount: 4_500,
  },
  shop_display_shelf: {
    prompt: [
      'Single isolated solid flat display shelf plank for a cabinet, extremely',
      'long and narrow, ten to one width-to-height proportion. One solid dark',
      'walnut board with a flat top surface, shallow depth, softly beveled front',
      'molding and one restrained thin aged-brass lip along the front edge.',
      'Straight, symmetrical, 1930s private bookstore cabinetry. This is a',
      'solid shelf ledge, not a box, not a cubby, not a cabinet, no hollow area,',
      'no opening, no wall, no brackets, no products, no text, no logo, no',
      'ground plane, no extra objects.',
    ].join(' '),
    texture: [
      'Rich dark walnut grain, satin hand-rubbed finish, thin aged-brass front',
      'lip, subtle edge wear, realistic PBR materials, no painted lighting.',
    ].join(' '),
    polycount: 5_000,
  },
  shop_header_plaque: {
    prompt: [
      'Single isolated extremely wide landscape sign plaque for a luxury 1930s',
      'private bookstore cabinet. Exact five-to-one width-to-height proportion:',
      'the total height is only twenty percent of its long width. Flat shallow',
      'horizontal rectangle, never square and never portrait. Deep recessed',
      'bottle-green leather or enamel center, very thin aged-brass inner border,',
      'dark walnut outer molding with crisp shallow bevels. Blank center for a',
      'dynamic heading, front-facing and symmetrical. No text, no letters, no',
      'logo, no wall, no shelf, no ground plane, no extra objects.',
    ].join(' '),
    texture: [
      'Deep bottle-green matte leather center, warm aged-brass keyline, rich',
      'walnut molding, subtle period patina, realistic PBR response, no painted',
      'lighting, no lettering.',
    ].join(' '),
    polycount: 6_000,
  },
  shop_featured_folio: {
    prompt: [
      'Single isolated luxury Sudoku folio opened completely flat to 180 degrees',
      'like an open book, with the left and right pages side by side in one',
      'continuous plane. The entire open book is one shallow landscape slab',
      'tilted backward only fifteen degrees for a tabletop presentation. Never',
      'an L shape, no page standing perpendicular, no vertical closed book.',
      'Two rigid warm-ivory vellum pages in a dark brown leather bookbinder',
      'cover, aged-brass center hinge and corner protectors, a precise decorative',
      '9 by 9 brass-line Sudoku grid spanning the open pages with stronger 3 by',
      '3 divisions. Empty grid with no digits. Front-facing, symmetrical, premium',
      '1930s private bookstore proofing object. No text, no letters, no numbers,',
      'no logo, no stand, no table, no ground plane, no extra objects.',
    ].join(' '),
    texture: [
      'Warm ivory vellum pages, dark hand-tooled brown leather cover, restrained',
      'aged-brass hinge, corners and grid rules, subtle tactile wear, clean',
      'realistic PBR materials with no painted shadows, no text or numbers.',
    ].join(' '),
    polycount: 12_000,
  },
  shop_library_left: {
    prompt: [
      'Single isolated narrow tall side vignette for a 1930s private bookstore,',
      'one-to-three width-to-height proportion. A slim rich-walnut bookcase with',
      'three shelves densely filled with varied dark leatherbound books, plus a',
      'small warm pleated reading lamp on the lowest shelf. Front-facing, shallow',
      'depth, premium realistic construction, designed as background dressing',
      'beside a larger cabinet. No wall, no floor, no loose text, no logo, no',
      'people, no extra furniture.',
    ].join(' '),
    texture: [
      'Dark polished walnut, aged leather books in burgundy forest-green and',
      'umber, restrained gold spine bands without readable lettering, warm ivory',
      'fabric lampshade and aged brass lamp base, realistic PBR materials with',
      'no painted lighting.',
    ].join(' '),
    polycount: 12_000,
  },
  shop_library_right: {
    prompt: [
      'Single isolated narrow tall side vignette for a 1930s private bookstore,',
      'one-to-three width-to-height proportion. A slim rich-walnut bookcase with',
      'three shelves densely filled with varied dark leatherbound books, a small',
      'aged-brass celestial globe on the lowest shelf, and one framed botanical',
      'print tucked behind the books. Front-facing, shallow depth, premium',
      'realistic construction, designed as background dressing beside a larger',
      'cabinet. No wall, no floor, no readable text, no logo, no people, no',
      'extra furniture.',
    ].join(' '),
    texture: [
      'Dark polished walnut, aged leather books in forest-green navy and umber,',
      'restrained gold spine bands without readable lettering, aged brass globe,',
      'warm vellum botanical print, realistic PBR materials with no painted',
      'lighting.',
    ].join(' '),
    polycount: 12_000,
  },
};

const requestedNames = new Set(process.argv.slice(3));
const ACTIVE_MODELS = Object.fromEntries(
  Object.entries(MODELS).filter(([name]) => requestedNames.size === 0 || requestedNames.has(name)),
);
if (Object.keys(ACTIVE_MODELS).length === 0) {
  throw new Error(`No matching model names: ${[...requestedNames].join(', ')}`);
}

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

async function createPreview(name, specification) {
  const request = {
    mode: 'preview',
    prompt: specification.prompt,
    model_type: 'standard',
    ai_model: 'meshy-7',
    ultra_mode: true,
    should_remesh: true,
    topology: 'triangle',
    target_polycount: specification.polycount,
    target_formats: ['glb', 'usdz'],
    auto_size: false,
    origin_at: 'center',
    alpha_thumbnail: true,
    moderation: true,
  };
  await writeFile(path.join(OUT, `${name}-preview-request.json`), `${JSON.stringify(request, null, 2)}\n`);
  const body = await requestJSON(BASE, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(request),
  });
  return body.result;
}

async function createRefine(name, previewID, specification) {
  const request = {
    mode: 'refine',
    preview_task_id: previewID,
    ai_model: 'meshy-7',
    enable_pbr: true,
    texture_resolution: '2k',
    texture_prompt: specification.texture,
    target_formats: ['glb', 'usdz'],
    alpha_thumbnail: true,
    moderation: true,
  };
  await writeFile(path.join(OUT, `${name}-refine-request.json`), `${JSON.stringify(request, null, 2)}\n`);
  const body = await requestJSON(BASE, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(request),
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

async function preserveTask(name, stage, task) {
  await writeFile(path.join(OUT, `${name}-${stage}-response.json`), `${JSON.stringify(task, null, 2)}\n`);
}

await mkdir(OUT, { recursive: true });
const state = await loadState();

for (const [name, specification] of Object.entries(ACTIVE_MODELS)) {
  state[name] ??= {};
  if (!state[name].previewID) {
    state[name].previewID = await createPreview(name, specification);
    await saveState(state);
    console.log(`${name}: Meshy 7 Ultra preview task ${state[name].previewID}`);
  }
}

const previews = Object.fromEntries(await Promise.all(
  Object.entries(ACTIVE_MODELS).map(async ([name]) => {
    const task = await awaitTask(state[name].previewID, `${name} preview`);
    await preserveTask(name, 'preview', task);
    return [name, task];
  }),
));

for (const [name, specification] of Object.entries(ACTIVE_MODELS)) {
  if (!state[name].refineID) {
    state[name].refineID = await createRefine(name, state[name].previewID, specification);
    await saveState(state);
    console.log(`${name}: Meshy 7 PBR refine task ${state[name].refineID}`);
  }
}

const refined = Object.fromEntries(await Promise.all(
  Object.entries(ACTIVE_MODELS).map(async ([name]) => {
    const task = await awaitTask(state[name].refineID, `${name} refine`);
    await preserveTask(name, 'refine', task);
    return [name, task];
  }),
));

const manifest = {};
for (const [name, specification] of Object.entries(ACTIVE_MODELS)) {
  const task = refined[name];
  const downloads = [];
  for (const format of ['glb', 'usdz']) {
    const modelURL = task.model_urls?.[format];
    if (!modelURL) continue;
    const destination = path.join(OUT, `${name}.${format}`);
    downloads.push(download(modelURL, destination));
  }
  const thumbnailURL = task.alpha_thumbnail_url ?? task.thumbnail_url;
  if (!thumbnailURL) throw new Error(`${name}: missing thumbnail URL`);
  downloads.push(download(thumbnailURL, path.join(OUT, `${name}.png`)));
  await Promise.all(downloads);

  manifest[name] = {
    provider: 'Meshy',
    geometryModel: 'meshy-7-ultra',
    textureModel: 'meshy-7-pbr',
    previewID: state[name].previewID,
    refineID: state[name].refineID,
    geometryPrompt: specification.prompt,
    texturePrompt: specification.texture,
    previewCredits: previews[name].consumed_credits,
    refineCredits: task.consumed_credits,
    modelFormats: Object.keys(task.model_urls ?? {}),
    textureURLsPreservedInResponse: Boolean(task.texture_urls),
  };
  console.log(`${name}: preserved GLB/USDZ and thumbnail`);
}

await writeFile(path.join(OUT, 'manifest.json'), `${JSON.stringify(manifest, null, 2)}\n`);
console.log(`wrote ${OUT}`);
