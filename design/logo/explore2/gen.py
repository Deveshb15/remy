# Generates the full Remy icon exploration (SVG tiles) + board.html.
INK, PAPER = "#141414", "#F4F3EF"
PALETTE = {"paper": PAPER, "butter": "#F6D66B", "night": "#16161A", "coral": "#F28B6E", "mint": "#9FD9BF",
           "sky": "#9CC8F2", "lilac": "#C7B8F0", "cream": "#FBF4E4", "red": "#E5484D"}

def tile(bg, body):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256" width="256" height="256">'
            f'<defs><clipPath id="t"><rect width="256" height="256" rx="57"/></clipPath></defs>'
            f'<rect width="256" height="256" rx="57" fill="{bg}"/><g clip-path="url(#t)">{body}</g></svg>')

def capsule(x, y, w=20, h=32):
    r = w / 2
    return f"M{x} {y+r} A{r} {r} 0 0 1 {x+w} {y+r} V{y+h-r} A{r} {r} 0 0 1 {x} {y+h-r} Z"

HEAD = "M30 256 V226 A98 98 0 0 1 226 226 V256 Z"
def peek(bg, ink, eyes="capsule", extra="", eye_col=None):
    eye_col = eye_col or bg
    if eyes == "capsule":
        return tile(bg, f'<path fill="{ink}" fill-rule="evenodd" d="{HEAD} {capsule(122,160,20,32)} {capsule(164,160,20,32)}"/>{extra}')
    if eyes == "wide":
        return tile(bg, f'<path fill="{ink}" fill-rule="evenodd" d="{HEAD} {capsule(112,150,26,42)} {capsule(160,150,26,42)}"/>{extra}')
    if eyes == "dots":
        return tile(bg, f'<path fill="{ink}" d="{HEAD}"/><circle cx="132" cy="178" r="13" fill="{eye_col}"/><circle cx="174" cy="178" r="13" fill="{eye_col}"/>{extra}')
    if eyes == "blink":
        return tile(bg, f'<path fill="{ink}" d="{HEAD}"/><path d="M120 180 Q132 166 144 180 M162 180 Q174 166 186 180" fill="none" stroke="{eye_col}" stroke-width="9" stroke-linecap="round"/>{extra}')
    if eyes == "wink":
        return tile(bg, f'<path fill="{ink}" fill-rule="evenodd" d="{HEAD} {capsule(164,160,20,32)}"/><path d="M120 180 Q132 166 144 180" fill="none" stroke="{eye_col}" stroke-width="9" stroke-linecap="round"/>{extra}')

def checkface(bg, ink, face="disc", eye_col=None):
    eye_col = eye_col or bg
    eyes = f'<rect x="98" y="88" width="16" height="30" rx="8" fill="{eye_col}"/><rect x="142" y="88" width="16" height="30" rx="8" fill="{eye_col}"/>'
    smile = f'<path d="M96 148 L116 166 L162 132" fill="none" stroke="{eye_col}" stroke-width="14" stroke-linecap="round" stroke-linejoin="round"/>'
    if face == "disc":
        return tile(bg, f'<circle cx="128" cy="128" r="88" fill="{ink}"/>{eyes}{smile}')
    if face == "ring":
        return tile(bg, f'<circle cx="128" cy="128" r="80" fill="none" stroke="{ink}" stroke-width="16"/>'
                        + eyes.replace(eye_col, ink) + smile.replace(eye_col, ink))
    if face == "wink":
        return tile(bg, f'<circle cx="128" cy="128" r="88" fill="{ink}"/><path d="M96 106 Q106 94 116 106" fill="none" stroke="{eye_col}" stroke-width="9" stroke-linecap="round"/>'
                        f'<rect x="142" y="88" width="16" height="30" rx="8" fill="{eye_col}"/>{smile}')

R = '<path d="M60 52 V204"/><path d="M60 52 H116 A46 46 0 0 1 116 144 H60"/>'
def rmark(bg, ink, variant):
    g = f'<g transform="translate(38 38) scale(0.703)" fill="none" stroke="{ink}" stroke-width="30" stroke-linecap="round" stroke-linejoin="round">'
    if variant == "check":
        return tile(bg, g + R + '<path d="M100 144 L144 188 L196 136"/></g>')
    if variant == "eye":
        return tile(bg, g + R + '<path d="M100 144 L156 204"/></g>' + f'<circle cx="114" cy="107" r="9" fill="{ink}"/>')
    if variant == "dot":
        return tile(bg, g + R + '<path d="M100 144 L156 204"/></g>' + f'<circle cx="186" cy="182" r="14" fill="{PALETTE["red"]}"/>')
    if variant == "lower":  # lowercase r as a little character: shoulder is a head with an eye
        return tile(bg, f'<g fill="none" stroke="{ink}" stroke-width="26" stroke-linecap="round"><path d="M92 104 V196"/>'
                        f'<path d="M92 150 C92 112 120 96 150 96 C168 96 180 104 186 112"/></g><circle cx="150" cy="128" r="9" fill="{ink}"/>')

