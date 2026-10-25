#!/usr/bin/env python3
"""Test des Gegenlesers scripts/asc_check.py (Issue #175, Durchgang B2b, AC-11 bis AC-20g der Spec
docs/specs/appstore/app-store-auftritt.md). Ohne Netz und ohne Schlüssel: Apple wird durch FakeASC ersetzt, die
Datenschutzseite durch einen Schein-Abruf, die Signatur durch fake_sign."""
import ast, contextlib, datetime, html, importlib, inspect, io, json, re, sys, unittest
from pathlib import Path
from unittest import mock
from urllib.parse import unquote, urlsplit

R = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(R / "scripts"))
try:
    asc_check, asc_lib = importlib.import_module("asc_check"), importlib.import_module("asc_lib")
except ImportError:
    asc_check = asc_lib = None

APP = "APP-7f3"
ENV = {"ASC_KEY_ID": "TESTKID", "ASC_ISSUER_ID": "iss-0000", "ASC_KEY_PATH": "/geheim/AuthKey_TEST.p8"}
PRIVACY_URL = "https://emmrich-business.com/datenschutz"
VERSION_FIELDS = {"description": "description", "keywords": "keywords", "promotionalText": "promotional_text",
                  "supportUrl": "support_url"}
INFO_FIELDS = {"name": "name", "subtitle": "subtitle", "privacyPolicyUrl": "privacy_url"}
PREFIX = "com.johannesemmrich.smartcart.premium."
CONTACT = {"contactFirstName": "Vorname-XYZ", "contactLastName": "Nachname-XYZ",
           "contactEmail": "kontakt-xyz@example.com", "contactPhone": "+49 000 123456"}


def own_parse(lang):
    parts = re.split(r"^## (.+)$", (R / f"docs/appstore/{lang}.md").read_text(encoding="utf-8"), flags=re.M)
    return {parts[i].strip(): parts[i + 1].strip() for i in range(1, len(parts), 2)}


TEXTS = {"de-DE": own_parse("de"), "en-US": own_parse("en")}
fake_sign = lambda data, key_path: b"\x30\x06\x02\x01\x01\x02\x01\x02"


def res(kind, rid, **attrs):
    return {"id": rid, "type": kind, "attributes": attrs}


def page_html(drop_english=False):
    md = (R / "docs/appstore/datenschutz.md").read_text(encoding="utf-8")
    if drop_english:
        md = md.split("## English")[0]
    body = "".join(f"<p>{html.escape(l.replace('**', ''))}</p>\n" for l in md.splitlines() if l.strip() and l != "---")
    return f"<html><body><h1>Datenschutz</h1>\n{body}</body></html>".encode()


