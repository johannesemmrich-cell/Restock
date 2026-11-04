#!/usr/bin/env python3
"""Holt TestFlight-Absturzmeldungen und -berichte aus App Store Connect ab (Issue #242, Schnitt 1).
Nur GET über einen eigenen Lesezaun (asc_lib.ALLOWED bleibt unverändert). Je Meldung `<id>.json` (Attribute wie
geliefert) und, falls vorhanden, `<id>.crash` (logText), Dateien 0600, Ordner 0700. Das Log nennt je Meldung nur
Id, Plattform und Datum, nie E-Mail, Kommentar, Gerät, Berichtstext, Token oder Schlüsselpfad.
Aufruf: asc_crashes.py <zielordner>; Umgebung ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH."""
import json, os, re, sys, time
from pathlib import Path
from urllib.parse import urlsplit

sys.path.insert(0, str(Path(__file__).resolve().parent))  # python3 -I nimmt den Skriptordner nicht in sys.path
from asc_lib import BUNDLE, HOST, apple_error_suffix, make_token, openssl_sign, urllib_send  # noqa: E402

_ID = r"([A-Za-z0-9_-][A-Za-z0-9._-]*)"  # Datei-ID: [A-Za-z0-9._-]+, ohne führenden Punkt (kein "..")
_CURSOR = r"[A-Za-z0-9._~%=-]+"
APP_LOOKUP = f"/v1/apps?filter[bundleId]={BUNDLE}"
LIST_QUERY = re.compile(rf"limit=200(?:&cursor={_CURSOR})?|cursor={_CURSOR}&limit=200")
MAX_PAGES, ATTEMPTS = 50, 5
API_HOST = urlsplit(HOST).netloc


def check_read(method, path, ids):
    """Lesezaun (AC-1, AC-2): nur GET, nur drei Aufrufarten, Abfragen exakt, IDs nur aus früheren Antworten."""
    if method != "GET":
        raise ValueError(f"Methode nicht erlaubt: {method}")
    if not isinstance(path, str) or not path.startswith("/") or path.startswith("//"):
        raise ValueError("Pfad muss relativ zu api.appstoreconnect.apple.com sein")
    if path == APP_LOOKUP:
        return
    base, sep, query = path.partition("?")
    m = re.fullmatch(rf"/v1/apps/{_ID}/betaFeedbackCrashSubmissions", base)
    ok = m is not None and bool(sep) and LIST_QUERY.fullmatch(query) is not None
    if not ok:
        m = re.fullmatch(rf"/v1/betaFeedbackCrashSubmissions/{_ID}/crashLog", base)
        ok = m is not None and not sep
    if not ok:
        raise ValueError(f"Pfad nicht erlaubt: GET {base}")
    if m.group(1) not in ids:
        raise ValueError(f"ID nicht aus einer Antwort: GET {base}")


def safe_field(value):
    """Logfeld (AC-11): nur [A-Za-z0-9._:+-], kein '::', höchstens 64 Zeichen, sonst '?'."""
    if not isinstance(value, str) or not re.fullmatch(r"[A-Za-z0-9._:+-]+", value) or "::" in value:
        return "?"
    return value[:64]


class Reader:
    def __init__(self, token, send, sleep):
        self.token, self.send, self.sleep, self.ids = token, send, sleep, set()

    def get(self, path, missing_ok=False):
        """GET mit Wiederholung bei 5xx, 429 und Netzfehler (AC-8); 404 nur mit missing_ok als None (AC-5)."""
        check_read("GET", path, self.ids)
        shown = path.partition("?")[0]
        for attempt in range(1, ATTEMPTS + 1):
            try:
                status, raw = self.send("GET", HOST + path, {"Authorization": f"Bearer {self.token}"}, None)
            except OSError as e:
                failure = f"Netzfehler ({type(e).__name__}) bei GET {shown}"
            else:
                if 200 <= status < 300:
                    break
                if status == 404 and missing_ok:
                    return None
                failure = f"HTTP {status} bei GET {shown}{apple_error_suffix(raw)}"
                if status != 429 and status < 500:  # andere Fehler sofort (AC-9)
                    raise RuntimeError(failure)
            if attempt == ATTEMPTS:
                raise RuntimeError(failure)
            self.sleep(attempt)
        doc = json.loads(raw) if raw else {}
        items = doc.get("data")
        for x in items if isinstance(items, list) else [items] if isinstance(items, dict) else []:
            if isinstance(x, dict) and isinstance(x.get("id"), str):
                self.ids.add(x["id"])
        return doc