def other(name, bg=PAPER, ink=INK):
    bodies = {
        "daybuddy": f'<g transform="translate(38 36) scale(0.703)"><rect x="52" y="72" width="152" height="140" rx="36" fill="none" stroke="{ink}" stroke-width="24"/><rect x="86" y="40" width="22" height="50" rx="11" fill="{ink}"/><rect x="148" y="40" width="22" height="50" rx="11" fill="{ink}"/><path d="M98 150 Q128 180 158 150" fill="none" stroke="{ink}" stroke-width="20" stroke-linecap="round"/></g>',
        "bubblebuddy": f'<path fill="{ink}" fill-rule="evenodd" d="M84 60 H172 A28 28 0 0 1 200 88 V150 A28 28 0 0 1 172 178 H118 L88 206 V178 H84 A28 28 0 0 1 56 150 V88 A28 28 0 0 1 84 60 Z {capsule(102,100,18,30)} {capsule(140,100,18,30)}"/>',
        "widgetbuddy": f'<rect x="66" y="58" width="140" height="120" rx="28" fill="{ink}" opacity=".22"/><path fill="{ink}" fill-rule="evenodd" d="M78 82 H174 A28 28 0 0 1 202 110 V170 A28 28 0 0 1 174 198 H78 A28 28 0 0 1 50 170 V110 A28 28 0 0 1 78 82 Z {capsule(100,118,18,30)} {capsule(136,118,18,30)}"/>',
        "ping": f'<circle cx="128" cy="128" r="28" fill="{ink}"/><circle cx="128" cy="128" r="58" fill="none" stroke="{ink}" stroke-width="10" opacity=".45"/><circle cx="128" cy="128" r="88" fill="none" stroke="{ink}" stroke-width="10" opacity=".18"/>',
        "sunrise": f'<path fill="{ink}" d="M60 178 A68 68 0 0 1 196 178 Z"/><rect x="40" y="190" width="176" height="12" rx="6" fill="{ink}"/><g stroke="{ink}" stroke-width="12" stroke-linecap="round"><path d="M128 62 V82"/><path d="M60 92 L74 106"/><path d="M196 92 L182 106"/></g>',
        "moon": f'<path fill="{ink}" d="M150 52 A80 80 0 1 0 204 164 A64 64 0 1 1 150 52 Z"/><circle cx="182" cy="84" r="10" fill="{ink}"/>',
        "plane": f'<path fill="{ink}" d="M48 132 L204 60 L156 200 L128 152 Z"/><path fill="{bg}" d="M128 152 L204 60 L140 146 Z" opacity=".55"/>',
        "sprout": f'<rect x="52" y="182" width="152" height="12" rx="6" fill="{ink}"/><path d="M128 182 V118" stroke="{ink}" stroke-width="12" stroke-linecap="round"/><path fill="{ink}" d="M128 138 C102 138 84 120 84 96 C108 96 128 112 128 138 Z M128 122 C130 92 152 72 182 72 C182 102 160 122 128 122 Z"/>',
        "note": f'<path fill="{ink}" fill-rule="evenodd" d="M84 56 H170 L200 86 V148 A28 28 0 0 1 172 176 H114 L84 206 V176 A28 28 0 0 1 56 148 V84 A28 28 0 0 1 84 56 Z M98 104 A12 12 0 1 0 98 128 A12 12 0 1 0 98 104 Z M124 110 H166 A6 6 0 0 1 166 122 H124 A6 6 0 0 1 124 110 Z"/>',
        "bookmark": f'<path fill="{ink}" fill-rule="evenodd" d="M86 40 H170 A6 6 0 0 1 176 46 V214 L128 178 L80 214 V46 A6 6 0 0 1 86 40 Z M128 86 A18 18 0 1 0 128 122 A18 18 0 1 0 128 86 Z"/>',
        "nowlater": f'<path fill="{ink}" d="M128 44 A84 84 0 0 0 128 212 Z"/><path d="M128 50 A78 78 0 0 1 128 206" fill="none" stroke="{ink}" stroke-width="12"/>',
        "knot": f'<path d="M64 196 C96 168 116 140 128 112 C142 80 176 72 184 100 C192 128 152 140 128 112 C104 84 80 96 76 120" fill="none" stroke="{ink}" stroke-width="16" stroke-linecap="round"/>',
    }
    return tile(bg, bodies[name])

