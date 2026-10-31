# Peek, round 3: same idea (Remy peeks up on its day), away from the "dark blob + tall eyes" bot look.
INK, PAPER, BUTTER, CORAL, NIGHT, CREAM, MINT, LILAC, SKY, RED = ("#141414", "#F4F3EF", "#F6D66B", "#F28B6E",
    "#16161A", "#FBF4E4", "#9FD9BF", "#C7B8F0", "#9CC8F2", "#E5484D")

def tile(bg, body):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256" width="256" height="256">'
            f'<defs><clipPath id="t"><rect width="256" height="256" rx="57"/></clipPath></defs>'
            f'<rect width="256" height="256" rx="57" fill="{bg}"/><g clip-path="url(#t)">{body}</g></svg>')

def dome(fill, cy=226, r=98):
    return f'<path fill="{fill}" d="M{128-r} 256 V{cy} A{r} {r} 0 0 1 {128+r} {cy} V256 Z"/>'

def googly(white, pupil, y=182, dx=5, dy=-6, r=19, gap=22):
    return "".join(f'<circle cx="{x}" cy="{y}" r="{r}" fill="{white}"/><circle cx="{x+dx}" cy="{y+dy}" r="{r*0.47:.1f}" fill="{pupil}"/>'
                   for x in (128 - gap, 128 + gap))

def dots(col, y=184, r=10, gap=21):
    return f'<circle cx="{128-gap}" cy="{y}" r="{r}" fill="{col}"/><circle cx="{128+gap}" cy="{y}" r="{r}" fill="{col}"/>'

def smile(col, y=214, w=14, width=7):
    return f'<path d="M{128-w} {y} Q128 {y+12} {128+w} {y}" fill="none" stroke="{col}" stroke-width="{width}" stroke-linecap="round"/>'

def blush(col, y=204, gap=48):
    return f'<ellipse cx="{128-gap}" cy="{y}" rx="11" ry="6.5" fill="{col}" opacity=".85"/><ellipse cx="{128+gap}" cy="{y}" rx="11" ry="6.5" fill="{col}" opacity=".85"/>'

def bow(col, knot=None, y=130):
    k = knot or col
    return (f'<path fill="{col}" d="M128 {y} C110 {y-18} 88 {y-20} 86 {y-4} C84 {y+12} 108 {y+12} 128 {y} Z'
            f' M128 {y} C146 {y-18} 168 {y-20} 170 {y-4} C172 {y+12} 148 {y+12} 128 {y} Z"/><circle cx="128" cy="{y}" r="9" fill="{k}"/>')

def hands(col, edge):
    # Paws straddle the narrower head's sides (r=80, x 48..208), so they read as gripping the bottom edge.
    return "".join(f'<rect x="{x-17}" y="226" width="34" height="40" rx="15" fill="{col}" stroke="{edge}" stroke-width="6"/>' for x in (56, 200))

