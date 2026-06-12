#!/usr/bin/env python3
"""Renders Headwind app-icon concept SVGs to squircle-masked previews."""

import cairosvg
from PIL import Image, ImageDraw
from pathlib import Path

OUT = Path(__file__).parent

HEADER = '<?xml version="1.0"?><svg width="1024" height="1024" viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg">'


def sky_gradient(gid="sky", stops=(("0", "#5BC4F5"), ("0.52", "#2E7BE5"), ("1", "#1D3F9E"))):
    s = "".join(f'<stop offset="{o}" stop-color="{c}"/>' for o, c in stops)
    return f'<defs><linearGradient id="{gid}" x1="0" y1="0" x2="0.22" y2="1">{s}</linearGradient></defs>'


# --- Concept A: attitude indicator (artificial horizon), 10° bank ---
attitude = HEADER + f'''
<defs>
  <linearGradient id="panel" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#1B2A4E"/><stop offset="1" stop-color="#0F1B38"/>
  </linearGradient>
  <linearGradient id="skyhalf" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#54B9F0"/><stop offset="1" stop-color="#2E7BE5"/>
  </linearGradient>
  <linearGradient id="earth" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#C07434"/><stop offset="1" stop-color="#8A4D22"/>
  </linearGradient>
  <clipPath id="dial"><circle cx="512" cy="512" r="358"/></clipPath>
</defs>
<rect width="1024" height="1024" fill="url(#panel)"/>
<g clip-path="url(#dial)">
  <g transform="rotate(-10 512 512)">
    <rect x="52" y="52" width="920" height="460" fill="url(#skyhalf)"/>
    <rect x="52" y="512" width="920" height="460" fill="url(#earth)"/>
    <rect x="52" y="506" width="920" height="12" fill="#FFFFFF"/>
    <rect x="427" y="402" width="170" height="9" rx="4" fill="#FFFFFF" fill-opacity="0.55"/>
    <rect x="459" y="452" width="106" height="9" rx="4" fill="#FFFFFF" fill-opacity="0.45"/>
    <rect x="459" y="562" width="106" height="9" rx="4" fill="#FFFFFF" fill-opacity="0.45"/>
    <rect x="427" y="612" width="170" height="9" rx="4" fill="#FFFFFF" fill-opacity="0.55"/>
  </g>
</g>
<circle cx="512" cy="512" r="364" fill="none" stroke="#FFFFFF" stroke-opacity="0.16" stroke-width="16"/>
<g fill="#FFD60A">
  <rect x="312" y="500" width="130" height="22" rx="11"/>
  <rect x="420" y="500" width="22" height="44" rx="11"/>
  <rect x="582" y="500" width="130" height="22" rx="11"/>
  <rect x="582" y="500" width="22" height="44" rx="11"/>
  <circle cx="512" cy="511" r="17"/>
</g>
</svg>'''

# --- Concept C: runway 27 at dusk ---
edge_lights = "".join(
    f'<circle cx="{lx}" cy="{y}" r="{r}" fill="#FFC76B" fill-opacity="0.95"/>'
    f'<circle cx="{rx}" cy="{y}" r="{r}" fill="#FFC76B" fill-opacity="0.95"/>'
    for lx, rx, y, r in [
        (262, 762, 952, 11), (310, 714, 836, 9), (352, 672, 732, 8),
        (388, 636, 644, 6), (418, 606, 570, 5), (443, 581, 510, 4),
    ]
)
keys = "".join(
    f'<rect x="{x}" y="958" width="36" height="54" rx="6" fill="#FFFFFF" fill-opacity="0.85"/>'
    for x in (350, 412, 474, 536, 598, 660)
)
runway = HEADER + f'''
<defs>
  <linearGradient id="dusk" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#16275C"/><stop offset="0.26" stop-color="#3F6BCD"/>
    <stop offset="0.385" stop-color="#E8865A"/>
  </linearGradient>
</defs>
<rect width="1024" height="1024" fill="url(#dusk)"/>
<rect y="394" width="1024" height="10" fill="#FFC76B" fill-opacity="0.5"/>
<rect y="402" width="1024" height="622" fill="#27335A"/>
<polygon points="212,1024 812,1024 552,408 472,408" fill="#39466A"/>
<line x1="227" y1="1024" x2="477" y2="412" stroke="#FFFFFF" stroke-opacity="0.35" stroke-width="10"/>
<line x1="797" y1="1024" x2="547" y2="412" stroke="#FFFFFF" stroke-opacity="0.35" stroke-width="10"/>
<g fill="#FFFFFF" fill-opacity="0.92">
  <rect x="503" y="772" width="18" height="56" rx="5"/>
  <rect x="505" y="676" width="14" height="45" rx="4"/>
  <rect x="506" y="598" width="11" height="36" rx="3"/>
  <rect x="508" y="536" width="8" height="28" rx="2"/>
  <rect x="509" y="488" width="6" height="21" rx="2"/>
</g>
<text x="512" y="938" font-family="sans-serif" font-weight="700" font-size="116"
      text-anchor="middle" fill="#FFFFFF" fill-opacity="0.95">27</text>
{keys}
{edge_lights}
</svg>'''

