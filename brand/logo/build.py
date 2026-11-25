import pathlib
OUT = pathlib.Path(__file__).parent / "svg"; OUT.mkdir(exist_ok=True)
GREEN, GOLD, CREAM, INK = "#0F4C3A", "#E0A93B", "#F4F1EA", "#0B1F18"
FONT = "Bahnschrift, 'DIN Alternate', 'Barlow Semi Condensed', 'Segoe UI', sans-serif"

def mark(uid, body, accent, x=0, y=0, s=1.0):
    return f'''<g transform="translate({x} {y}) scale({s})">
  <defs>
    <clipPath id="{uid}d"><path d="M16 12H60A48 48 0 0 1 60 108H16Z"/></clipPath>
    <mask id="{uid}l" maskUnits="userSpaceOnUse" x="0" y="0" width="120" height="120">
      <rect width="120" height="120" fill="#fff"/>
      <path d="M38 62C40 41 56 27 84 23C82 44 50 50 38 62Z" fill="#000"/>
    </mask>
  </defs>
  <g clip-path="url(#{uid}d)">
    <rect width="120" height="60" fill="{body}" mask="url(#{uid}l)"/>
    <rect y="64" width="120" height="12" fill="{body}"/>
    <rect y="80" width="120" height="9" fill="{body}"/>
    <rect y="93" width="120" height="6" fill="{body}"/>
    <rect y="103" width="120" height="5" fill="{accent}"/>
  </g>
</g>'''

def svg(w, h, inner, bg=None, title="DalaCarbon AI"):
    b = f'<rect width="{w}" height="{h}" fill="{bg}"/>' if bg else ""
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w} {h}" width="{w}" height="{h}"><title>{title}</title>{b}{inner}</svg>\n'

def wordmark(x, y, size, main, ai, tag=None, tagcol=None, anchor="start"):
    t = f'''<text x="{x}" y="{y}" text-anchor="{anchor}" font-family="{FONT}" font-size="{size}" font-weight="600" font-stretch="condensed" letter-spacing="-0.5" fill="{main}">DalaCarbon<tspan fill="{ai}" dx="{size*0.16:.1f}">AI</tspan></text>'''
    if tag:
        t += f'''<text x="{x+ (2 if anchor=='start' else 0)}" y="{y+size*0.5:.0f}" text-anchor="{anchor}" font-family="{FONT}" font-size="{size*0.24:.1f}" font-weight="400" letter-spacing="{size*0.06:.1f}" fill="{tagcol}">{tag}</text>'''
    return t

TAG = "SOIL CARBON INTELLIGENCE"
variants = {
  # name: (body, accent, word, ai, tagcol, bg)
  "color":   (GREEN, GOLD, GREEN, GOLD, "#5B6B63", None),
  "reverse": (CREAM, GOLD, CREAM, GOLD, "#9DB5AA", GREEN),
  "mono-black": (INK, INK, INK, INK, INK, None),
  "mono-white": ("#FFFFFF", "#FFFFFF", "#FFFFFF", "#FFFFFF", "#FFFFFF", INK),
}
for n, (body, acc, word, ai, tc, bg) in variants.items():
    (OUT/f"mark-{n}.svg").write_text(svg(120, 120, mark("m", body, acc), bg), encoding="utf-8")
    (OUT/f"logo-horizontal-{n}.svg").write_text(
        svg(560, 140, mark("h", body, acc, 10, 10) + wordmark(150, 84, 64, word, ai, TAG, tc), bg))
    (OUT/f"logo-stacked-{n}.svg").write_text(
        svg(360, 300, mark("s", body, acc, 110, 14, 1.2) + wordmark(180, 222, 56, word, ai, TAG, tc, "middle"), bg))

# App icon / avatar
icon = f'<rect width="512" height="512" rx="112" fill="{GREEN}"/>' + mark("i", CREAM, GOLD, 51.4, 58, 3.3)
(OUT/"app-icon.svg").write_text(svg(512, 512, icon, None, "DalaCarbon AI — app icon"), encoding="utf-8")
avatar = f'<circle cx="256" cy="256" r="256" fill="{GREEN}"/>' + mark("a", CREAM, GOLD, 70, 76, 3.0)
(OUT/"avatar-round.svg").write_text(svg(512, 512, avatar, None, "DalaCarbon AI — avatar"), encoding="utf-8")
print(sorted(p.name for p in OUT.iterdir()))