items = [
    ("googly-butter", tile(BUTTER, dome(INK) + googly("#FFFFFF", INK) + smile("#FFFFFF")), "Googly", "White eyes glancing up, a small smile. Curious, not robotic."),
    ("bow-paper", tile(PAPER, dome(INK) + bow(RED) + googly("#FFFFFF", INK) + smile("#FFFFFF")), "Red bow", "Tie a string to remember: Remy wears the reminder."),
    ("bow-butter", tile(BUTTER, dome(INK) + bow(RED) + dots("#FFFFFF") + smile("#FFFFFF")), "Bow · dot eyes", "The bow with simple dot eyes."),
    ("hands-butter", tile(BUTTER, dome(INK, cy=234, r=80) + googly("#FFFFFF", INK, y=190, r=16, gap=19) + smile("#FFFFFF", y=218, w=11, width=6) + hands(INK, BUTTER)), "Hands", "Little hands grip the edge: peeking over the wall."),
    ("light-night", tile(NIGHT, dome(CREAM) + dots(INK) + smile(INK) + blush(CORAL)), "Light Remy", "A light body on a dark tile, dot eyes, rosy cheeks."),
    ("coral-cream", tile(CREAM, dome(CORAL) + dots(INK) + smile(INK) + blush("#D9604A")), "Coral body", "A warm coral Remy on cream."),
    ("patch", tile(BUTTER, dome(INK) + f'<ellipse cx="128" cy="200" rx="64" ry="50" fill="{CREAM}"/>' + dots(INK, y=190, r=9, gap=20) + smile(INK, y=212, w=12, width=6)), "Face patch", "A dark body with a light face: a little critter."),
    ("curl", tile(MINT, dome(INK) + f'<path d="M128 130 C126 108 144 100 152 110 C160 120 146 128 140 118" fill="none" stroke="{INK}" stroke-width="9" stroke-linecap="round"/>' + googly("#FFFFFF", INK) + smile("#FFFFFF")), "Curl", "One curl of hair: instant personality."),
    ("sprout", tile(MINT, dome(INK) + f'<path d="M128 130 V112" stroke="{INK}" stroke-width="8" stroke-linecap="round"/><path fill="{INK}" d="M128 116 C114 116 104 106 104 94 C118 94 128 102 128 116 Z M128 112 C130 98 142 88 156 88 C156 102 146 112 128 112 Z"/>' + dots("#FFFFFF") + smile("#FFFFFF")), "Sprout", "A sprout on its head: it grows on its day."),
    ("side", tile(BUTTER, f'<circle cx="236" cy="160" r="94" fill="{INK}"/>' + "".join(f'<circle cx="{x}" cy="136" r="17" fill="#FFFFFF"/><circle cx="{x-6}" cy="132" r="8" fill="{INK}"/>' for x in (176, 210)) + f'<path d="M184 178 Q196 188 208 178" fill="none" stroke="#FFFFFF" stroke-width="7" stroke-linecap="round"/>'), "Side peek", "Remy leans in from the side to check on you."),
    ("sleepy-lilac", tile(LILAC, dome(INK) + "".join(f'<path d="M{x-15} 182 A15 15 0 0 0 {x+15} 182 Z" fill="#FFFFFF"/>' for x in (106, 150)) + bow(RED, y=130)), "Sleepy", "Half-closed eyes: resting until the day comes."),
    ("oh-sky", tile(SKY, dome(INK) + googly("#FFFFFF", INK, dx=0, dy=-8) + f'<circle cx="128" cy="216" r="8" fill="none" stroke="#FFFFFF" stroke-width="6"/>'), "Oh!", "A little “oh!”: it’s due today."),
    ("googly-paper", tile(PAPER, dome(INK) + googly("#FFFFFF", INK) + smile("#FFFFFF") + blush(CORAL, y=206, gap=56)), "Googly · blush", "Paper tile, googly eyes, rosy cheeks."),
    ("cream-coral", tile(CORAL, dome(CREAM) + googly("#FFFFFF", INK).replace('fill="#FFFFFF"', f'fill="{INK}"').replace(f'r="8.9" fill="{INK}"', 'r="8.9" fill="#FFFFFF"') + smile(INK)), "Cream on coral", "Light body, dark eyes with a sparkle."),
    ("bow-night", tile(NIGHT, dome(CREAM) + bow(RED) + dots(INK) + smile(INK)), "Bow · night", "Light Remy with the red bow on a dark tile."),
    ("hands-bow", tile(PAPER, dome(INK, cy=234, r=80) + bow(RED, y=154) + googly("#FFFFFF", INK, y=190, r=16, gap=19) + smile("#FFFFFF", y=218, w=11, width=6) + hands(INK, PAPER)), "Bow + hands", "Everything: the bow, the hands, the glance."),
]
for f, svg, *_ in items:
    open(f"{f}.svg", "w").write(svg)
cells = "".join(f'<div class="c"><img class="big" src="{f}.svg"><div class="sm"><img src="{f}.svg" width="40"><img src="{f}.svg" width="24"><img src="{f}.svg" width="16"></div><b>{i+1:02d} · {n}</b><p>{d}</p></div>'
                for i, (f, _, n, d) in enumerate(items))
open("board.html", "w").write('''<!doctype html><meta charset="utf-8"><style>
body{margin:0;padding:40px 44px;background:#EDEDEA;font:13px -apple-system,system-ui;color:#1b1b1b}
h1{font-size:26px;margin:0 0 4px;letter-spacing:-.4px} .sub{color:#777;margin:0 0 22px}
.g{display:grid;grid-template-columns:repeat(4,1fr);gap:16px}
.c{background:#fff;border-radius:16px;padding:18px} .big{width:150px;height:150px;display:block;margin:0 auto 12px}
.sm{display:flex;align-items:flex-end;justify-content:center;gap:10px;margin-bottom:10px;height:40px}
b{font-size:14px} p{margin:3px 0 0;color:#777;line-height:1.35;font-size:12px}</style>
<h1>Remy · Peek, round 3</h1><p class="sub">Same idea, less bot: expressive eyes, a mouth, and one ownable detail each. 150 / 40 / 24 / 16 px.</p><div class="g">''' + cells + "</div>")
