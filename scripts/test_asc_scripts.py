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


if __name__ == "__main__":
    unittest.main()
