#!/usr/bin/env python3
# Writes the brand SVGs into assets/: icon.svg (app icon, 1024 grid), logo.svg and logo-dark.svg (Dot alone),
# logo-mono.svg (one-color silhouette), wordmark.svg and wordmark-dark.svg (geometric monoline
# "periodical" with Dot as the period). scripts/make-icon.swift draws the same icon for the .icns.
#   python3 scripts/make-brand.py
import math, os, sys

OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets")
INK = "#1C1C1E"

# ---------- Dot character (shared geometry, 1024 grid) ----------
CX, CY, R = 530, 540, 250
def dot_defs(p):
    return f'''
    <radialGradient id="{p}body" cx="0.36" cy="0.3" r="0.78">
      <stop offset="0" stop-color="#55555C"/><stop offset="0.5" stop-color="#232326"/><stop offset="1" stop-color="#0B0B0C"/>
    </radialGradient>
    <radialGradient id="{p}rim" cx="0.5" cy="0.5" r="0.5">
      <stop offset="0.72" stop-color="#FFC21A" stop-opacity="0"/><stop offset="1" stop-color="#FFC21A" stop-opacity="0.7"/>
    </radialGradient>
    <linearGradient id="{p}rimfade" x1="0.15" y1="0.1" x2="0.85" y2="0.95">
      <stop offset="0.45" stop-color="#fff" stop-opacity="0"/><stop offset="1" stop-color="#fff" stop-opacity="1"/>
    </linearGradient>
    <mask id="{p}rimmask" maskContentUnits="userSpaceOnUse"><rect x="{CX-R}" y="{CY-R}" width="{2*R}" height="{2*R}" fill="url(#{p}rimfade)"/></mask>
    <linearGradient id="{p}eye" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0.55" stop-color="#FFFFFF"/><stop offset="1" stop-color="#E4E4EC"/>
    </linearGradient>
    <filter id="{p}blur24" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="24"/></filter>
    <filter id="{p}blur10" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="10"/></filter>'''

def dot_body(p, rim=True):
    ex = [478, 622]; ey = 506
    s = f'''
    <circle cx="{CX}" cy="{CY}" r="{R}" fill="url(#{p}body)"/>'''
    if rim:
        s += f'''
    <circle cx="{CX}" cy="{CY}" r="{R}" fill="url(#{p}rim)" mask="url(#{p}rimmask)"/>'''
    s += f'''
    <ellipse cx="430" cy="390" rx="92" ry="44" transform="rotate(-38 430 390)" fill="#fff" opacity="0.18" filter="url(#{p}blur10)"/>
    <ellipse cx="404" cy="372" rx="30" ry="14" transform="rotate(-38 404 372)" fill="#fff" opacity="0.5"/>'''
    for x in ex:
        s += f'''
    <ellipse cx="{x}" cy="{ey}" rx="54" ry="70" fill="url(#{p}eye)"/>
    <circle cx="{x+15}" cy="{ey-7}" r="31" fill="#0B0B0C"/>
    <circle cx="{x+25}" cy="{ey-19}" r="10" fill="#fff"/>'''
    s += '''
    <path d="M520 626 Q552 656 584 626" fill="none" stroke="#fff" stroke-width="17" stroke-linecap="round"/>'''
    return s

def svg(viewbox, body, title):
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{viewbox}" role="img" aria-label="{title}">\n<title>{title}</title>\n{body}\n</svg>\n'

# ---------- App icon ----------
icon = f'''<defs>
    <linearGradient id="field" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#FFE45A"/><stop offset="1" stop-color="#FFC00C"/>
    </linearGradient>
    <radialGradient id="glow" cx="0.3" cy="0.18" r="0.75">
      <stop offset="0" stop-color="#FFF6B8" stop-opacity="0.7"/><stop offset="1" stop-color="#FFF6B8" stop-opacity="0"/>
    </radialGradient>
    <clipPath id="tile"><rect x="100" y="100" width="824" height="824" rx="185.4"/></clipPath>
    <filter id="tileshadow" x="-10%" y="-10%" width="120%" height="125%"><feDropShadow dx="0" dy="10" stdDeviation="12" flood-color="#000" flood-opacity="0.24"/></filter>{dot_defs("d")}
  </defs>
  <g filter="url(#tileshadow)"><rect x="100" y="100" width="824" height="824" rx="185.4" fill="url(#field)"/></g>
  <g clip-path="url(#tile)">
    <rect x="100" y="100" width="824" height="824" fill="url(#glow)"/>
    <ellipse cx="{CX+10}" cy="{CY+R+12}" rx="210" ry="30" fill="#9A6200" opacity="0.5" filter="url(#dblur24)"/>{dot_body("d")}
  </g>'''
open(f"{OUT}/icon.svg","w").write(svg("0 0 1024 1024", icon, "Periodical"))

# ---------- Logo (character alone) ----------
logo = f'''<defs>{dot_defs("d")}
  </defs>{dot_body("d", rim=False)}'''
pad = 6
box = f"{CX-R-pad} {CY-R-pad} {2*(R+pad)} {2*(R+pad)}"
open(f"{OUT}/logo.svg","w").write(svg(box, logo, "Periodical"))
# On dark grounds a faint light edge, brightest at the lower right, keeps the ball's silhouette from sinking into the background.
logo_dark = logo + f'''
    <circle cx="{CX}" cy="{CY}" r="{R-5}" fill="none" stroke="#fff" stroke-opacity="0.32" stroke-width="10" mask="url(#drimmask)"/>'''
open(f"{OUT}/logo-dark.svg","w").write(svg(box, logo_dark, "Periodical"))

