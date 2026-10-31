#!/usr/bin/env python3
"""Maintain appcast.xml, the Sparkle update feed served from the repo root.

  appcast.py add --version 0.1.2 --build 3 --notes notes.md --signature SIG --length N [--beta] [--critical] [--phased-hours H]
  appcast.py promote --version 0.1.2     # beta -> everyone
  appcast.py --selftest

Items are inserted newest-first after the ITEMS marker; the file is otherwise left untouched.
"""
import argparse, html, re, sys
from email.utils import formatdate
from pathlib import Path

REPO = "Deveshb15/remy"
MIN_MACOS = "26.0.0"
MARKER = "<!-- ITEMS (newest first; written by scripts/appcast.py) -->"
TEMPLATE = f"""<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>Remy</title>
    <link>https://github.com/{REPO}</link>
    <description>Remy updates</description>
    <language>en</language>
    {MARKER}
  </channel>
</rss>
"""

def md_to_html(md: str) -> str:
    """Tiny Markdown subset for release notes: ### headings, - bullets, paragraphs, **bold**, `code`."""
    def inline(s):
        s = html.escape(s, quote=False)
        s = re.sub(r"\*\*(.+?)\*\*", r"<b>\1</b>", s)
        return re.sub(r"`(.+?)`", r"<code>\1</code>", s)
    out, in_list = [], False
    for line in md.splitlines():
        line = line.rstrip()
        if line.startswith("- "):
            if not in_list: out.append("<ul>"); in_list = True
            out.append(f"<li>{inline(line[2:])}</li>")
            continue
        if in_list: out.append("</ul>"); in_list = False
        if line.startswith("### "): out.append(f"<h3>{inline(line[4:])}</h3>")
        elif line: out.append(f"<p>{inline(line)}</p>")
    if in_list: out.append("</ul>")
    return "\n".join(out)

def item(version, build, notes_html, signature, length, beta=False, critical=False, phased_hours=0, date=None):
    extra = []
    if beta: extra.append("<sparkle:channel>beta</sparkle:channel>")
    if critical: extra.append("<sparkle:criticalUpdate></sparkle:criticalUpdate>")
    if phased_hours: extra.append(f"<sparkle:phasedRolloutInterval>{int(phased_hours * 3600)}</sparkle:phasedRolloutInterval>")
    extra = "".join(f"\n      {e}" for e in extra)
    url = f"https://github.com/{REPO}/releases/download/v{version}/Remy.dmg"
    return f"""<item>
      <title>Remy {version}</title>
      <pubDate>{date or formatdate(usegmt=True)}</pubDate>
      <sparkle:version>{build}</sparkle:version>
      <sparkle:shortVersionString>{version}</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>{MIN_MACOS}</sparkle:minimumSystemVersion>{extra}
      <description><![CDATA[{notes_html}]]></description>
      <enclosure url="{url}" sparkle:edSignature="{signature}" length="{length}" type="application/octet-stream"/>
    </item>"""

def add(feed: str, new_item: str, version: str) -> str:
    if f"<sparkle:shortVersionString>{version}</sparkle:shortVersionString>" in feed:
        sys.exit(f"appcast already has {version}")
    if MARKER not in feed:
        sys.exit("appcast.xml is missing the ITEMS marker")
    return feed.replace(MARKER, f"{MARKER}\n    {new_item}", 1)

def promote(feed: str, version: str) -> str:
    pattern = re.compile(r"(<item>(?:(?!</item>).)*?<sparkle:shortVersionString>" + re.escape(version) + r"</sparkle:shortVersionString>.*?</item>)", re.S)
    m = pattern.search(feed)
    if not m: sys.exit(f"appcast has no item for {version}")
    block = re.sub(r"\n\s*<sparkle:channel>beta</sparkle:channel>", "", m.group(1))
    return feed[:m.start()] + block + feed[m.end():]

def selftest():
    feed = TEMPLATE
    feed = add(feed, item("0.1.2", 3, md_to_html("### Fixed\n- **Bold** and `code`"), "SIG==", 123, date="X"), "0.1.2")
    feed = add(feed, item("0.1.3", 4, "<p>b</p>", "SIG2==", 456, beta=True, phased_hours=12, date="Y"), "0.1.3")
    assert feed.index("0.1.3") < feed.index("0.1.2"), "newest first"
    assert "<li><b>Bold</b> and <code>code</code></li>" in feed
    assert "<sparkle:channel>beta</sparkle:channel>" in feed and "<sparkle:phasedRolloutInterval>43200<" in feed
    assert 'url="https://github.com/Deveshb15/remy/releases/download/v0.1.3/Remy.dmg"' in feed
    promoted = promote(feed, "0.1.3")
    assert "<sparkle:channel>" not in promoted and promoted.count("<item>") == 2
    try: add(feed, item("0.1.2", 5, "", "S", 1), "0.1.2"); raise AssertionError("duplicate accepted")
    except SystemExit: pass
    import xml.dom.minidom; xml.dom.minidom.parseString(promoted)  # well-formed
    print("appcast selftest ok")

if __name__ == "__main__":
    if sys.argv[1:] == ["--selftest"]: selftest(); sys.exit()
    ap = argparse.ArgumentParser()
    ap.add_argument("command", choices=["add", "promote"])
    ap.add_argument("--file", default="appcast.xml")
    ap.add_argument("--version", required=True)
    ap.add_argument("--build"); ap.add_argument("--notes"); ap.add_argument("--signature"); ap.add_argument("--length")
    ap.add_argument("--beta", action="store_true"); ap.add_argument("--critical", action="store_true")
    ap.add_argument("--phased-hours", type=float, default=0)
    a = ap.parse_args()
    path = Path(a.file)
    feed = path.read_text() if path.exists() else TEMPLATE
    if a.command == "add":
        notes = md_to_html(Path(a.notes).read_text())
        feed = add(feed, item(a.version, a.build, notes, a.signature, a.length, a.beta, a.critical, a.phased_hours), a.version)
    else:
        feed = promote(feed, a.version)
    path.write_text(feed)
    print(f"{a.command}: {a.version} -> {path}")
