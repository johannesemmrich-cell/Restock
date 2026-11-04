#!/usr/bin/env python3
"""Test des Abholers scripts/asc_crashes.py (Issue #242, Schnitt 1, AC-1 bis AC-15 der Spec
docs/specs/appstore/asc-crashes.md). Ohne Netz und ohne Schlüssel: Apple wird durch FakeASC über die `send`-Naht
ersetzt, die Signatur durch fake_sign, Wartezeit und Ausgabe sind injiziert. Nur AC-14 (fehlende Konfiguration)
läuft zusätzlich als echter Unterprozess. Schnittstelle des Skripts: check_read(method, path, ids), safe_field(value),
run(target, env, send, sign, sleep, out) (wirft RuntimeError/ValueError, Exit 1 macht main), main(argv)."""
import contextlib, importlib, io, json, os, re, stat, subprocess, sys, tempfile, unittest
from pathlib import Path

R = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(R / "scripts"))
try:
    asc_crashes, asc_lib = importlib.import_module("asc_crashes"), importlib.import_module("asc_lib")
except ImportError:
    asc_crashes = None
    asc_lib = importlib.import_module("asc_lib")

APP = "APP-7f3"
ENV = {"ASC_KEY_ID": "TESTKID", "ASC_ISSUER_ID": "iss-0000", "ASC_KEY_PATH": "/geheim/AuthKey_TEST.p8"}
BUNDLE = "com.johannesemmrich.Restock"
SECRETS = ("tester-geheim@example.com", "Kommentar-GEHEIM", "iPhone99,9-GEHEIM", "LOGTEXT-GEHEIM", "/geheim/AuthKey_TEST.p8")
LIST = f"/v1/apps/{APP}/betaFeedbackCrashSubmissions?limit=200"
fake_sign = lambda data, key_path: b"\x30\x06\x02\x01\x01\x02\x01\x02"
# Stand von ALLOWED vor #242; das Skript darf der Liste nichts hinzufügen (AC-3)
ALLOWED_BEFORE = {
    "GET": [r"/v1/apps/[A-Za-z0-9_-]+/(?:appStoreVersions|appInfos)",
            r"/v1/appStoreVersions/[A-Za-z0-9_-]+/appStoreVersionLocalizations",
            r"/v1/appInfos/[A-Za-z0-9_-]+/appInfoLocalizations"],
    "POST": [r"/v1/(?:appStoreVersionLocalizations|appInfoLocalizations)"],
    "PATCH": [r"/v1/(?:appStoreVersionLocalizations|appInfoLocalizations)/[A-Za-z0-9_-]+"],
}


def submission(sid, platform="IOS", created="2026-11-01T10:00:00Z"):
    return {"id": sid, "type": "betaFeedbackCrashSubmissions", "attributes": {
        "createdDate": created, "devicePlatform": platform, "email": SECRETS[0], "comment": SECRETS[1],
        "deviceModel": SECRETS[2], "osVersion": "26.5", "timeZone": "Europe/Berlin"}}


class FakeASC:
    """Schein-Apple: `pages` = Liste von Seiten (je Liste Meldungen), `logs` = id -> Status oder logText,
    `script` = Liste von Statuscodes/Ausnahmen, die der Reihe nach vor der echten Antwort abgefragt werden."""

    def __init__(self, pages=(), logs=None, app=True, script=(), next_override=None):
        self.pages, self.logs, self.app, self.script = list(pages), logs or {}, app, list(script)
        self.next_override, self.calls, self.tokens = next_override, [], []

    def __call__(self, method, url, headers, data):
        self.calls.append((method, url))
        self.tokens.append(headers.get("Authorization", "").removeprefix("Bearer "))
        if self.script:
            step = self.script.pop(0)
            if isinstance(step, Exception):
                raise step
            if step:
                return step, json.dumps({"errors": [{"code": "FEHLER_CODE", "title": "Fehler-Titel", "detail": "DETAIL-GEHEIM", "id": "ERR-ID"}]}).encode()
        path = url.removeprefix(asc_lib.HOST)
        base, _, query = path.partition("?")
        if base == "/v1/apps":
            return 200, json.dumps({"data": [{"id": APP, "type": "apps"}] if self.app else []}).encode()
        if base == f"/v1/apps/{APP}/betaFeedbackCrashSubmissions":
            idx = 0
            m = re.search(r"cursor=(\d+)", query)
            if m:
                idx = int(m.group(1))
            body = {"data": self.pages[idx] if self.pages else [], "links": {}}
            if self.next_override is not None:
                body["links"]["next"] = self.next_override
            elif idx + 1 < len(self.pages):
                body["links"]["next"] = f"{asc_lib.HOST}{base}?limit=200&cursor={idx + 1}"
            return 200, json.dumps(body).encode()
        m = re.fullmatch(r"/v1/betaFeedbackCrashSubmissions/([^/]+)/crashLog", base)
        if m:
            log = self.logs.get(m.group(1), 404)
            if isinstance(log, int):
                return log, b"{}"
            return 200, json.dumps({"data": {"id": "L-" + m.group(1), "type": "betaCrashLogs", "attributes": {"logText": log}}}).encode()
        return 404, b"{}"


