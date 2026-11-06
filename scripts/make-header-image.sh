#!/usr/bin/env bash
# App-Store-Kopfbild rendern (Issue #241, Spec docs/specs/appstore/kopfbild.md).
#   scripts/make-header-image.sh [de|en]     ohne Argument: beide Sprachen
# Rendert scripts/header-image/kopfbild.html mit Chrome headless in 5244x2950 (16:9) und 3840x1646 (21:9),
# je neu (nicht skaliert/beschnitten), entfernt den Alphakanal (PNG-Farbtyp 2), prüft Pixelmaße, Farbtyp und
# Sicherheitsbereich (Elementrahmen per --dump-dom, dazu Pixelprüfung außerhalb) und bricht bei Abweichung ab.
# Ergebnis: docs/artifacts/feat-241-kopfbild/kopfbild-<lang>-<WxH>.png, render-protokoll.txt,
# und (wenn beide Sprachen vorliegen) zuschnitt-vorschau.png.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEMPLATE="$ROOT/scripts/header-image/kopfbild.html"
CROP_TEMPLATE="$ROOT/scripts/header-image/zuschnitt.html"
STRIP_SRC="$ROOT/scripts/header-image/strip-alpha.swift"
OUT="$ROOT/docs/artifacts/feat-241-kopfbild"
LOG="$OUT/render-protokoll.txt"
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
BG="F5F2E9"   # RCCanvas hell
SIZES="5244x2950 3840x1646"

case "${1:-}" in
  "") LANGS="de en" ;;
  de|en) LANGS="$1" ;;
  *) echo "Aufruf: $0 [de|en]" >&2; exit 2 ;;
esac

[ -x "$CHROME" ] || { echo "Chrome fehlt: $CHROME" >&2; exit 1; }
mkdir -p "$OUT"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/kopfbild.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

swiftc -O -o "$WORK/strip-alpha" "$STRIP_SRC" 2>"$WORK/swiftc.log" || { cat "$WORK/swiftc.log" >&2; exit 1; }

chrome() {
  # Eigenes Profil, damit ein laufendes Chrome des Nutzers nicht berührt wird.
  "$CHROME" --headless=new --disable-gpu --no-first-run --no-default-browser-check \
    --user-data-dir="$WORK/profile" --force-device-scale-factor=1 --hide-scrollbars \
    --run-all-compositor-stages-before-draw --virtual-time-budget=5000 "$@" 2>>"$WORK/chrome.log"
}

png_check() { # Datei → "WxH farbtyp tRNS"
  python3 -I - "$1" <<'PY'
import struct, sys
raw = open(sys.argv[1], "rb").read()
assert raw[:8] == b"\x89PNG\r\n\x1a\n", "kein PNG"
w, h, _d, ct = struct.unpack(">IIBB", raw[16:26])
print(f"{w}x{h} {ct} {'ja' if b'tRNS' in raw else 'nein'}")
PY
}

{
  echo "Kopfbild-Renderprotokoll (Issue #241)"
  echo "Zeit (UTC): $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "Commit: $(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo unbekannt)"
  echo "Chrome: $("$CHROME" --version 2>/dev/null)"
  echo "Vorlage: scripts/header-image/kopfbild.html"
  echo "Sicherheitsbereich: mittlere 84 % Breite, mittlere 76 % Höhe (Spec AC-5)"
  echo
} > "$LOG"

