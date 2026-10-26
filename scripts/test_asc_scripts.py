#!/usr/bin/env python3
"""Sicherheitstest der ASC-Skripte (Issue #175, Durchgang B2a, AC-10 bis AC-10h der Spec
docs/specs/appstore/app-store-auftritt.md). Ohne Netz und ohne Schlüssel: Apple wird durch FakeASC ersetzt,
die Signatur durch fake_sign; nur der openssl-Test erzeugt einen Wegwerf-Schlüssel."""
import ast, base64, builtins, contextlib, importlib, io, json, re, shutil, subprocess, sys, tempfile, unittest
from pathlib import Path
from unittest import mock
from urllib.parse import unquote, urlsplit

R = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(R / "scripts"))
try:
    asc_lib, asc_publish = importlib.import_module("asc_lib"), importlib.import_module("asc_publish")
except ImportError:
    asc_lib = asc_publish = None

APP = "APP-7f3"
ENV = {"ASC_KEY_ID": "TESTKID", "ASC_ISSUER_ID": "iss-0000", "ASC_KEY_PATH": "/geheim/AuthKey_TEST.p8"}
VERSION_FIELDS = {"description": "description", "keywords": "keywords", "promotionalText": "promotional_text",
                  "supportUrl": "support_url"}
INFO_FIELDS = {"name": "name", "subtitle": "subtitle", "privacyPolicyUrl": "privacy_url"}
BAD_WORDS = ("shell=True", "DELETE", "reviewSubmissions", "appStoreVersionSubmissions", "whatsNew")


def own_parse(lang):  # unabhängig von asc_lib, wie check_b1.py
    parts = re.split(r"^## (.+)$", (R / f"docs/appstore/{lang}.md").read_text(encoding="utf-8"), flags=re.M)
    return {parts[i].strip(): parts[i + 1].strip() for i in range(1, len(parts), 2)}


TEXTS = {"de-DE": own_parse("de"), "en-US": own_parse("en")}