def run_script(fake, target, env=ENV, sleep=lambda s: None):
    out = io.StringIO()
    rc = asc_crashes.run(target, env, send=fake, sign=fake_sign, sleep=sleep, out=out)
    return rc, out.getvalue()


class AscCrashesTests(unittest.TestCase):
    def setUp(self):
        self.assertIsNotNone(asc_crashes, "scripts/asc_crashes.py fehlt (RED)")
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.target = Path(self.tmp.name) / "crashes"

    def test_fence_allows_only_three_read_paths(self):  # AC-1
        ids = {APP, "S-1"}
        ok = [("GET", f"/v1/apps?filter[bundleId]={BUNDLE}"), ("GET", LIST),
              ("GET", LIST + "&cursor=abc_DEF-1="), ("GET", "/v1/betaFeedbackCrashSubmissions/S-1/crashLog")]
        for m, p in ok:
            asc_crashes.check_read(m, p, ids)
        bad = [("POST", LIST), ("PATCH", LIST), ("DELETE", LIST), ("GET", "/v1/apps"), ("GET", "/v1/apps?filter[bundleId]=x"),
               ("GET", f"/v1/apps/{APP}/betaFeedbackCrashSubmissions"), ("GET", f"/v1/apps/{APP}/betaFeedbackCrashSubmissions?limit=100"),
               ("GET", LIST + "&include=build"), ("GET", LIST + "&cursor="), ("GET", "/v1/betaFeedbackCrashSubmissions/S-1/crashLog?x=1"),
               ("GET", f"/v1/apps/{APP}/appInfos"), ("GET", "//evil.example/v1/apps"), ("GET", "v1/apps"),
               ("GET", "https://evil.example" + LIST), ("GET", "/v1/betaFeedbackCrashSubmissions/S-1")]
        for m, p in bad:
            with self.assertRaises(ValueError, msg=f"{m} {p}"):
                asc_crashes.check_read(m, p, ids)

    def test_fence_rejects_id_not_from_response(self):  # AC-2
        with self.assertRaises(ValueError):
            asc_crashes.check_read("GET", LIST, set())
        with self.assertRaises(ValueError):
            asc_crashes.check_read("GET", "/v1/betaFeedbackCrashSubmissions/FREMD/crashLog", {APP})

    def test_asc_lib_allowed_unchanged(self):  # AC-3
        self.assertEqual(asc_lib.ALLOWED, ALLOWED_BEFORE)
        for path in (LIST, "/v1/betaFeedbackCrashSubmissions/S-1/crashLog"):
            with self.assertRaises(ValueError):
                asc_lib.check_path("GET", path)

    def test_writes_json_and_crash_files_mode_0600(self):  # AC-4
        fake = FakeASC(pages=[[submission("S-1"), submission("S-2")]], logs={"S-1": "LOGTEXT-GEHEIM"})
        rc, _ = run_script(fake, self.target)
        self.assertEqual(rc, 0)
        self.assertEqual(stat.S_IMODE(self.target.stat().st_mode), 0o700)
        self.assertEqual(json.loads((self.target / "S-1.json").read_text())["email"], SECRETS[0])
        self.assertEqual((self.target / "S-1.crash").read_text(), "LOGTEXT-GEHEIM")
        for f in self.target.iterdir():
            self.assertEqual(stat.S_IMODE(f.stat().st_mode), 0o600, f.name)

    def test_missing_crash_log_is_not_an_error(self):  # AC-5
        fake = FakeASC(pages=[[submission("S-1"), submission("S-2"), submission("S-3")]], logs={"S-2": "", "S-3": 404})
        rc, _ = run_script(fake, self.target)
        self.assertEqual(rc, 0)
        self.assertEqual(sorted(p.name for p in self.target.iterdir()), ["S-1.json", "S-2.json", "S-3.json"])

    def test_follows_links_next_over_pages(self):  # AC-6
        fake = FakeASC(pages=[[submission("S-1")], [submission("S-2")], [submission("S-3")]])
        run_script(fake, self.target)
        self.assertEqual(sorted(p.name for p in self.target.iterdir()), ["S-1.json", "S-2.json", "S-3.json"])

    def test_links_next_foreign_host_and_loop_abort(self):  # AC-7
        for nxt in ("https://evil.example/v1/x?limit=200", f"http://api.appstoreconnect.apple.com/v1/apps/{APP}/betaFeedbackCrashSubmissions?limit=200&cursor=1"):
            fake = FakeASC(pages=[[submission("S-1")]], next_override=nxt)
            with self.assertRaises(RuntimeError):
                run_script(fake, self.target)
            self.assertTrue(all(u.startswith(asc_lib.HOST) for _, u in fake.calls), fake.calls)
        loop = FakeASC(pages=[[submission("S-1")]], next_override=f"{asc_lib.HOST}/v1/apps/{APP}/betaFeedbackCrashSubmissions?limit=200")
        with self.assertRaises(RuntimeError):
            run_script(loop, self.target)
        many = FakeASC(pages=[[submission(f"S-{i}")] for i in range(60)])
        with self.assertRaises(RuntimeError):
            run_script(many, self.target)

    def test_retries_on_5xx_429_and_network_error(self):  # AC-8
        fake = FakeASC(pages=[[submission("S-1")]], script=[503, 429, OSError("Netz weg"), 500])
        waits = []
        rc, _ = run_script(fake, self.target, sleep=waits.append)
        self.assertEqual(rc, 0)
        self.assertEqual(len(waits), 4)
        fail = FakeASC(script=[500] * 5)
        with self.assertRaises(RuntimeError) as cm:
            run_script(fail, self.target / "x")
        self.assertIn("HTTP 500", str(cm.exception))
        self.assertIn("/v1/apps", str(cm.exception))
        self.assertEqual(len(fail.calls), 5)

    def test_client_error_aborts_with_code_and_title_only(self):  # AC-9
        fake = FakeASC(pages=[[submission("S-1")]], script=[403])
        with self.assertRaises(RuntimeError) as cm:
            run_script(fake, self.target)
        msg = str(cm.exception)
        self.assertIn("HTTP 403", msg)
        self.assertIn("FEHLER_CODE", msg)
        self.assertIn("Fehler-Titel", msg)
        for secret in ("DETAIL-GEHEIM", "ERR-ID", ENV["ASC_KEY_PATH"], fake.tokens[0]):
            self.assertNotIn(secret, msg)
        self.assertEqual(len(fake.calls), 1)
        bad_log = FakeASC(pages=[[submission("S-1")]], logs={"S-1": 401})
        with self.assertRaises(RuntimeError):
            run_script(bad_log, self.target / "y")

    def test_log_contains_only_id_platform_date(self):  # AC-10
        fake = FakeASC(pages=[[submission("S-1")]], logs={"S-1": "LOGTEXT-GEHEIM"})
        err = io.StringIO()
        with contextlib.redirect_stdout(io.StringIO()) as so, contextlib.redirect_stderr(err):
            _, out = run_script(fake, self.target)
        text = out + so.getvalue() + err.getvalue()
        self.assertIn("S-1", out)
        self.assertIn("IOS", out)
        self.assertIn("2026-11-01", out)
        for secret in (*SECRETS, *fake.tokens):
            self.assertNotIn(secret, text)

    def test_safe_field_blocks_workflow_command_injection(self):  # AC-11
        sf = asc_crashes.safe_field
        self.assertEqual(sf("S-1_a.b:c+d"), "S-1_a.b:c+d")
        self.assertEqual(sf("x" * 100), "x" * 64)
        for bad in ("::error::x", "a\n::error::x", "a\rb", "a\x00b", "ä", "a b", None, 5):
            self.assertEqual(sf(bad), "?", repr(bad))
        evil = submission("S-1", platform="::error::x\n::warning::y", created="a\n::error::z")
        _, out = run_script(FakeASC(pages=[[evil]]), self.target)
        for line in out.splitlines():
            self.assertFalse(line.startswith("::"), line)
        self.assertEqual(len([l for l in out.splitlines() if "S-1" in l]), 1)

    def test_unsafe_submission_id_is_rejected(self):  # AC-12
        for bad in ("../x", "a/b", "", "a b", "x\ny"):
            target = self.target / "z"
            with self.assertRaises((RuntimeError, ValueError), msg=repr(bad)):
                run_script(FakeASC(pages=[[submission(bad)]]), target)
            outside = [p for p in Path(self.tmp.name).rglob("*") if p.is_file()]
            self.assertEqual(outside, [], f"Datei außerhalb des Zielordners: {outside}")

    def test_no_submissions_exits_zero(self):  # AC-13
        rc, out = run_script(FakeASC(pages=[[]]), self.target)
        self.assertEqual(rc, 0)
        self.assertIn("keine Absturzmeldungen", out)
        self.assertEqual(list(self.target.iterdir()), [])

    def test_missing_config_or_app_fails_cleanly(self):  # AC-14
        script = str(R / "scripts" / "asc_crashes.py")
        base = {"PATH": os.environ.get("PATH", "")}
        cases = [([self.tmp.name + "/o"], base), ([], {**base, **ENV}),
                 *[([self.tmp.name + "/o"], {**base, **{k: v for k, v in ENV.items() if k != drop}}) for drop in ENV]]
        for argv, env in cases:
            p = subprocess.run([sys.executable, "-I", script, *argv], env=env, capture_output=True, text=True)
            self.assertNotEqual(p.returncode, 0, argv)
            for secret in (ENV["ASC_KEY_PATH"], "Traceback"):
                self.assertNotIn(secret, p.stdout + p.stderr)
        with self.assertRaises(RuntimeError):
            run_script(FakeASC(app=False), self.target)

    def test_ci_lists_crash_test(self):  # AC-15
        ci = (R / ".github/workflows/ci.yml").read_text(encoding="utf-8")
        self.assertRegex(ci, r"scripts/test_asc_crashes\.py")
        self.assertIn('python3 -I "$t"', ci)


if __name__ == "__main__":
    unittest.main()