class FakeASC:
    """Ein vollständig eingerichteter Entwurf von Version 1.0; Tests verändern einzelne Felder."""

    def __init__(self):
        self.app = res("apps", APP, bundleId="com.johannesemmrich.Restock",
                       contentRightsDeclaration="DOES_NOT_USE_THIRD_PARTY_CONTENT")
        self.version = res("appStoreVersions", "VER-1", versionString="1.0", platform="IOS",
                           appVersionState="PREPARE_FOR_SUBMISSION")
        self.info = res("appInfos", "INFO-1", state="PREPARE_FOR_SUBMISSION")
        self.vlocs = [res("appStoreVersionLocalizations", f"VL-{l}", locale=l,
                          **{k: TEXTS[l][f] for k, f in VERSION_FIELDS.items()}) for l in TEXTS]
        self.ilocs = [res("appInfoLocalizations", f"IL-{l}", locale=l,
                          **{k: TEXTS[l][f] for k, f in INFO_FIELDS.items()}) for l in TEXTS]
        self.primary, self.secondary = {"id": "SHOPPING", "type": "appCategories"}, {"id": "PRODUCTIVITY", "type": "appCategories"}
        self.age = res("ageRatingDeclarations", "AGE-1", violenceCartoonOrFantasy="NONE")
        self.price_schedule, self.availability = res("appPriceSchedules", "PS-1"), res("appAvailabilities", "AV-1")
        self.iaps = [res("inAppPurchases", "IAP-life", productId=PREFIX + "lifetime", inAppPurchaseType="NON_CONSUMABLE",
                         state="READY_TO_SUBMIT")]
        self.groups = [res("subscriptionGroups", "GRP-1", referenceName="Restock Pro")]
        self.subs = [res("subscriptions", f"SUB-{p}", productId=PREFIX + p, state="READY_TO_SUBMIT") for p in ("monthly", "yearly")]
        self.prices = {"IAP-life": "14.99", "SUB-monthly": "1.99", "SUB-yearly": "8.99"}
        self.product_locs = {pid: [res("localizations", f"LOC-{pid}-{l}", locale=l, name="Restock Pro", description="Alles")
                                   for l in TEXTS] for pid in self.prices}
        self.review_shots = {pid: res("appStoreReviewScreenshots", f"RS-{pid}") for pid in self.prices}
        self.sets = {l: [res("appScreenshotSets", f"SET-{l}", screenshotDisplayType="APP_IPHONE_67")] for l in TEXTS}
        self.shots = {l: [res("appScreenshots", f"SH-{l}-{i}", imageAsset={"width": 1320, "height": 2868},
                              assetDeliveryState={"state": "COMPLETE"}) for i in range(4)] for l in TEXTS}
        self.build = res("builds", "BUILD-37", version="37", processingState="VALID", usesNonExemptEncryption=False)
        self.review = res("appStoreReviewDetails", "REV-1", demoAccountRequired=False, **CONTACT)
        self.calls = []

    def routes(self):
        r = {"/v1/apps": [self.app], f"/v1/apps/{APP}/appStoreVersions": [self.version], f"/v1/apps/{APP}/appInfos": [self.info],
             "/v1/appStoreVersions/VER-1/appStoreVersionLocalizations": self.vlocs,
             "/v1/appInfos/INFO-1/appInfoLocalizations": self.ilocs,
             "/v1/appInfos/INFO-1/primaryCategory": self.primary, "/v1/appInfos/INFO-1/secondaryCategory": self.secondary,
             "/v1/appInfos/INFO-1/ageRatingDeclaration": self.age,
             f"/v1/apps/{APP}/appPriceSchedule": self.price_schedule, f"/v1/apps/{APP}/appAvailabilityV2": self.availability,
             f"/v1/apps/{APP}/inAppPurchasesV2": self.iaps, f"/v1/apps/{APP}/subscriptionGroups": self.groups,
             "/v1/subscriptionGroups/GRP-1/subscriptions": self.subs,
             "/v1/appStoreVersions/VER-1/build": self.build, "/v1/appStoreVersions/VER-1/appStoreReviewDetail": self.review}
        for pid in self.prices:
            r.update({p.format(id=pid): v for p, v in zip(asc_check.PRODUCT_PATHS[pid.split("-")[0]],
                                                          (self.product_locs[pid], self.review_shots[pid]))})
        for v in self.vlocs:
            l = v["attributes"]["locale"]
            r[f"/v1/appStoreVersionLocalizations/{v['id']}/appScreenshotSets"] = self.sets.get(l, [])
            for s in self.sets.get(l, []):
                r[f"/v1/appScreenshotSets/{s['id']}/appScreenshots"] = self.shots[l]
        return r

    def __call__(self, method, url, headers, data):
        self.calls.append((method, url, headers))
        p = unquote(urlsplit(url).path)
        if method != "GET":
            return 405, b"{}"
        for pid, price in self.prices.items():  # Preispunkte (Abfrage mit include, Basisland Deutschland)
            if p == asc_check.PRICE_PATHS[pid.split("-")[0]].format(id=pid):
                return 200, json.dumps({"data": [res("prices", f"PR-{pid}")],
                                        "included": [res("pricePoints", f"PP-{pid}", customerPrice=price)]}).encode()
        routes = self.routes()
        if p not in routes:
            return 404, b"{}"
        return 200, json.dumps({"data": routes[p]}).encode()

    tokens = property(lambda self: [c[2].get("Authorization", "").split(" ")[-1] for c in self.calls])


class FakePage:
    def __init__(self, status=200, body=None):
        self.status, self.body, self.calls = status, page_html() if body is None else body, []

    def __call__(self, method, url, headers, data):
        self.calls.append((method, url, headers))
        return self.status, self.body