def der(r, s):
    enc = lambda n: (lambda b: b"\x02" + bytes([len(b)]) + b)(n.to_bytes((n.bit_length() + 8) // 8, "big"))
    body = enc(r) + enc(s)
    return b"\x30" + bytes([len(body)]) + body


R_INT, S_INT = int("80" + "11" * 31, 16), int("22" * 31, 16)  # r mit Vorzeichen-Null, s kürzer als 32 Byte
FIXED_DER = der(R_INT, S_INT)
fake_sign = lambda data, key_path: FIXED_DER
b64d = lambda s: base64.urlsafe_b64decode(s + "=" * (-len(s) % 4))


def loc(kind, locale, fields, **over):
    return {"id": f"{kind}-{locale}", "type": kind,
            "attributes": {"locale": locale, **{k: TEXTS[locale][f] for k, f in fields.items()}, **over}}


class FakeASC:
    """Spielt die benötigten ASC-Pfade nach, übernimmt PATCH/POST in den eigenen Zustand, zeichnet jeden Aufruf auf."""

    def __init__(self, vstate="PREPARE_FOR_SUBMISSION", istate="PREPARE_FOR_SUBMISSION", versions=None, infos=None,
                 apps=None, vlocs=None, ilocs=None):
        self.apps = [{"id": APP, "type": "apps"}] if apps is None else apps
        self.versions = versions or [{"id": "VER-1", "type": "appStoreVersions",
                                      "attributes": {"versionString": "1.0", "platform": "IOS", "appVersionState": vstate}}]
        self.infos = infos or [{"id": "INFO-1", "type": "appInfos", "attributes": {"state": istate}}]
        self.vlocs = [loc("appStoreVersionLocalizations", l, VERSION_FIELDS) for l in TEXTS] if vlocs is None else vlocs
        self.ilocs = [loc("appInfoLocalizations", l, INFO_FIELDS) for l in TEXTS] if ilocs is None else ilocs
        self.calls, self.ids = [], {APP}

    def __call__(self, method, url, headers, data):
        self.calls.append((method, url, headers, json.loads(data) if data else None))
        p = unquote(urlsplit(url).path)
        routes = {"/v1/apps": self.apps, f"/v1/apps/{APP}/appStoreVersions": self.versions, f"/v1/apps/{APP}/appInfos": self.infos}
        routes.update({f"/v1/appStoreVersions/{v['id']}/appStoreVersionLocalizations": self.vlocs for v in self.versions})
        routes.update({f"/v1/appInfos/{i['id']}/appInfoLocalizations": self.ilocs for i in self.infos})
        if method == "GET":
            if p not in routes:
                return 404, b"{}"
            self.ids |= {x["id"] for x in routes[p]}
            return 200, json.dumps({"data": routes[p]}).encode()
        store = self.vlocs if p.split("/")[2] == "appStoreVersionLocalizations" else self.ilocs
        body = json.loads(data)["data"]
        if method == "PATCH":
            item = next(x for x in store if x["id"] == p.split("/")[3])
            item["attributes"].update(body["attributes"])
        elif any(x["attributes"]["locale"] == body["attributes"]["locale"] for x in store):
            return 409, b"{}"
        else:
            item = {"id": f"NEW-{len(self.calls)}", "type": body["type"], "attributes": dict(body["attributes"])}
            store.append(item)
        return 200, json.dumps({"data": item}).encode()

    writes = property(lambda self: [c for c in self.calls if c[0] != "GET"])
    tokens = property(lambda self: [c[2].get("Authorization", "").split(" ")[-1] for c in self.calls])


def run(fake, *argv):
    out, err = io.StringIO(), io.StringIO()
    with contextlib.redirect_stderr(err):
        code = asc_publish.main(list(argv), env=dict(ENV), send=fake, sign=fake_sign, out=out)
    return code, out.getvalue() + err.getvalue()


class AscScripts(unittest.TestCase):
    def setUp(self):
        self.assertIsNotNone(asc_lib, "scripts/asc_lib.py und scripts/asc_publish.py fehlen")

    def test_parse_texts(self):
        for lang, locale in (("de", "de-DE"), ("en", "en-US")):
            self.assertEqual(asc_lib.parse_texts(R / f"docs/appstore/{lang}.md"), TEXTS[locale])

    def test_api_rejects_before_send(self):  # AC-10a
        send = mock.Mock(return_value=(200, b"{}"))
        for m, p in (("GET", "https://evil.example/v1/apps"), ("GET", "//evil.example/v1/apps"),
                     ("DEL" + "ETE", "/v1/appStoreVersionLocalizations/X"), ("PUT", "/v1/appInfoLocalizations/X"),
                     ("POST", "/v1/review" + "Submissions"), ("POST", "/v1/appStoreVersion" + "Submissions"),
                     ("GET", "/v2/apps"), ("GET", f"/v1/apps/{APP}/builds"), ("PATCH", "/v1/appInfos/INFO-1")):
            with self.assertRaises(Exception, msg=f"{m} {p}"):
                asc_lib.api(m, p, token="T", send=send)
        send.assert_not_called()
        asc_lib.api("GET", "/v1/apps?filter[bundleId]=com.johannesemmrich.Restock", token="T", send=send)
        self.assertTrue(send.call_args[0][1].startswith("https://api.appstoreconnect.apple.com/v1/apps"))

    def test_only_own_app_and_host(self):  # AC-10b
        fake = FakeASC(vlocs=[], ilocs=[])
        self.assertEqual(run(fake, "--apply")[0], 0)
        for _, url, _, _ in fake.calls:
            self.assertTrue(url.startswith("https://api.appstoreconnect.apple.com/v1/"), url)
            segs = [s for s in unquote(urlsplit(url).path).split("/")[2:] if s[:1].isupper() or "-" in s]
            self.assertTrue(set(segs) <= fake.ids, url)
        self.assertIn("com.johannesemmrich.Restock", unquote(fake.calls[0][1]))

    def test_dry_run_never_writes(self):  # AC-10c
        fake = FakeASC(vlocs=[loc("appStoreVersionLocalizations", "de-DE", VERSION_FIELDS, description="alt")])
        code, out = run(fake)
        self.assertEqual((code, fake.writes), (0, []))
        self.assertIn("PATCH", out)
        self.assertIn("POST", out)
        self.assertIn("description", out)

    def test_state_checks_abort_before_writing(self):  # AC-10d
        two = lambda kind, attrs: [{"id": f"X-{i}", "type": kind, "attributes": attrs} for i in (1, 2)]
        cases = [FakeASC(vstate="READY_FOR_REVIEW"), FakeASC(vstate="WAITING_FOR_REVIEW"), FakeASC(vstate="FOO"),
                 FakeASC(istate="READY_FOR_DISTRIBUTION"), FakeASC(apps=[]),
                 FakeASC(apps=[{"id": APP, "type": "apps"}, {"id": "APP-other", "type": "apps"}]),
                 FakeASC(versions=two("appStoreVersions", {"versionString": "1.0", "platform": "IOS",
                                                           "appVersionState": "PREPARE_FOR_SUBMISSION"})),
                 FakeASC(infos=two("appInfos", {"state": "PREPARE_FOR_SUBMISSION"}))]
        for fake in cases:
            fake.vlocs = []
            code, _ = run(fake, "--apply")
            self.assertNotEqual(code, 0)
            self.assertEqual(fake.writes, [])

    def test_live_and_draft_appinfo_picks_draft(self):  # AC-10d, Positivfall
        infos = [{"id": "INFO-live", "type": "appInfos", "attributes": {"state": "READY_FOR_DISTRIBUTION"}},
                 {"id": "INFO-1", "type": "appInfos", "attributes": {"state": "PREPARE_FOR_SUBMISSION"}}]
        fake = FakeASC(infos=infos, ilocs=[loc("appInfoLocalizations", "de-DE", INFO_FIELDS, subtitle="alt")])
        self.assertEqual(run(fake, "--apply")[0], 0)
        self.assertNotIn("INFO-live", " ".join(c[1] for c in fake.calls))

    def test_patch_existing_post_missing(self):  # AC-10e
        fake = FakeASC(vlocs=[loc("appStoreVersionLocalizations", "de-DE", VERSION_FIELDS, description="alt")],
                       ilocs=[loc("appInfoLocalizations", "de-DE", INFO_FIELDS)])
        self.assertEqual(run(fake, "--apply")[0], 0)
        got = sorted((m, unquote(urlsplit(u).path)) for m, u, _, _ in fake.writes)
        self.assertEqual(got, [("PATCH", "/v1/appStoreVersionLocalizations/appStoreVersionLocalizations-de-DE"),
                               ("POST", "/v1/appInfoLocalizations"), ("POST", "/v1/appStoreVersionLocalizations")])
        for m, u, _, body in fake.writes:
            attrs, rel = body["data"]["attributes"], body["data"].get("relationships", {})
            if m == "PATCH":
                self.assertEqual(attrs, {"description": TEXTS["de-DE"]["description"]})
            elif "appInfoLocalizations" in u:
                self.assertEqual(set(attrs) - {"locale"}, set(INFO_FIELDS))
                self.assertEqual(rel["appInfo"]["data"], {"type": "appInfos", "id": "INFO-1"})
            else:
                self.assertEqual(set(attrs) - {"locale"}, set(VERSION_FIELDS))
                self.assertEqual(rel["appStoreVersion"]["data"], {"type": "appStoreVersions", "id": "VER-1"})
            self.assertNotIn("whats" + "New", json.dumps(body))

    def test_idempotent(self):  # AC-10f
        fake = FakeASC()
        self.assertEqual((run(fake, "--apply")[0], fake.writes), (0, []))
        fake = FakeASC(vlocs=[], ilocs=[loc("appInfoLocalizations", "en-US", INFO_FIELDS, name="alt")])
        run(fake, "--apply")
        n = len(fake.writes)
        self.assertEqual((n, run(fake, "--apply")[0], len(fake.writes)), (4, 0, 4))  # 2 POST Version, 1 PATCH + 1 POST appInfo

    def test_der_to_raw_and_token(self):  # AC-10g
        self.assertEqual(asc_lib.der_to_raw(FIXED_DER), R_INT.to_bytes(32, "big") + S_INT.to_bytes(32, "big"))
        seen = []
        tok = asc_lib.make_token(ENV, sign=lambda d, k: seen.append((d, k)) or FIXED_DER, now=1_000_000)
        h, p, s = tok.split(".")
        self.assertEqual(json.loads(b64d(h)), {"alg": "ES256", "kid": "TESTKID", "typ": "JWT"})
        claims = json.loads(b64d(p))
        self.assertEqual((claims["iss"], claims["aud"], claims["iat"]), ("iss-0000", "appstoreconnect-v1", 1_000_000))
        self.assertTrue(1_000_000 < claims["exp"] <= 1_001_200)
        self.assertEqual((len(b64d(s)), seen), (64, [(f"{h}.{p}".encode(), ENV["ASC_KEY_PATH"])]))

    def test_no_secrets_in_output_or_errors(self):  # AC-10g
        fake = FakeASC(vlocs=[])
        _, out = run(fake)
        self.assertTrue(fake.tokens[0])
        for secret in (fake.tokens[0], ENV["ASC_KEY_PATH"], base64.b64encode(FIXED_DER).decode()):
            self.assertNotIn(secret, out)
        leak = mock.Mock(return_value=(403, json.dumps({"errors": [{"detail": "GEHEIMTOKEN"}]}).encode()))
        with self.assertRaises(Exception) as e:
            asc_lib.api("GET", f"/v1/apps/{APP}/appInfos", token="GEHEIMTOKEN", send=leak)
        self.assertIn("403", str(e.exception))
        self.assertIn(f"/v1/apps/{APP}/appInfos", str(e.exception))
        self.assertNotIn("GEHEIMTOKEN", str(e.exception))

    @unittest.skipUnless(shutil.which("openssl"), "openssl fehlt")
    def test_default_sign_with_throwaway_key(self):  # AC-10g: echte Signatur, Schlüssel nie von Python gelesen
        with tempfile.TemporaryDirectory() as d:
            key, pub, sig, data = (Path(d) / n for n in ("k.pem", "pub.pem", "sig.der", "data"))
            sh = lambda *a: subprocess.run(["openssl", *map(str, a)], check=True, capture_output=True, text=True)
            sh("ecparam", "-name", "prime256v1", "-genkey", "-noout", "-out", key)
            sh("ec", "-in", key, "-pubout", "-out", pub)
            opened, real_open = [], builtins.open
            rec = lambda f, *a, **k: opened.append(str(f)) or real_open(f, *a, **k)
            with mock.patch("builtins.open", rec), mock.patch("io.open", rec), \
                    mock.patch.object(Path, "read_bytes", lambda s: opened.append(str(s)) or b""), \
                    mock.patch.object(Path, "read_text", lambda s, *a, **k: opened.append(str(s)) or ""):
                tok = asc_lib.make_token({**ENV, "ASC_KEY_PATH": str(key)})
            self.assertNotIn(str(key), opened)
            h, p, s = tok.split(".")
            raw = b64d(s)
            sig.write_bytes(der(int.from_bytes(raw[:32], "big"), int.from_bytes(raw[32:], "big")))
            data.write_bytes(f"{h}.{p}".encode())
            self.assertIn("Verified OK", sh("dgst", "-sha256", "-verify", pub, "-signature", sig, data).stdout)

    def test_source_bans(self):  # AC-10h
        for name in ("asc_lib.py", "asc_publish.py"):
            src = (R / "scripts" / name).read_text(encoding="utf-8")
            for word in BAD_WORDS:
                self.assertNotIn(word, src, f"{name}: {word}")
            for url in re.findall(r"https?://[^\s\"'`]+", src):
                self.assertTrue(url.startswith("https://api.appstoreconnect.apple.com"), f"{name}: {url}")
            tree = ast.parse(src)
            mods = {a.name.split(".")[0] for n in ast.walk(tree) if isinstance(n, ast.Import) for a in n.names}
            mods |= {n.module.split(".")[0] for n in ast.walk(tree) if isinstance(n, ast.ImportFrom) and n.module}
            self.assertTrue(mods - {"asc_lib"} <= set(sys.stdlib_module_names), f"{name}: {mods}")
            for n in ast.walk(tree):
                if isinstance(n, ast.Call) and getattr(n.func, "attr", "") in ("run", "Popen", "check_output"):
                    self.assertIsInstance(n.args[0], (ast.List, ast.Name), f"{name}: Aufruf ohne Argumentliste")
                    self.assertFalse(any(k.arg == "shell" for k in n.keywords), name)

    def test_api_rejects_foreign_queries_before_send(self):  # F002/F003: nur exakte Abfragen
        send = mock.Mock(return_value=(200, b"{}"))
        for m, p in (("GET", "/v1/apps?filter[bundleId]=x"), ("GET", "/v1/apps"),
                     ("GET", "/v1/apps?filter[bundleId]=com.johannesemmrich.Restock&include=builds"),
                     ("PATCH", "/v1/appInfoLocalizations/abc?x=1"), ("POST", "/v1/appInfoLocalizations?x=1"),
                     ("POST", "/v1/appInfoLocalizations?"), ("GET", f"/v1/apps/{APP}/appInfos?x=//evil"),
                     ("GET", f"/v1/apps/{APP}/appInfos?"),
                     ("GET", f"/v1/apps/{APP}/appStoreVersions?filter[versionString]=2.0&filter[platform]=IOS"),
                     ("GET", "/v1/apps?filter[bundleId]=com.johannesemmrich.Restock\r\nX-Evil: 1")):
            with self.assertRaises(Exception, msg=f"{m} {p!r}"):
                asc_lib.api(m, p, token="T", send=send)
        send.assert_not_called()
        asc_lib.api("GET", f"/v1/apps/{APP}/appStoreVersions?filter[versionString]=1.0&filter[platform]=IOS",
                    token="T", send=send)
        asc_lib.api("GET", f"/v1/apps/{APP}/appInfos", token="T", send=send)
        self.assertEqual(send.call_count, 2)

    def test_urllib_send_never_follows_redirect(self):  # F001: Token geht nie zum Ziel einer Weiterleitung
        import http.server, threading
        hits = []

        class Target(http.server.BaseHTTPRequestHandler):
            def do_GET(self):
                hits.append(self.headers.get("Authorization"))
                self.send_response(200), self.end_headers(), self.wfile.write(b"{}")
            log_message = lambda *a: None

        target = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Target)

        class Redirect(Target):
            def do_GET(self):
                self.send_response(302)
                self.send_header("Location", f"http://127.0.0.1:{target.server_port}/stolen")
                self.end_headers()

        origin = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Redirect)
        for srv in (target, origin):
            threading.Thread(target=srv.serve_forever, daemon=True).start()
        try:
            status, _ = asc_lib.urllib_send("GET", f"http://127.0.0.1:{origin.server_port}/v1/apps",
                                            {"Authorization": "Bearer GEHEIM"}, None)
        finally:
            for srv in (target, origin):
                srv.shutdown(), srv.server_close()
        self.assertEqual((status, hits), (302, []))
        proxies = [h for h in asc_lib.OPENER.handlers if isinstance(h, asc_lib.urllib.request.ProxyHandler)]
        self.assertTrue(all(h.proxies == {} for h in proxies))
        self.assertIsNone(asc_lib.NoRedirect().redirect_request(None, None, 302, "", {}, "http://127.0.0.1/"))

    def test_api_turns_redirect_status_into_error(self):  # F001: 3xx endet als Fehler mit Status und Pfad
        with self.assertRaises(Exception) as e:
            asc_lib.api("GET", f"/v1/apps/{APP}/appInfos", token="GEHEIM", send=lambda *a: (302, b""))
        self.assertIn("302", str(e.exception))
        self.assertNotIn("GEHEIM", str(e.exception))

    # --- Issue #227: Apples code und title bei HTTP-Fehlern ---
    @staticmethod
    def _errs(*items):
        return json.dumps({"errors": list(items)}).encode()

    def test_error_suffix_reads_code_and_title(self):  # AC-1
        one = self._errs({"code": "A", "title": "B"})
        self.assertEqual(asc_lib.apple_error_suffix(one), " — A: B")
        two = self._errs({"code": "A", "title": "B"}, {"code": "C", "title": "D"})
        self.assertEqual(asc_lib.apple_error_suffix(two), " — A: B; C: D")

    def test_error_suffix_invalid_input_is_empty(self):  # AC-2
        for raw in (b"", None, b"kein json", b"[]", b"{}", b'{"errors": "x"}', b'{"errors": {"a": 1}}',
                    b'{"errors": [1, "x", null]}', b"\xff\xfe"):
            self.assertEqual(asc_lib.apple_error_suffix(raw), "", raw)

    def test_error_suffix_max_three_errors(self):  # AC-3
        raw = self._errs(*({"code": f"C{i}", "title": f"T{i}"} for i in range(4)))
        out = asc_lib.apple_error_suffix(raw)
        self.assertIn("C2: T2", out)
        self.assertNotIn("C3", out)

    def test_error_suffix_truncates_and_strips_control_chars(self):  # AC-4
        out = asc_lib.apple_error_suffix(self._errs({"code": "X" * 200, "title": "a\r\nb\tc\x1b[31md"}))
        self.assertNotIn("X" * 81, out)
        self.assertIn("X" * 80, out)
        self.assertFalse(re.search(r"[\x00-\x1f\x7f]", out), repr(out))
        self.assertEqual(asc_lib.apple_error_suffix(self._errs({"title": "nur Titel"})), " — nur Titel")
        self.assertEqual(asc_lib.apple_error_suffix(self._errs({"code": "NUR_CODE"})), " — NUR_CODE")
        for bad in ({"code": 5, "title": ["x"]}, {}, {"detail": "d"}):
            self.assertEqual(asc_lib.apple_error_suffix(self._errs(bad)), "", bad)

    def test_error_suffix_never_contains_detail_id_source(self):  # AC-5
        raw = self._errs({"code": "A", "title": "B", "detail": "GEHEIMDETAIL /geheim/AuthKey_TEST.p8",
                          "id": "GEHEIMID", "source": {"pointer": "/data/GEHEIMQUELLE"}})
        out = asc_lib.apple_error_suffix(raw)
        for word in ("GEHEIM", "AuthKey", "pointer"):
            self.assertNotIn(word, out)

    def test_error_suffix_strips_surrogates_and_format_chars(self):  # AC-4, Adversary F001
        raw = b'{"errors": [{"code": "A\\ud800B\\u2028C", "title": "x\\u2029y\\u202ez\\u200b\\ufeff\\u2066w"}]}'
        out = asc_lib.apple_error_suffix(raw)
        for ch in ("\ud800", " ", " ", "‮", "​", "﻿", "⁦"):
            self.assertNotIn(ch, out)
        out.encode("utf-8")
        self.assertEqual(out, " — ABC: xyzw")

    def test_api_error_message_includes_apple_code_and_title(self):  # AC-6
        raw = self._errs({"code": "STATE_ERROR", "title": "Zustand falsch", "detail": "GEHEIMDETAIL"})
        with self.assertRaises(RuntimeError) as e:
            asc_lib.api("POST", "/v1/appStoreVersionLocalizations", token="GEHEIMTOKEN", send=lambda *a: (409, raw),
                        body={"data": {}})
        msg = str(e.exception)
        self.assertTrue(msg.startswith("HTTP 409 bei POST /v1/appStoreVersionLocalizations"), msg)
        self.assertIn("STATE_ERROR: Zustand falsch", msg)
        self.assertNotIn("GEHEIM", msg)

    def test_api_error_without_json_keeps_old_message(self):  # AC-7
        for status, raw in ((409, b"<html>"), (500, b""), (302, b"")):
            with self.assertRaises(RuntimeError) as e:
                asc_lib.api("GET", f"/v1/apps/{APP}/appInfos", token="T", send=lambda *a: (status, raw))
            self.assertEqual(str(e.exception), f"HTTP {status} bei GET /v1/apps/{APP}/appInfos")
        with self.assertRaises(RuntimeError) as e:
            asc_lib.api("GET", f"/v1/apps/{APP}/appInfos", token="T",
                        send=lambda *a: (302, self._errs({"code": "R", "title": "Umgeleitet"})))
        self.assertIn("R: Umgeleitet", str(e.exception))

    def test_urllib_send_returns_error_body_capped(self):  # AC-8
        import http.server, threading
        big = b"x" * (200 * 1024)

        class H(http.server.BaseHTTPRequestHandler):
            _small = b'{"errors":[{"code":"A","title":"B"}]}'

            def do_GET(self):
                body = big if self.path == "/big" else self._small
                self.send_response(409), self.send_header("Content-Length", str(len(body)))
                self.end_headers(), self.wfile.write(body)
            log_message = lambda *a: None

        srv = http.server.ThreadingHTTPServer(("127.0.0.1", 0), H)
        threading.Thread(target=srv.serve_forever, daemon=True).start()
        try:
            base = f"http://127.0.0.1:{srv.server_port}"
            status, raw = asc_lib.urllib_send("GET", base + "/small", {}, None)
            self.assertEqual((status, raw), (409, H._small))
            status, raw = asc_lib.urllib_send("GET", base + "/big", {}, None)
            self.assertEqual(status, 409)
            self.assertTrue(0 < len(raw) <= 65536, len(raw))
        finally:
            srv.shutdown(), srv.server_close()

    def test_error_with_secret_like_detail_never_leaks(self):  # AC-11
        raw = self._errs({"code": "FORBIDDEN", "title": "Nein", "detail": "Bearer GEHEIMTOKEN /geheim/AuthKey_TEST.p8",
                          "id": "GEHEIMTOKEN"})
        with self.assertRaises(RuntimeError) as e:
            asc_lib.api("GET", f"/v1/apps/{APP}/appInfos", token="GEHEIMTOKEN", send=lambda *a: (403, raw))
        for secret in ("GEHEIMTOKEN", "AuthKey", "Bearer"):
            self.assertNotIn(secret, str(e.exception))
        self.assertIn("FORBIDDEN: Nein", str(e.exception))


if __name__ == "__main__":
    unittest.main()
