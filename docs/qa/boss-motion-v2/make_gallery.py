"""Arrange unmodified Simulator capture images for the boss design review."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import json
import html

root = Path(__file__).parent
records = json.loads((root / 'gallery/boss-gallery-captions.json').read_text())
ordinary = records[:19]
font = '/System/Library/Fonts/Supplemental/Georgia.ttf'
small = ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc', 18)
title = ImageFont.truetype(font, 32)
label = ImageFont.truetype(font, 20)
for page, start in enumerate((0, 10), 1):
    selected = ordinary[start:start + 10]
    sheet = Image.new('RGB', (1400, 1410), '#eee8da')
    draw = ImageDraw.Draw(sheet)
    draw.text((32, 24), f'Probably Sudoku  /  Boss review {page} of 2', font=title, fill='#233b32')
    draw.text((32, 68), 'Actual gameplay captures · shared QA board · open the gallery to inspect at full size', font=small, fill='#5b655c')
    for n, row in enumerate(selected):
        x, y = 30 + (n % 5) * 274, 120 + (n // 5) * 640
        im = Image.open(root / 'gallery' / (row['image'] + '.png')).convert('RGB')
        im.thumbnail((250, 550), Image.Resampling.LANCZOS)
        sheet.paste(im, (x, y))
        # Long names wrap without altering the captured game image.
        words = f'{start+n+1:02d}  {row["name"]}'.split()
        lines, line = [], ''
        for word in words:
            candidate = (line + ' ' + word).strip()
            if draw.textlength(candidate, font=label) > 252:
                lines.append(line)
                line = word
            else:
                line = candidate
        lines.append(line)
        for j, line in enumerate(lines):
            draw.text((x, y + 552 + j * 25), line, font=label, fill='#233b32')
    sheet.save(root / f'boss-overview-{page}.jpg', quality=93)

cards = []
for index, row in enumerate(ordinary):
    cards.append(f'''<button class="card" data-index="{index}">
      <img src="gallery/{html.escape(row['image'])}.png" alt="{html.escape(row['name'])} gameplay screenshot" loading="lazy">
      <span class="ordinal">{index+1:02d}</span><h2>{html.escape(row['name'])}</h2>
      <p>{html.escape(row['rule'])}</p><span class="inspect">Inspect screenshot ↗</span></button>''')

template = '''<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Probably Sudoku · Boss review</title><style>
*{box-sizing:border-box}body{margin:0;background:#eee8da;color:#263c33;font:16px/1.5 -apple-system,BlinkMacSystemFont,sans-serif}
header{max-width:1440px;margin:auto;padding:48px 32px 28px}header .eyebrow{font-size:12px;letter-spacing:.18em;text-transform:uppercase}
h1{font:normal clamp(38px,5vw,72px)/1.05 Georgia,serif;margin:14px 0}header p{max-width:770px;color:#62665c}
.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(225px,1fr));gap:24px;max-width:1440px;margin:auto;padding:0 32px 48px}
.card{display:flex;flex-direction:column;align-items:stretch;text-align:left;padding:12px 12px 18px;border:1px solid #c8c8b8;background:#f7f1e4;cursor:pointer;color:inherit;box-shadow:0 3px 10px #233b320b;font:inherit}
.card:hover,.card:focus-visible{outline:2px solid #668574;outline-offset:3px;transform:translateY(-2px)}.card img{width:100%;display:block}
.ordinal{display:block;font-size:12px;letter-spacing:.12em;margin-top:16px;color:#747c6c}.card h2{font:24px/1.15 Georgia,serif;margin:4px 0 8px}.card p{font-size:14px;color:#666a60;margin:0 0 16px}.inspect{margin-top:auto;font-size:12px;font-weight:600}
dialog{width:min(1130px,96vw);height:min(940px,95dvh);padding:0;border:1px solid #9fae9b;background:#eee8da;color:#263c33}dialog::backdrop{background:#15271fd9}
.viewer{height:100%;display:grid;grid-template-columns:minmax(250px,1fr) minmax(260px,.8fr);gap:24px;padding:22px}.shot{width:100%;height:100%;min-height:0;object-fit:contain;align-self:center}
.description{overflow:auto;display:flex;flex-direction:column;gap:10px;padding:18px 8px}.description h2{font:42px/1.1 Georgia,serif;margin:10px 0}.rule{font-size:20px}.note{border-top:1px solid #bac2b2;padding-top:18px;color:#5b655c}.caption{font-size:13px;color:#747c6c}
.nav{display:flex;gap:10px;flex-wrap:wrap;margin-top:auto;padding-top:20px}button.control,a.control{border:1px solid #789080;background:transparent;padding:11px 15px;color:#263c33;text-decoration:none;cursor:pointer;font:inherit}button.control:hover{background:#dae0d0}.close{align-self:flex-end}
.sample{display:flex;gap:8px;flex-wrap:wrap}.sample button{font-size:13px}.motion{max-width:1440px;padding:0 32px 42px;margin:auto}.motion p{max-width:760px;color:#62665c}.motion a{color:#335c49}footer{padding:24px 32px;border-top:1px solid #c8c8b8;color:#6d7466;font-size:13px}
@media(max-width:640px){header{padding:28px 20px}.grid{padding:0 20px 32px;grid-template-columns:repeat(2,minmax(0,1fr));gap:12px}.card{padding:6px 6px 12px}.card h2{font-size:19px}.card p{font-size:12px}.viewer{display:flex;flex-direction:column;overflow:auto;gap:0;padding:12px}.shot{height:65vh;min-height:65vh}.description{overflow:visible;padding:12px}.description h2{font-size:30px}.nav{margin-top:10px}}
</style></head><body><header><div class="eyebrow">Probably Sudoku · Art & motion review</div><h1>The bosses, as they are.</h1>
<p>All 19 bosses captured from the actual gameplay views on an iPhone 17 Pro canvas. Select one to see the full screenshot, its rule, and a possible visual direction for us to discuss.</p>
<p>Both Garrys now use red clay bricks, staggered drops and brief impact dust. The other bosses below show their current treatment; the suggested directions have not been implemented.</p></header>
<main class="grid">CARDS</main><section class="motion"><h2>Landings in motion</h2><p>The screenshots show the settled state. <a href="native/box-entrance.mp4">Watch the box-boss entrance</a> · <a href="native/row-turn.mp4">Watch the row-boss turn change</a></p></section>
<dialog id="viewer"><div class="viewer"><img class="shot" id="shot" alt=""><div class="description"><button class="control close" id="close">Close ×</button><span class="ordinal" id="number"></span><h2 id="name"></h2><p class="rule" id="rule"></p><p class="note" id="idea"></p><p class="caption" id="setup"></p><div class="sample" id="samples"></div><div class="nav"><button class="control" id="prev">← Previous</button><button class="control" id="next">Next →</button><a class="control" id="original" target="_blank">Full-size image ↗</a></div></div></div></dialog>
<footer>Review captures use the same partially played QA board and populated inventory to expose each effect. They do not alter a saved player run. Final bosses are staged here for comparison. Additional Shredder and urgent Tik Tak states are available inside their viewer.</footer>
<script>const records=RECORDS;let index=18;const dialog=document.querySelector('#viewer');
function show(i,variant=null){index=(i+19)%19;const r=variant||records[index];document.querySelector('#shot').src='gallery/'+r.image+'.png';document.querySelector('#shot').alt=r.name+' gameplay screenshot';document.querySelector('#name').textContent=r.name;document.querySelector('#number').textContent=String(index+1).padStart(2,'0')+' / 19';document.querySelector('#rule').textContent=r.rule;document.querySelector('#idea').textContent='For discussion: '+r.discussion;document.querySelector('#setup').textContent=r.setup+'. '+r.handCount+' hand cards · '+r.turns+' turns · target '+r.target.toLocaleString();document.querySelector('#original').href='gallery/'+r.image+'.png';const samples=document.querySelector('#samples');samples.replaceChildren();const alternatives=records.filter(a=>a.bossID===r.bossID);if(alternatives.length>1)alternatives.forEach(a=>{const b=document.createElement('button');b.className='control';b.textContent=a.turn===2?'Turn 2':a.image.includes('urgent')?'25 seconds left':'First turn';b.onclick=()=>show(index,a);samples.appendChild(b)});if(!dialog.open)dialog.showModal()}
document.querySelectorAll('[data-index]').forEach(b=>b.onclick=()=>show(Number(b.dataset.index)));document.querySelector('#close').onclick=()=>dialog.close();document.querySelector('#prev').onclick=()=>show(index-1);document.querySelector('#next').onclick=()=>show(index+1);document.addEventListener('keydown',e=>{if(!dialog.open)return;if(e.key==='ArrowRight'){e.preventDefault();show(index+1)}if(e.key==='ArrowLeft'){e.preventDefault();show(index-1)}});dialog.addEventListener('click',e=>{if(e.target===dialog)dialog.close()});</script></body></html>'''
(root/'boss-gallery.html').write_text(template.replace('CARDS', '\n'.join(cards)).replace('RECORDS', json.dumps(records)), encoding='utf-8')
print('Created boss-gallery.html and two labeled overview sheets for 19 bosses.')