for lang in $LANGS; do
  for size in $SIZES; do
    w="${size%x*}"; h="${size#*x}"
    url="file://$TEMPLATE?lang=$lang&w=$w&h=$h"
    name="kopfbild-$lang-$size.png"
    echo "== $name" | tee -a "$LOG"

    # 1. Rendern
    rm -f "$WORK/raw.png"
    chrome --screenshot="$WORK/raw.png" --window-size="$w,$h" --default-background-color="${BG}FF" "$url" >/dev/null
    [ -s "$WORK/raw.png" ] || { echo "Rendern fehlgeschlagen ($name)" | tee -a "$LOG" >&2; cat "$WORK/chrome.log" >&2; exit 1; }
    sw="$(sips -g pixelWidth "$WORK/raw.png" | awk '/pixelWidth/{print $2}')"
    sh="$(sips -g pixelHeight "$WORK/raw.png" | awk '/pixelHeight/{print $2}')"
    echo "  Chrome-Screenshot: ${sw}x${sh}, Farbtyp/tRNS: $(png_check "$WORK/raw.png" | cut -d' ' -f2-)" | tee -a "$LOG"
    [ "${sw}x${sh}" = "$size" ] || { echo "  ABBRUCH: Maße ${sw}x${sh} statt $size" | tee -a "$LOG" >&2; exit 1; }

    # 2. Alphakanal entfernen + Pixelprüfung außerhalb des Sicherheitsbereichs
    pix="$("$WORK/strip-alpha" "$WORK/raw.png" "$OUT/$name" "$BG")"
    echo "  Pixelprüfung: $pix" | tee -a "$LOG"
    case "$pix" in *" outside_non_bg=0 "*) ;; *) echo "  ABBRUCH: außerhalb des Sicherheitsbereichs nicht nur Hintergrund" | tee -a "$LOG" >&2; exit 1 ;; esac
    case "$pix" in *" corner=$BG "*) ;; *) echo "  ABBRUCH: Ecke ist nicht die Hintergrundfarbe #$BG" | tee -a "$LOG" >&2; exit 1 ;; esac

    # 3. Ergebnis prüfen: Maße, Farbtyp 2 (RGB ohne Alpha), kein tRNS
    res="$(png_check "$OUT/$name")"
    echo "  Ergebnis: $res (Maße, PNG-Farbtyp, tRNS)" | tee -a "$LOG"
    [ "$res" = "$size 2 nein" ] || { echo "  ABBRUCH: erwartet '$size 2 nein'" | tee -a "$LOG" >&2; exit 1; }

    # 4. Elementrahmen im gerenderten Dokument messen (AC-5)
    chrome --dump-dom --window-size="$w,$h" "$url&measure=1" > "$WORK/dom.html"
    set +e
    python3 -I - "$WORK/dom.html" "$lang" "$w" "$h" > "$WORK/measure.txt" <<'PY'
import html, json, re, sys
dom = open(sys.argv[1], encoding="utf-8").read()
m = re.search(r'<pre id="measure">(.*?)</pre>', dom, re.S)
if not m or not m.group(1).strip():
    print("  ABBRUCH: keine Messung im DOM"); sys.exit(1)
d = json.loads(html.unescape(m.group(1)))
s = d["safe"]
print(f"  DOM-Messung: Bildfläche {d['viewport'][0]:.0f}x{d['viewport'][1]:.0f} (Fenster {d['window'][0]}x{d['window'][1]}), Sicherheitsbereich x {s['left']:.0f}..{s['right']:.0f}, "
      f"y {s['top']:.0f}..{s['bottom']:.0f}, {len(d['items'])} Elemente, außerhalb: {len(d['outside'])}, Symbol geladen: {d['iconLoaded']}")
xs = [i["left"] for i in d["items"]] + [i["right"] for i in d["items"]]
ys = [i["top"] for i in d["items"]] + [i["bottom"] for i in d["items"]]
print(f"  Inhaltsrahmen gesamt: x {min(xs):.0f}..{max(xs):.0f}, y {min(ys):.0f}..{max(ys):.0f} "
      f"(Abstand zum Bereich: links {min(xs)-s['left']:.0f}, rechts {s['right']-max(xs):.0f}, oben {min(ys)-s['top']:.0f}, unten {s['bottom']-max(ys):.0f} px)")
for i in d["outside"]:
    print(f"    außerhalb: {i['el']} „{i['text']}“ {i['left']:.0f},{i['top']:.0f}–{i['right']:.0f},{i['bottom']:.0f}")
print("  Sichtbarer Text: " + " | ".join(l.strip() for l in d["textLines"].splitlines() if l.strip()))
if d["outside"] or not d["iconLoaded"] or list(d["viewport"]) != [int(sys.argv[3]), int(sys.argv[4])]:
    sys.exit(1)
PY
    rc=$?
    set -e
    tee -a "$LOG" < "$WORK/measure.txt"
    [ "$rc" -eq 0 ] || { echo "  ABBRUCH: Messung fehlgeschlagen ($name)" | tee -a "$LOG" >&2; exit 1; }
    echo "  ok" | tee -a "$LOG"
  done
done

# Zuschnitt-Vorschau (AC-6), sobald beide 16:9-Fassungen vorliegen
if [ -f "$OUT/kopfbild-de-5244x2950.png" ] && [ -f "$OUT/kopfbild-en-5244x2950.png" ]; then
  chrome --screenshot="$WORK/crop.png" --window-size=2400,1640 "file://$CROP_TEMPLATE" >/dev/null
  "$WORK/strip-alpha" "$WORK/crop.png" "$OUT/zuschnitt-vorschau.png" "$BG" >/dev/null
  echo "Zuschnitt-Vorschau: docs/artifacts/feat-241-kopfbild/zuschnitt-vorschau.png ($(png_check "$OUT/zuschnitt-vorschau.png"))" | tee -a "$LOG"
fi
echo "Fertig: alle Prüfungen bestanden." | tee -a "$LOG"