# --- Concept D: windsock in a stiff breeze ---
def sock_segments(fill_shadow=None):
    segs = [
        (330, 96, 458, 79, "#FF8A3D"),
        (458, 79, 568, 65, "#F2F6FC"),
        (568, 65, 668, 52, "#FF8A3D"),
        (668, 52, 752, 41, "#F2F6FC"),
        (752, 41, 826, 32, "#FF8A3D"),
    ]
    out = []
    for x0, h0, x1, h1, color in segs:
        c = fill_shadow or color
        out.append(
            f'<polygon points="{x0},{-h0} {x1},{-h1} {x1},{h1} {x0},{h0}" fill="{c}"/>'
        )
    return "".join(out)


windsock = HEADER + sky_gradient(stops=(("0", "#68CCF7"), ("0.55", "#2E7BE5"), ("1", "#1D4AAE"))) + f'''
<rect width="1024" height="1024" fill="url(#sky)"/>
<g stroke="#FFFFFF" stroke-width="26" stroke-linecap="round" fill="none">
  <line x1="560" y1="180" x2="850" y2="180" stroke-opacity="0.30"/>
  <line x1="640" y1="262" x2="900" y2="262" stroke-opacity="0.18"/>
</g>
<line x1="338" y1="908" x2="330" y2="330" stroke="#0E2A63" stroke-opacity="0.18" stroke-width="30" stroke-linecap="round" transform="translate(10,20)"/>
<g transform="translate(12, 350)" fill-opacity="0.18"><g transform="rotate(7 330 0)">{sock_segments("#0E2A63")}</g></g>
<line x1="330" y1="900" x2="330" y2="330" stroke="#FFFFFF" stroke-width="30" stroke-linecap="round"/>
<g transform="translate(0, 330)"><g transform="rotate(7 330 0)">{sock_segments()}</g></g>
</svg>'''

concepts = {
    "icon-A-attitude": attitude,
    "icon-C-runway": runway,
    "icon-D-windsock": windsock,
}

mask = Image.new("L", (1024, 1024), 0)
ImageDraw.Draw(mask).rounded_rectangle([0, 0, 1023, 1023], radius=232, fill=255)

for name, svg in concepts.items():
    png = OUT / f"{name}.png"
    cairosvg.svg2png(bytestring=svg.encode(), write_to=str(png), output_width=1024, output_height=1024)
    img = Image.open(png).convert("RGBA")
    img.putalpha(mask)
    img.resize((512, 512), Image.LANCZOS).save(OUT / f"{name}-preview.png")
    (OUT / f"{name}.svg").write_text(svg)

# comparison grid at home-screen-ish scale, current dart included
grid_names = ["icon-A-attitude", "icon-C-runway", "icon-D-windsock", "preview-rounded"]
grid = Image.new("RGBA", (560, 560), (24, 28, 38, 255))
for i, name in enumerate(grid_names):
    tile = Image.open(OUT / f"{name}.png" if name != "preview-rounded" else OUT / "preview-rounded.png")
    tile = tile.convert("RGBA").resize((240, 240), Image.LANCZOS)
    if name != "preview-rounded":
        m = mask.resize((240, 240))
        tile.putalpha(m)
    grid.paste(tile, (27 + (i % 2) * 267, 27 + (i // 2) * 267), tile)
grid.save(OUT / "icon-grid.png")
print("rendered", ", ".join(concepts))