# ---------- Mono logo (template-safe silhouette) ----------
mono = f'''<path fill="#000" fill-rule="evenodd" d="M{CX-R} {CY} a{R} {R} 0 1 0 {2*R} 0 a{R} {R} 0 1 0 {-2*R} 0 Z M424 506 a54 70 0 1 0 108 0 a54 70 0 1 0 -108 0 Z M568 506 a54 70 0 1 0 108 0 a54 70 0 1 0 -108 0 Z"/>
  <circle cx="493" cy="499" r="31" fill="#000"/><circle cx="637" cy="499" r="31" fill="#000"/>'''
open(f"{OUT}/logo-mono.svg","w").write(svg(f"{CX-R} {CY-R} {2*R} {2*R}", mono, "Periodical"))

# ---------- Wordmark: geometric monoline, Dot as the period ----------
W = 26.0          # stroke
r = (100 - W)/2   # bowl centerline radius (x-height 100)
top, base = 50, 150   # x-height line, baseline (y down)
asc, desc = 0, 200
yc = 100
h = W/2
k = r*math.cos(math.radians(45))
paths = []
thin = []   # optically lighter strokes (the e's crossbar), drawn at W_THIN
butt = []   # full-weight strokes with flat ends
caps = []   # round ends for the flat-ended strokes
W_THIN = 21.0
def stem(x, y1, y2): paths.append(f"M{x:.1f} {y1+h:.1f}V{y2-h:.1f}")
def bowl(cx): paths.append(f"M{cx-r:.1f} {yc}a{r:.1f} {r:.1f} 0 1 0 {2*r:.1f} 0a{r:.1f} {r:.1f} 0 1 0 {-2*r:.1f} 0")
tittles = []
x = 0.0
def adv(width, gap): 
    global x; x += width + gap
# p
L=x; bowl(L+50); paths.append(f"M{L+h:.1f} {yc}V{desc-h:.1f}"); adv(100, 15)
# e
# The e's bowl has a flat start hidden under its lighter crossbar and a round terminal drawn as a dot.
L=x; cx=L+50; ebar = yc + 3; e65 = math.radians(65)
thin.append(f"M{cx-r:.1f} {ebar}H{cx+r+2.5:.1f}")
ex_, ey_ = cx + r*math.cos(e65), yc + r*math.sin(e65)
y0 = ebar - yc
butt.append(f"M{cx+math.sqrt(r*r-y0*y0):.1f} {ebar}A{r:.1f} {r:.1f} 0 1 0 {ex_:.1f} {ey_:.1f}")
caps.append((ex_, ey_)); adv(100, 13)
# r
L=x; sx=L+h; stem(sx, top, base); paths.append(f"M{sx:.1f} {yc+4:.1f}V{yc:.1f}A{r:.1f} {r:.1f} 0 0 1 {sx+r:.1f} {top+h:.1f}"); adv(W+r, 9)
# i
L=x; stem(L+h, top, base); tittles.append(L+h); adv(W, 18)
# o
L=x; bowl(L+50); adv(100, 15)
# d
L=x; bowl(L+50); stem(L+100-h, asc, base); adv(100, 18)
# i
L=x; stem(L+h, top, base); tittles.append(L+h); adv(W, 15)
# c
L=x; cx=L+50; paths.append(f"M{cx+k:.1f} {yc-k:.1f}A{r:.1f} {r:.1f} 0 1 0 {cx+k:.1f} {yc+k:.1f}"); adv(50+k+h, 12)
# a
L=x; bowl(L+50); paths.append(f"M{L+100-h:.1f} {yc}V{base-h:.1f}"); adv(100, 18)
# l
L=x; stem(L+h, asc, base); adv(W, 14)
# Dot period
dr = 31; dcx = x + dr; dcy = base - dr; x += 2*dr
total = x
def wordmark(ink, eye, pupil, title, ring=None):
    d = " ".join(paths)
    t = "".join(f'<circle cx="{tx:.1f}" cy="{h+3:.1f}" r="{h+3:.1f}"/>' for tx in tittles)
    ex = [dcx-11.5, dcx+11.5]
    edge = f' stroke="{ring}" stroke-width="3.5"' if ring else ""
    eyes = "".join(f'<ellipse cx="{e:.1f}" cy="{dcy-4:.1f}" rx="8.2" ry="11"{edge} fill="{eye}"/><circle cx="{e+2.5:.1f}" cy="{dcy-6.5:.1f}" r="5" fill="{pupil}"/>' for e in ex)
    body = f'''<g fill="none" stroke="{ink}" stroke-linecap="round" stroke-linejoin="round"><path stroke-width="{W}" d="{d}"/><path stroke-width="{W_THIN}" d="{" ".join(thin)}"/><path stroke-width="{W}" stroke-linecap="butt" d="{" ".join(butt)}"/></g>
  <g fill="{ink}">{t}{"".join(f'<circle cx="{cx_:.1f}" cy="{cy_:.1f}" r="{h}"/>' for cx_, cy_ in caps)}<circle cx="{dcx:.1f}" cy="{dcy:.1f}" r="{dr}"/></g>
  {eyes}'''
    return svg(f"-4 -4 {total+8:.0f} {desc+8}", body, title)
open(f"{OUT}/wordmark.svg","w").write(wordmark(INK, "#FFFFFF", INK, "Periodical"))
open(f"{OUT}/wordmark-dark.svg","w").write(wordmark("#FFFFFF", "#FFFFFF", "#1C1C1E", "Periodical", ring="#1C1C1E"))