def run(fake, *argv, page=None, commit=lambda: "abc1234def", now=datetime.datetime(2026, 10, 25, 12, 0, tzinfo=datetime.timezone.utc)):
    out, err = io.StringIO(), io.StringIO()
    with contextlib.redirect_stderr(err):
        code = asc_check.main(list(argv), env=dict(ENV), send=fake, sign=fake_sign, out=out,
                              page_send=page or FakePage(), commit=commit, now=now)
    return code, out.getvalue() + err.getvalue()


class AscCheck(unittest.TestCase):
    def setUp(self):
        self.assertIsNotNone(asc_check, "scripts/asc_check.py fehlt")

    def assert_section(self, section, break_it, needle):
        self.assertEqual(run(FakeASC(), "--section", section)[0], 0, f"{section} ok-Fall")
        fake = FakeASC()
        break_it(fake)
        code, out = run(fake, "--section", section)
        self.assertNotEqual(code, 0, f"{section} Abweichungsfall")
        self.assertIn("Abweichung", out)
        self.assertIn(needle, out)
        return out

    def test_section_metadata_ok_and_deviation(self):  # AC-11
        out = self.assert_section("metadata", lambda f: f.vlocs[1]["attributes"].update(keywords="alt,falsch"), "keywords")
        self.assertIn("en-US", out)
        out = self.assert_section("metadata", lambda f: f.ilocs.pop(0), "de-DE")

    def test_section_privacy_url_ok_and_deviation(self):  # AC-12
        self.assertEqual(run(FakeASC(), "--section", "privacy-url")[0], 0)
        for page in (FakePage(body=page_html(drop_english=True)), FakePage(status=404),
                     FakePage(body=b"<p>Geteilte Listen liegen in der privaten Datenbank.</p>")):
            code, out = run(FakeASC(), "--section", "privacy-url", page=page)
            self.assertNotEqual(code, 0)
            self.assertIn("Abweichung", out)

    def test_section_appinfo_ok_and_deviation(self):  # AC-13
        self.assert_section("appinfo", lambda f: setattr(f, "age", None), "ageRating")
        self.assert_section("appinfo", lambda f: setattr(f, "secondary", None), "secondaryCategory")
        self.assert_section("appinfo", lambda f: f.app["attributes"].update(contentRightsDeclaration=None), "contentRights")
        self.assert_section("appinfo", lambda f: setattr(f, "price_schedule", None), "appPriceSchedule")
        self.assert_section("appinfo", lambda f: setattr(f, "availability", None), "appAvailability")

    def test_privacy_questionnaire_reports_manual(self):  # AC-14, AC-20d
        code, out = run(FakeASC(), "--all")
        line = next(l for l in out.splitlines() if "AC-14" in l)
        self.assertIn("manuell belegen", line)
        self.assertNotRegex(line, r"^ok\b")

    def test_section_iap_ok_and_deviation(self):  # AC-15
        self.assert_section("iap", lambda f: f.subs.pop(), "yearly")
        self.assert_section("iap", lambda f: f.iaps.append(res("inAppPurchases", "IAP-x", productId=PREFIX + "sharedlists",
                                                               inAppPurchaseType="NON_CONSUMABLE", state="READY_TO_SUBMIT")),
                            "sharedlists")
        self.assert_section("iap", lambda f: f.prices.update({"SUB-monthly": "2.99"}), "1.99")
        self.assert_section("iap", lambda f: f.product_locs["IAP-life"].pop(), "en-US")
        self.assert_section("iap", lambda f: f.review_shots.update({"SUB-yearly": None}), "Review-Screenshot")
        self.assert_section("iap", lambda f: f.subs[0]["attributes"].update(state="WAITING_FOR_REVIEW"), "WAITING_FOR_REVIEW")

    def test_section_screenshots_checks_pixel_size_not_enum(self):  # AC-16
        fake = FakeASC()
        for s in fake.sets.values():
            s[0]["attributes"]["screenshotDisplayType"] = "APP_IPHONE_UNBEKANNT"
        self.assertEqual(run(fake, "--section", "screenshots")[0], 0, "Enum-Name darf keine Rolle spielen")
        self.assert_section("screenshots", lambda f: f.shots["de-DE"][0]["attributes"].update(
            imageAsset={"width": 1290, "height": 2796}), "de-DE")
        self.assert_section("screenshots", lambda f: f.shots.update({"en-US": f.shots["en-US"][:2]}), "en-US")

    def test_section_build_ok_and_deviation(self):  # AC-17
        self.assert_section("build", lambda f: f.build["attributes"].update(version="36"), "37")
        self.assert_section("build", lambda f: f.build["attributes"].update(processingState="PROCESSING"), "PROCESSING")
        self.assert_section("build", lambda f: setattr(f, "build", None), "build")

    def test_section_build_requires_export_compliance_false(self):  # AC-17
        self.assert_section("build", lambda f: f.build["attributes"].update(usesNonExemptEncryption=None), "usesNonExemptEncryption")
        self.assert_section("build", lambda f: f.build["attributes"].update(usesNonExemptEncryption=True), "usesNonExemptEncryption")

    def test_section_review_ok_and_deviation(self):  # AC-17a
        self.assert_section("review", lambda f: f.review["attributes"].update(contactPhone=""), "contactPhone")
        self.assert_section("review", lambda f: f.review["attributes"].update(demoAccountRequired=True), "demoAccountRequired")
        self.assert_section("review", lambda f: setattr(f, "review", None), "appStoreReviewDetail")

    def test_section_review_never_prints_contact_values(self):  # AC-17a
        fake = FakeASC()
        fake.review["attributes"]["contactEmail"] = ""
        for f in (FakeASC(), fake):
            _, out = run(f, "--section", "review")
            for value in CONTACT.values():
                self.assertNotIn(value, out)
        self.assertIn("leer", run(fake, "--section", "review")[1])

    def test_section_status_ok_and_deviation(self):  # AC-18
        self.assert_section("status", lambda f: f.version["attributes"].update(appVersionState="WAITING_FOR_REVIEW"),
                            "WAITING_FOR_REVIEW")

    def test_deviation_names_field_expected_actual(self):  # AC-20c
        out = self.assert_section("metadata", lambda f: f.ilocs[0]["attributes"].update(subtitle="Falscher Untertitel"), "subtitle")
        line = next(l for l in out.splitlines() if "subtitle" in l and "Abweichung" in l)
        self.assertIn("Soll", line)
        self.assertIn(TEXTS["de-DE"]["subtitle"], line)
        self.assertIn("Falscher Untertitel", line)

    def test_all_exit_zero_only_if_all_api_sections_ok(self):  # AC-19, AC-20d
        code, out = run(FakeASC(), "--all")
        self.assertEqual(code, 0, out)
        for section in ("metadata", "privacy-url", "appinfo", "iap", "screenshots", "build", "review", "status"):
            self.assertIn(section, out)
        fake = FakeASC()
        fake.build["attributes"]["processingState"] = "INVALID"
        self.assertNotEqual(run(fake, "--all")[0], 0)
        self.assertNotEqual(run(FakeASC(), "--all", page=FakePage(status=404))[0], 0)

    def test_fence_rejects_before_send(self):  # AC-20a
        send = mock.Mock(return_value=(200, json.dumps({"data": [res("apps", APP)]}).encode()))
        reader = asc_check.Reader("T", send=send)
        for p in ("https://evil.example/v1/apps", "//evil.example/v1/apps", "/v1/apps", "/v1/apps?filter[bundleId]=x",
                  "/v1/review" + "Submissions", "/v1/appStoreVersion" + "Submissions", "/v2/apps",
                  f"/v1/apps/{APP}/appInfos", "/v1/appStoreVersionLocalizations/VL-de-DE"):
            with self.assertRaises(Exception, msg=p):
                reader.get(p)
        send.assert_not_called()
        reader.get(f"/v1/apps?filter[bundleId]={asc_lib.BUNDLE}")
        self.assertTrue(send.call_args[0][1].startswith("https://api.appstoreconnect.apple.com/v1/apps"))
        self.assertEqual(send.call_args[0][0], "GET")
        for p in (f"/v1/apps/{APP}/builds", "/v1/apps/APP-fremd/appInfos", f"/v1/apps/{APP}/appInfos?x=1"):
            with self.assertRaises(Exception, msg=p):
                reader.get(p)
        self.assertEqual(send.call_count, 1)
        for m in ("POST", "PATCH", "DEL" + "ETE", "PUT"):
            with self.assertRaises(Exception, msg=m):
                asc_check.check_read(m, f"/v1/apps/{APP}/appInfos", {APP})
        asc_check.check_read("GET", f"/v1/apps/{APP}/appInfos", {APP})

    def test_only_get_and_ids_from_answers(self):  # AC-20a im ganzen Lauf
        fake = FakeASC()
        run(fake, "--all")
        self.assertTrue(fake.calls)
        for method, url, _ in fake.calls:
            self.assertEqual(method, "GET")
            self.assertTrue(url.startswith("https://api.appstoreconnect.apple.com/v1/"), url)

    def test_privacy_fetch_without_authorization_and_redirect(self):  # AC-20b
        page = FakePage()
        run(FakeASC(), "--section", "privacy-url", page=page)
        self.assertEqual([(m, u) for m, u, _ in page.calls], [("GET", PRIVACY_URL)])
        self.assertFalse(any(k.lower() == "authorization" for k in page.calls[0][2]))
        self.assertIs(inspect.signature(asc_check.fetch_privacy).parameters["send"].default, asc_lib.urllib_send)
        code, out = run(FakeASC(), "--section", "privacy-url", page=FakePage(status=302, body=b""))
        self.assertNotEqual(code, 0)
        self.assertIn("302", out)

    def test_privacy_fetch_only_exact_url(self):  # AC-20b
        send = mock.Mock(return_value=(200, b""))
        for url in ("http://emmrich-business.com/datenschutz", "https://emmrich-business.com/datenschutz/../x",
                    "https://evil.example/datenschutz", "https://emmrich-business.com/datenschutz?x=1",
                    "https://api.appstoreconnect.apple.com/v1/apps"):
            with self.assertRaises(Exception, msg=url):
                asc_check.fetch_privacy(url, send=send)
        send.assert_not_called()

    def test_no_secrets_in_output_or_errors(self):  # AC-20e
        fake = FakeASC()
        _, out = run(fake, "--all")
        self.assertTrue(fake.tokens[0])
        for secret in (fake.tokens[0], ENV["ASC_KEY_PATH"]):
            self.assertNotIn(secret, out)
        leak = lambda m, u, h, d: (403, json.dumps({"errors": [{"detail": h["Authorization"]}]}).encode())
        code, out = run(leak, "--section", "metadata")
        self.assertNotEqual(code, 0)
        self.assertIn("403", out)
        self.assertIn("/v1/apps", out)
        self.assertNotIn("Bearer", out)
        self.assertNotIn(ENV["ASC_KEY_PATH"], out)

    def test_source_bans(self):  # AC-20f
        src = (R / "scripts/asc_check.py").read_text(encoding="utf-8")
        for word in ("shell=True", '"POST"', '"PATCH"', '"DELETE"', '"PUT"', "'POST'", "'PATCH'", "'DELETE'", "'PUT'",
                     "reviewSubmissions", "appStoreVersionSubmissions", "asc_lib.api", "ASC_KEY_PATH"):
            self.assertNotIn(word, src, word)
        for url in re.findall(r"https?://[^\s\"'`]+", src):
            self.assertTrue(url.startswith("https://api.appstoreconnect.apple.com") or url == PRIVACY_URL, url)
        tree = ast.parse(src)
        mods = {a.name.split(".")[0] for n in ast.walk(tree) if isinstance(n, ast.Import) for a in n.names}
        mods |= {n.module.split(".")[0] for n in ast.walk(tree) if isinstance(n, ast.ImportFrom) and n.module}
        self.assertTrue(mods - {"asc_lib"} <= set(sys.stdlib_module_names), mods)
        for n in ast.walk(tree):
            if isinstance(n, ast.Call) and getattr(n.func, "attr", "") in ("run", "Popen", "check_output"):
                self.assertIsInstance(n.args[0], (ast.List, ast.Name), "Aufruf ohne Argumentliste")
                self.assertFalse(any(k.arg == "shell" for k in n.keywords))
            if isinstance(n, ast.Call) and getattr(n.func, "id", "") == "open":
                self.fail("asc_check öffnet keine Dateien selbst (Texte über asc_lib.parse_texts)")

    def test_protocol_has_timestamp_and_commit(self):  # AC-20g
        _, out = run(FakeASC(), "--all")
        head = out.splitlines()[0]
        self.assertIn("2026-10-25T12:00:00Z", head)
        self.assertIn("abc1234def", head)
        _, out = run(FakeASC(), "--all", commit=lambda: None)
        self.assertIn("unbekannt", out.splitlines()[0])


if __name__ == "__main__":
    unittest.main()
