#!/usr/bin/env python3
"""Gemeinsame Bausteine der ASC-Skripte (Issue #175, B2a): Textdateien lesen, ES256-Token, eingehegter API-Aufruf.
Der Schlüssel wird nie von Python gelesen, sein Pfad geht nur als Argument an openssl. Fehler nennen Status, Pfad und Apples code/title (nie detail/id/source)."""
import base64, json, re, subprocess, time, unicodedata, urllib.error, urllib.request
from pathlib import Path

HOST = "https://api.appstoreconnect.apple.com"
BUNDLE = "com.johannesemmrich.Restock"
_ID = r"[A-Za-z0-9_-]+"
_LOCS = r"/v1/(?:appStoreVersionLocalizations|appInfoLocalizations)"
VERSION_QUERY = "filter[versionString]=1.0&filter[platform]=IOS"
ALLOWED = {  # Methode -> erlaubte Pfadmuster (Teil vor "?"), AC-10a
    "GET": [rf"/v1/apps/{_ID}/(?:appStoreVersions|appInfos)",
            rf"/v1/appStoreVersions/{_ID}/appStoreVersionLocalizations",
            rf"/v1/appInfos/{_ID}/appInfoLocalizations"],
    "POST": [_LOCS],
    "PATCH": [rf"{_LOCS}/{_ID}"],
}


def parse_texts(path):
    parts = re.split(r"^## (.+)$", Path(path).read_text(encoding="utf-8"), flags=re.M)
    return {parts[i].strip(): parts[i + 1].strip() for i in range(1, len(parts), 2)}


def b64url(raw):
    return base64.urlsafe_b64encode(raw).rstrip(b"=").decode()


def der_to_raw(der_bytes):
    """DER-Signatur (SEQUENCE aus zwei INTEGER) nach R‖S mit je 32 Byte."""
    i, out = 2 if der_bytes[1] < 0x80 else 2 + (der_bytes[1] & 0x7F), b""
    for _ in range(2):
        if der_bytes[i] != 0x02:
            raise ValueError("Signatur ist kein DER-INTEGER-Paar")
        n = der_bytes[i + 1]
        out += int.from_bytes(der_bytes[i + 2:i + 2 + n], "big").to_bytes(32, "big")
        i += 2 + n
    return out


def openssl_sign(data, key_path):
    try:
        return subprocess.run(["openssl", "dgst", "-sha256", "-sign", key_path], input=data,
                              capture_output=True, check=True).stdout
    except subprocess.CalledProcessError as e:  # Meldung ohne Befehlszeile, sie enthielte den Schlüsselpfad
        raise RuntimeError(f"openssl-Signatur fehlgeschlagen (Exit {e.returncode})") from None


def make_token(env, sign=openssl_sign, now=None):
    missing = [k for k in ("ASC_KEY_ID", "ASC_ISSUER_ID", "ASC_KEY_PATH") if not env.get(k)]
    if missing:
        raise RuntimeError("Umgebungsvariable fehlt: " + ", ".join(missing))
    iat = int(time.time() if now is None else now)
    head = {"alg": "ES256", "kid": env["ASC_KEY_ID"], "typ": "JWT"}
    claims = {"iss": env["ASC_ISSUER_ID"], "aud": "appstoreconnect-v1", "iat": iat, "exp": iat + 1200}
    signing_input = ".".join(b64url(json.dumps(x, separators=(",", ":")).encode()) for x in (head, claims))
    return signing_input + "." + b64url(der_to_raw(sign(signing_input.encode(), env["ASC_KEY_PATH"])))


class NoRedirect(urllib.request.HTTPRedirectHandler):
    """3xx nie verfolgen, sonst ginge der Bearer-Token mit zum Ziel der Weiterleitung."""

    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


OPENER = urllib.request.build_opener(urllib.request.ProxyHandler({}), NoRedirect())


def urllib_send(method, url, headers, data, opener=OPENER):
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with opener.open(req, timeout=60) as resp:
            return resp.status, resp.read()
    except urllib.error.HTTPError as e:
        try:  # Fehlerkörper höchstens 64 KiB, Lesefehler = leer (Issue #227, AC-8)
            raw = e.read(65536) or b""
        except Exception:
            raw = b""
        finally:
            e.close()
        return e.code, raw


_STRIP = {"Cc", "Cf", "Cs", "Zl", "Zp"}  # Steuer-, Format-/Bidi-, Surrogat- und Zeilen-/Absatztrenner (F001)


def apple_error_suffix(raw):
    """Zusatz aus Apples JSON:API-Fehlern: nur code und title, je 80 Zeichen, ohne Steuerzeichen, höchstens 3 Fehler.
    Nie detail, id oder source; ungültige Eingabe ergibt "" und nie eine Ausnahme (Issue #227, AC-1 bis AC-5)."""
    try:
        errors = json.loads(raw).get("errors")
    except Exception:
        return ""
    parts = []
    for err in errors[:3] if isinstance(errors, list) else []:
        if not isinstance(err, dict):
            continue
        code, title = ("".join(c for c in v if unicodedata.category(c) not in _STRIP)[:80] if isinstance(v, str) else ""
                       for v in (err.get("code"), err.get("title")))
        if code or title:
            parts.append(": ".join(x for x in (code, title) if x))
    return " — " + "; ".join(parts) if parts else ""


def check_path(method, path):
    if method not in ALLOWED:
        raise ValueError(f"Methode nicht erlaubt: {method}")
    if not isinstance(path, str) or not path.startswith("/") or path.startswith("//"):
        raise ValueError("Pfad muss relativ zu api.appstoreconnect.apple.com sein")
    base, sep, query = path.partition("?")
    ok = any(re.fullmatch(p, base) for p in ALLOWED[method]) and not sep
    if method == "GET" and sep:  # Abfragen nur exakt wie in der Erlaubnisliste
        ok = (base == "/v1/apps" and query == f"filter[bundleId]={BUNDLE}") or (
            re.fullmatch(rf"/v1/apps/{_ID}/appStoreVersions", base) is not None and query == VERSION_QUERY)
    if not ok:
        raise ValueError(f"Pfad nicht erlaubt: {method} {base}")


def api(method, path, token, send=urllib_send, body=None):
    check_path(method, path)
    headers = {"Authorization": f"Bearer {token}"}
    data = None
    if body is not None:
        headers["Content-Type"] = "application/json"
        data = json.dumps(body).encode()
    status, raw = send(method, HOST + path, headers, data)
    if not 200 <= status < 300:  # auch 3xx: Weiterleitungen werden nie verfolgt
        raise RuntimeError(f"HTTP {status} bei {method} {path.partition('?')[0]}{apple_error_suffix(raw)}")
    return json.loads(raw) if raw else {}