def next_path(link, seen):
    """links.next nur auf demselben Host per https (AC-7); Rückgabe Pfad plus Abfrage."""
    parts = urlsplit(link) if isinstance(link, str) else None
    if parts is None or parts.scheme != "https" or parts.netloc != API_HOST or parts.fragment:
        raise RuntimeError("links.next zeigt nicht auf api.appstoreconnect.apple.com")
    path = parts.path + ("?" + parts.query if parts.query else "")
    if path in seen:
        raise RuntimeError("links.next wiederholt eine schon angefragte Seite")
    return path


def fetch_submissions(rd, app_id):
    path, seen, found = f"/v1/apps/{app_id}/betaFeedbackCrashSubmissions?limit=200", set(), []
    while path:
        if len(seen) >= MAX_PAGES:
            raise RuntimeError(f"mehr als {MAX_PAGES} Seiten")
        seen.add(path)
        doc = rd.get(path)
        found += [x for x in doc.get("data") or [] if isinstance(x, dict)]
        link = (doc.get("links") or {}).get("next")
        path = next_path(link, seen) if link else None
    return found


def write_private(path, text):
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC | os.O_NOFOLLOW, 0o600)
    os.fchmod(fd, 0o600)
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        f.write(text)


def run(target, env, send=urllib_send, sign=openssl_sign, sleep=time.sleep, out=sys.stdout):
    rd = Reader(make_token(env, sign=sign), send, sleep)
    apps = rd.get(APP_LOOKUP).get("data") or []
    if not apps:
        raise RuntimeError("keine App zur Bundle-ID gefunden")
    submissions = fetch_submissions(rd, apps[0]["id"])
    for s in submissions:  # alle IDs prüfen, bevor irgendetwas geschrieben wird (AC-12)
        if not isinstance(s.get("id"), str) or not re.fullmatch(_ID, s["id"]):
            raise RuntimeError("Meldung mit unzulässiger ID")
    target = Path(target)
    target.mkdir(mode=0o700, parents=True, exist_ok=True)
    os.chmod(target, 0o700)
    for s in submissions:
        sid, attrs = s["id"], s.get("attributes") or {}
        write_private(target / f"{sid}.json", json.dumps(attrs, ensure_ascii=False, indent=2))
        doc = rd.get(f"/v1/betaFeedbackCrashSubmissions/{sid}/crashLog", missing_ok=True)
        log = (((doc or {}).get("data") or {}).get("attributes") or {}).get("logText")
        if isinstance(log, str) and log:
            write_private(target / f"{sid}.crash", log)
        print(f"Meldung {safe_field(sid)} {safe_field(attrs.get('devicePlatform'))} {safe_field(attrs.get('createdDate'))}",
              file=out)
    print(f"{len(submissions)} Absturzmeldungen abgeholt" if submissions else "keine Absturzmeldungen", file=out)
    return 0


def main(argv):
    if len(argv) != 1:
        print("Aufruf: asc_crashes.py <zielordner>", file=sys.stderr)
        return 2
    try:
        return run(argv[0], os.environ)
    except Exception as e:  # Meldungen nennen nur Status, Pfad und Apples code/title, nie Token oder Schlüsselpfad
        print(f"Fehler: {e}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