P = PALETTE
items = [
  # Peek family
  ("peek-paper", peek(P["paper"], INK), "Peek · paper", "The original: ink Remy on paper white."),
  ("peek-butter", peek(P["butter"], "#1B1A17"), "Peek · butter", "One warm brand color."),
  ("peek-night", peek(P["night"], "#F2F1EC"), "Peek · night", "Dark tile, light Remy."),
  ("peek-coral", peek(P["coral"], "#1B1A17"), "Peek · coral", "Warmer, more energetic."),
  ("peek-mint", peek(P["mint"], "#14231C"), "Peek · mint", "Calm and fresh."),
  ("peek-sky", peek(P["sky"], "#10202E"), "Peek · sky", "Soft, open, trusted."),
  ("peek-lilac", peek(P["lilac"], "#1C1630"), "Peek · lilac", "Gentle, a little dreamy."),
  ("peek-wide", peek(P["butter"], "#1B1A17", "wide"), "Peek · curious", "Bigger eyes: alert and attentive."),
  ("peek-dots", peek(P["cream"], INK, "dots", eye_col="#FFFFFF"), "Peek · round eyes", "Classic round eyes, softer."),
  ("peek-blink", peek(P["butter"], "#1B1A17", "blink"), "Peek · content", "Happy closed eyes: “I’ve got it.”"),
  ("peek-wink", peek(P["paper"], INK, "wink"), "Peek · wink", "A wink, playful."),
  ("peek-blush", peek(P["butter"], "#1B1A17", "capsule", extra='<ellipse cx="104" cy="206" rx="12" ry="7" fill="#F28B6E"/><ellipse cx="200" cy="206" rx="12" ry="7" fill="#F28B6E"/>'), "Peek · blush", "Rosy cheeks: extra friendly."),
  # Check smile family
  ("smile-paper", checkface(P["paper"], INK), "Check smile", "A face whose smile is a check."),
  ("smile-butter", checkface(P["butter"], "#1B1A17"), "Check smile · butter", "The same smile, warm tile."),
  ("smile-coral", checkface(P["coral"], "#1B1A17"), "Check smile · coral", "More energy."),
  ("smile-ring", checkface(P["paper"], INK, "ring"), "Check smile · line", "Outline version: lighter."),
  ("smile-wink", checkface(P["sky"], "#10202E", "wink"), "Check smile · wink", "Winking, playful."),
  ("smile-night", checkface(P["night"], "#F2F1EC"), "Check smile · night", "Dark mode."),
  # R family
  ("r-check", rmark(P["paper"], INK, "check"), "R · check", "R whose leg becomes a check."),
  ("r-eye", rmark(P["butter"], "#1B1A17", "eye"), "R · eye", "An R that looks back at you."),
  ("r-dot", rmark(P["paper"], INK, "dot"), "R · red dot", "R plus a red “due” dot."),
  ("r-lower", rmark(P["butter"], "#1B1A17", "lower"), "r · character", "Lowercase r as a little character."),
  # Other ideas
  ("bubblebuddy", other("bubblebuddy"), "Bubble buddy", "A speech bubble with eyes: you talk, Remy listens."),
  ("widgetbuddy", other("widgetbuddy", P["butter"], "#1B1A17"), "Widget buddy", "A stacked widget card with a face."),
  ("daybuddy", other("daybuddy"), "Day buddy", "A calendar with ears and a smile."),
  ("ping", other("ping"), "Ping", "A gentle notification ripple."),
  ("sunrise", other("sunrise", P["cream"]), "Sunrise", "It comes up on its day."),
  ("moon", other("moon", P["night"], "#F2F1EC"), "Later", "Moon and star: saved for later."),
  ("plane", other("plane", P["sky"], "#10202E"), "Sent", "Your agent sends it, it lands."),
  ("sprout", other("sprout"), "Sprout", "A seed that sprouts on its day."),
  ("note", other("note"), "Note bubble", "You say it, it becomes a note."),
  ("knot", other("knot"), "Knot", "The string-on-your-finger reminder."),
  ("bookmark", other("bookmark"), "Bookmark", "A ribbon that marks the day."),
  ("nowlater", other("nowlater"), "Now & later", "Half now, half waiting."),
]
for f, svg, *_ in items:
    open(f"{f}.svg", "w").write(svg)

groups = [("Peek", 0, 12), ("Check smile", 12, 18), ("R lettermark", 18, 22), ("Other ideas", 22, len(items))]
html = []
n = 0
for title, a, b in groups:
    html.append(f'<h2>{title}</h2><div class="g">')
    for f, _, name, note in items[a:b]:
        n += 1
        html.append(f'<div class="c"><img class="big" src="{f}.svg"><div class="sm"><img src="{f}.svg" width="40"><img src="{f}.svg" width="24"><img src="{f}.svg" width="16"></div><b>{n:02d} · {name}</b><p>{note}</p></div>')
    html.append('</div>')
open("board.html", "w").write('''<!doctype html><meta charset="utf-8"><style>
body{margin:0;padding:40px 44px;background:#EDEDEA;font:13px -apple-system,system-ui;color:#1b1b1b}
h1{font-size:26px;margin:0 0 4px;letter-spacing:-.4px} .sub{color:#777;margin:0 0 6px} h2{font-size:16px;margin:26px 0 12px;color:#444}
.g{display:grid;grid-template-columns:repeat(6,1fr);gap:14px}
.c{background:#fff;border-radius:16px;padding:16px} .big{width:112px;height:112px;display:block;margin:0 auto 10px}
.sm{display:flex;align-items:flex-end;justify-content:center;gap:10px;margin-bottom:10px;height:40px}
b{font-size:13px} p{margin:3px 0 0;color:#777;line-height:1.3;font-size:12px}</style>
<h1>Remy · every icon exploration</h1><p class="sub">34 directions, each at 112, 40, 24, and 16 px. Pick by number, or remix (“14 with 08’s eyes”).</p>''' + "".join(html))
print(len(items), "icons")
