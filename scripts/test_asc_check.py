#!/usr/bin/env python3
"""Test des Gegenlesers scripts/asc_check.py (Issue #175, Durchgänge B2b, B3a und B3b, AC-11 bis AC-23e der Spec
docs/specs/appstore/app-store-auftritt.md). Ohne Netz und ohne Schlüssel: Apple wird durch FakeASC ersetzt, die
Datenschutzseite durch einen Schein-Abruf, die Signatur durch fake_sign. Kaufpfade und Preisantworten nach API 4.5.1;
Altersfreigabe, App-Preisplan und Verfügbarkeit in der Form des ersten echten Laufs
(docs/artifacts/feat-175-b3-asc-betrieb/asc-antwortformen-2026-10-25.txt)."""
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


UA = "Restock-asc-check/1.0"
# Die 24 Inhaltsangaben der Altersfreigabe (Spec B3b F2a); in der echten Antwort alle null, solange nichts beantwortet ist
AGE_FIELDS = ("advertising", "alcoholTobaccoOrDrugUseOrReferences", "contests", "gambling", "gamblingSimulated",
              "gunsOrOtherWeapons", "healthOrWellnessTopics", "lootBox", "medicalOrTreatmentInformation", "messagingAndChat",
              "parentalControls", "profanityOrCrudeHumor", "ageAssurance", "sexualContentGraphicAndNudity",
              "sexualContentOrNudity", "socialMedia", "socialMediaAgeRestricted", "horrorOrFearThemes",
              "matureOrSuggestiveThemes", "unrestrictedWebAccess", "userGeneratedContent", "violenceCartoonOrFantasy",
              "violenceRealisticProlongedGraphicOrSadistic", "violenceRealistic")
AGE_EXTRA = {"ageRatingOverride": "NONE", "ageRatingOverrideV2": "NONE", "koreaAgeRatingOverride": "NONE",
             "kidsAgeBand": None, "gracRatingClassificationNumber": None, "developerAgeRatingInfoUrl": None}


def age_attrs(value=lambda i: False if i % 2 else "NONE"):
    """Booleans mit false und Stufen mit NONE sind beantwortet; die Zusatzfelder wie in der echten Antwort."""
    return {**{f: value(i) for i, f in enumerate(AGE_FIELDS)}, **AGE_EXTRA}


TODAY = datetime.date(2026, 10, 25)
PRICE_KINDS = {"IAP": ("inAppPurchasePrices", "inAppPurchasePricePoint", "inAppPurchasePricePoints"),
               "SUB": ("subscriptionPrices", "subscriptionPricePoint", "subscriptionPricePoints")}


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
        self.age = res("ageRatingDeclarations", "AGE-1", **age_attrs())
        self.price_schedule, self.availability = res("appPriceSchedules", "APS-1"), res("appAvailabilities", "AV-1")
        # Preisplan der App (B3b): Plan-ID ≠ App-ID, Basisland, manualPrices als (startDate, endDate, Betrag; None = Preispunkt fehlt)
        self.base_territory, self.app_prices = {"id": "DEU", "type": "territories"}, [(None, None, "0.0")]
        self.status_override = {}  # Pfad → HTTP-Status, z. B. 404 an appAvailabilityV2 wie im Erstlauf
        self.iaps = [res("inAppPurchases", "IAP-life", productId=PREFIX + "lifetime", inAppPurchaseType="NON_CONSUMABLE",
                         state="READY_TO_SUBMIT")]
        self.groups = [res("subscriptionGroups", "GRP-1", referenceName="Restock Pro")]
        self.subs = [res("subscriptions", f"SUB-{p}", productId=PREFIX + p, state="READY_TO_SUBMIT") for p in ("monthly", "yearly")]
        self.prices = {"IAP-life": "14.99", "SUB-monthly": "1.99", "SUB-yearly": "8.99"}
        # Preisplan ≠ Kauf-ID (AC-22b); Einträge je Produkt: (Ort, startDate, endDate, Betrag; None = Preispunkt fehlt)
        self.plans, self.price_entries, self.decoys = {"IAP-life": "PLAN-x"}, {}, {}
        self.foreign_type_points = {}  # Preispunkt mit gleicher ID wie der Eintrag, aber fremdem Typ, steht vorn (F002)
        self.product_locs = {pid: [res("localizations", f"LOC-{pid}-{l}", locale=l, name="Restock Pro", description="Alles")
                                   for l in TEXTS] for pid in self.prices}
        self.review_shots = {pid: res("appStoreReviewScreenshots", f"RS-{pid}") for pid in self.prices}
        self.sets = {l: [res("appScreenshotSets", f"SET-{l}", screenshotDisplayType="APP_IPHONE_67")] for l in TEXTS}
        self.shots = {l: [res("appScreenshots", f"SH-{l}-{i}", imageAsset={"width": 1320, "height": 2868},
                              assetDeliveryState={"state": "COMPLETE"}) for i in range(4)] for l in TEXTS}
        self.set_shots = {}  # Set-ID → eigene Bilder; sonst gelten die Bilder der Sprache (self.shots)
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
        for pid in self.prices:  # Pfade fest nach API 4.5.1, nicht aus asc_check übernommen
            base, locs = (f"/v2/inAppPurchases/{pid}", "inAppPurchaseLocalizations") if pid.startswith("IAP") else \
                         (f"/v1/subscriptions/{pid}", "subscriptionLocalizations")
            r.update({f"{base}/{locs}": self.product_locs[pid], f"{base}/appStoreReviewScreenshot": self.review_shots[pid]})
        for v in self.vlocs:
            l = v["attributes"]["locale"]
            r[f"/v1/appStoreVersionLocalizations/{v['id']}/appScreenshotSets"] = self.sets.get(l, [])
            for s in self.sets.get(l, []):
                r[f"/v1/appScreenshotSets/{s['id']}/appScreenshots"] = self.set_shots.get(s["id"], self.shots[l])
        return r

    def __call__(self, method, url, headers, data):
        self.calls.append((method, url, headers))
        p = unquote(urlsplit(url).path)
        if method != "GET":
            return 405, b"{}"
        if p in self.status_override:
            return self.status_override[p], b'{"errors": [{"status": "404"}]}'
        m = re.fullmatch(r"/v1/appPriceSchedules/([^/]+)/(baseTerritory|manualPrices)", p)
        if m:  # nur unter der Plan-ID aus der Antwort, nie unter der App-ID
            if not self.price_schedule or m[1] != self.price_schedule["id"]:
                return 404, b"{}"
            return 200, (json.dumps({"data": self.base_territory}).encode() if m[2] == "baseTerritory" else self.app_price_doc())
        m = re.fullmatch(r"/v2/inAppPurchases/([^/]+)/iapPriceSchedule", p)
        if m and m[1] in self.prices:
            plan = self.plans.get(m[1])
            return 200, json.dumps({"data": res("inAppPurchasePriceSchedules", plan) if plan else None}).encode()
        m = re.fullmatch(r"/v1/inAppPurchasePriceSchedules/([^/]+)/(manual|automatic)Prices", p)
        if m:  # nur unter einer Plan-ID; die Kauf-ID als Plan gibt es bei Apple nicht
            pid = next((k for k, v in self.plans.items() if v == m[1]), None)
            return (200, self.price_doc(pid, m[2])) if pid else (404, b"{}")
        m = re.fullmatch(r"/v1/subscriptions/([^/]+)/prices", p)
        if m and m[1] in self.prices:
            return 200, self.price_doc(m[1], "prices")
        routes = self.routes()
        if p not in routes:
            return 404, b"{}"
        return 200, json.dumps({"data": routes[p]}).encode()

    def price_doc(self, pid, where):
        """Preisantwort mit Einträgen (startDate/endDate) und Preispunkten in included, Basisland Deutschland."""
        kind, rel, point = PRICE_KINDS[pid.split("-")[0]]
        default = [("manual" if pid.startswith("IAP") else "prices", None, None, self.prices[pid])]
        data, included = [], [res("territories", "DEU", currency="EUR")] if kind == "subscriptionPrices" else []
        if pid in self.decoys:  # Preispunkt ohne Bezug, steht vorn
            included.append(res(point, f"PP-decoy-{pid}", customerPrice=self.decoys[pid]))
        for i, (w, start, end, amount) in enumerate(self.price_entries.get(pid, default)):
            if w != where:
                continue
            entry = res(kind, f"PR-{pid}-{w}-{i}", startDate=start, endDate=end)
            entry["relationships"] = {rel: {"data": {"type": point, "id": f"PP-{pid}-{w}-{i}"}}}
            data.append(entry)
            if pid in self.foreign_type_points:
                other = PRICE_KINDS["SUB" if pid.startswith("IAP") else "IAP"][2]
                included.insert(0, res(other, f"PP-{pid}-{w}-{i}", customerPrice=self.foreign_type_points[pid]))
            if amount is not None:
                included.append(res(point, f"PP-{pid}-{w}-{i}", customerPrice=amount))
        return json.dumps({"data": data, "included": included}).encode()

    def app_price_doc(self):
        """manualPrices des App-Preisplans: AppPriceV2-Einträge mit Beziehung appPricePoint, Preispunkte in included."""
        data, included = [], []
        for i, (start, end, amount) in enumerate(self.app_prices):
            entry = res("appPrices", f"AP-{i}", startDate=start, endDate=end)
            entry["relationships"] = {"appPricePoint": {"data": {"type": "appPricePoints", "id": f"APP-PP-{i}"}},
                                      "territory": {"data": {"type": "territories", "id": "DEU"}}}
            data.append(entry)
            if amount is not None:
                included.append(res("appPricePoints", f"APP-PP-{i}", customerPrice=amount))
        return json.dumps({"data": data, "included": included}).encode()

    paths = property(lambda self: [unquote(urlsplit(c[1]).path) for c in self.calls])
    tokens = property(lambda self: [c[2].get("Authorization", "").split(" ")[-1] for c in self.calls])


class FakePage:
    def __init__(self, status=200, body=None):
        self.status, self.body, self.calls = status, page_html() if body is None else body, []

    def __call__(self, method, url, headers, data):
        self.calls.append((method, url, headers))
        return self.status, self.body


def run(fake, *argv, page=None, commit=lambda: "abc1234def", now=datetime.datetime(2026, 10, 25, 12, 0, tzinfo=datetime.timezone.utc),
        today=TODAY):
    out, err = io.StringIO(), io.StringIO()
    with contextlib.redirect_stderr(err):
        code = asc_check.main(list(argv), env=dict(ENV), send=fake, sign=fake_sign, out=out,
                              page_send=page or FakePage(), commit=commit, now=now, today=today)
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
        out = self.assert_section("iap", lambda f: f.subs.append(dict(f.subs[0])), "doppeltes Produkt")  # F003
        self.assertIn(PREFIX + "monthly 2-mal", out)

    def test_section_screenshots_checks_pixel_size_not_enum(self):  # AC-16
        fake = FakeASC()
        for s in fake.sets.values():
            s[0]["attributes"]["screenshotDisplayType"] = "APP_IPHONE_UNBEKANNT"
        self.assertEqual(run(fake, "--section", "screenshots")[0], 0, "Enum-Name darf keine Rolle spielen")
        self.assert_section("screenshots", lambda f: f.shots["de-DE"][0]["attributes"].update(
            imageAsset={"width": 1290, "height": 2796}), "de-DE")
        self.assert_section("screenshots", lambda f: f.shots.update({"en-US": f.shots["en-US"][:2]}), "en-US")

    @staticmethod
    def add_set(fake, loc, n, w=1206, h=2622, state="COMPLETE", kind="APP_IPHONE_61"):
        sid = f"SET-{loc}-{kind}"
        fake.sets[loc].append(res("appScreenshotSets", sid, screenshotDisplayType=kind))
        fake.set_shots[sid] = [res("appScreenshots", f"{sid}-{i}", imageAsset={"width": w, "height": h},
                                   assetDeliveryState={"state": state}) for i in range(n)]
        return fake.set_shots[sid]

    def test_screenshots_two_valid_sets_per_locale_ok(self):  # AC-3/AC-16: beide Größen, je Set
        fake = FakeASC()
        for loc in TEXTS:
            self.add_set(fake, loc, 5)
        code, out = run(fake, "--section", "screenshots")
        self.assertEqual(code, 0, out)
        line = next(l for l in out.splitlines() if "SET-de-DE-APP_IPHONE_61" in l)
        self.assertRegex(line, r"^ok\b")
        self.assertIn("APP_IPHONE_61", line)
        self.assertIn("5 Bilder", line)
        self.assertIn("1206×2622 ×5", line)
        self.assertIn("COMPLETE ×5", line)
        self.assertIn("1320×2868 ×4", next(l for l in out.splitlines() if "SET-en-US (" in l or "SET-en-US)" in l))

    def test_screenshots_mixed_sizes_in_one_set_deviate(self):
        fake = FakeASC()
        self.add_set(fake, "de-DE", 4)[0]["attributes"]["imageAsset"] = {"width": 1320, "height": 2868}
        code, out = run(fake, "--section", "screenshots")
        self.assertNotEqual(code, 0)
        line = next(l for l in out.splitlines() if "SET-de-DE-APP_IPHONE_61" in l)
        self.assertIn("Abweichung", line)
        self.assertIn("Soll", line)
        self.assertIn("Ist", line)

    def test_screenshots_zero_size_names_delivery_state(self):
        for state in ("PROCESSING", "FAILED"):
            fake = FakeASC()
            fake.shots["de-DE"][1]["attributes"].update(imageAsset={"width": 0, "height": 0},
                                                         assetDeliveryState={"state": state})
            code, out = run(fake, "--section", "screenshots")
            self.assertNotEqual(code, 0)
            line = next(l for l in out.splitlines() if "SH-de-DE-1" in l)
            self.assertIn("Abweichung", line)
            self.assertIn("0×0", line)
            self.assertIn(state, line)
        fake = FakeASC()
        fake.shots["en-US"][0]["attributes"].pop("imageAsset")
        fake.shots["en-US"][0]["attributes"].pop("assetDeliveryState")
        code, out = run(fake, "--section", "screenshots")
        line = next(l for l in out.splitlines() if "SH-en-US-0" in l)
        self.assertIn("Abweichung", line)
        self.assertIn("unbekannt", line)

    def test_screenshots_valid_size_needs_complete_state(self):  # F001
        for state, ok in (("FAILED", False), ("UPLOAD_COMPLETE", False), ("COMPLETE", True)):
            fake = FakeASC()
            fake.shots["de-DE"][2]["attributes"]["assetDeliveryState"] = {"state": state}
            code, out = run(fake, "--section", "screenshots")
            line = next(l for l in out.splitlines() if "SET-de-DE)" in l)
            self.assertEqual(code == 0, ok, out)
            self.assertEqual(line.startswith("ok"), ok, line)
            if not ok:
                self.assertIn(f"{state} ×1", line)

    def test_screenshots_count_per_set_and_locale_needs_set(self):
        fake = FakeASC()
        for loc in TEXTS:
            self.add_set(fake, loc, 2)
        code, out = run(fake, "--section", "screenshots")
        self.assertNotEqual(code, 0, "2 Bilder in einem Set sind zu wenig, auch wenn die Sprache 6 hat")
        self.assertIn("2 Bilder", next(l for l in out.splitlines() if "Abweichung" in l and "SET-de-DE-APP_IPHONE_61" in l))
        fake = FakeASC()
        fake.sets["en-US"] = []
        code, out = run(fake, "--section", "screenshots")
        self.assertNotEqual(code, 0)
        self.assertIn("Sets (en-US)", next(l for l in out.splitlines() if "Abweichung" in l))

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
        self.assert_section("review", lambda f: f.review["attributes"].update(contactEmail="   "), "contactEmail")  # F001

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
        fake = FakeASC()  # F004: keine Version 1.0 → jeder Abschnitt nennt die Ursache, kein KeyError
        fake.version["attributes"]["versionString"] = "2.0"
        code, out = run(fake, "--all")
        self.assertNotEqual(code, 0)
        self.assertNotRegex(out, r": '(app|ver|info)'")
        self.assertEqual(out.count("Version 1.0 (IOS): 0 Treffer"), 7, out)

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
            self.assertRegex(url, r"^https://api\.appstoreconnect\.apple\.com/v[12]/", url)

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

    def assert_iap(self, fake, ok, needle="", today=TODAY):
        code, out = run(fake, "--section", "iap", today=today)
        if ok:
            self.assertEqual(code, 0, out)
        else:
            self.assertNotEqual(code, 0, out)
            self.assertIn("Abweichung", out)
            self.assertIn(needle, out)
        return out

    def test_iap_uses_v2_paths_and_fence_rejects_v1(self):  # AC-22a
        fake = FakeASC()
        self.assert_iap(fake, True)
        self.assertIn("/v2/inAppPurchases/IAP-life/inAppPurchaseLocalizations", fake.paths)
        self.assertIn("/v2/inAppPurchases/IAP-life/appStoreReviewScreenshot", fake.paths)
        self.assertFalse([p for p in fake.paths if p.startswith("/v1/inAppPurchases/")], fake.paths)
        send = mock.Mock(return_value=(200, b"{}"))
        reader = asc_check.Reader("T", send=send)
        reader.ids.update({"IAP-life", "PLAN-x"})
        for p in ("/v1/inAppPurchases/IAP-life/inAppPurchaseLocalizations", "/v1/inAppPurchases/IAP-life/appStoreReviewScreenshot",
                  "/v2/inAppPurchases/IAP-fremd/iapPriceSchedule", "/v1/inAppPurchasePriceSchedules/PLAN-x/manualPrices"):
            with self.assertRaises(Exception, msg=p):
                reader.get(p)
        send.assert_not_called()
        for p in ("/v2/inAppPurchases/IAP-life/inAppPurchaseLocalizations", "/v2/inAppPurchases/IAP-life/appStoreReviewScreenshot",
                  "/v2/inAppPurchases/IAP-life/iapPriceSchedule",
                  "/v1/inAppPurchasePriceSchedules/PLAN-x/manualPrices?include=inAppPurchasePricePoint&filter[territory]=DEU",
                  "/v1/inAppPurchasePriceSchedules/PLAN-x/automaticPrices?include=inAppPurchasePricePoint&filter[territory]=DEU"):
            reader.get(p)

    def test_price_plan_id_taken_from_schedule_response(self):  # AC-22b
        fake = FakeASC()
        self.assert_iap(fake, True)
        self.assertIn("/v2/inAppPurchases/IAP-life/iapPriceSchedule", fake.paths)
        self.assertIn("/v1/inAppPurchasePriceSchedules/PLAN-x/manualPrices", fake.paths)
        self.assertIn("/v1/inAppPurchasePriceSchedules/PLAN-x/automaticPrices", fake.paths)
        self.assertFalse([p for p in fake.paths if "/inAppPurchasePriceSchedules/IAP-life" in p], fake.paths)
        fake = FakeASC()
        fake.plans["IAP-life"] = None
        self.assert_iap(fake, False, "lifetime")
        self.assertFalse([p for p in fake.paths if "/inAppPurchasePriceSchedules/" in p], fake.paths)

    def test_price_found_under_automatic_prices(self):  # AC-22c
        fake = FakeASC()
        fake.price_entries["IAP-life"] = [("automatic", None, None, "14.99")]
        self.assert_iap(fake, True)
        fake.price_entries["IAP-life"] = [("automatic", None, None, "19.99")]
        out = self.assert_iap(fake, False, "14.99")
        self.assertIn("19.99", out)

    def test_price_ignores_expired_and_future_entries(self):  # AC-22d
        fake = FakeASC()
        fake.price_entries["IAP-life"] = [("manual", "2025-01-01", "2026-10-24", "9.99"),
                                          ("manual", "2026-10-25", None, "14.99"),
                                          ("manual", "2026-10-26", None, "19.99")]
        self.assert_iap(fake, True)
        fake.price_entries["IAP-life"] = [("manual", None, "2026-10-25", "14.99"), ("manual", "2026-10-26", None, "19.99")]
        self.assert_iap(fake, True)  # endDate = heute gilt noch
        fake.price_entries["IAP-life"] = [("manual", None, "2026-10-24", "14.99"), ("manual", "2026-10-26", None, "14.99")]
        self.assert_iap(fake, False, "lifetime")

    def test_price_mapped_via_price_point_not_first(self):  # AC-22e
        fake = FakeASC()
        fake.decoys["IAP-life"] = "4.99"
        fake.price_entries["IAP-life"] = [("manual", None, "2026-01-31", "9.99"), ("manual", "2026-02-01", None, "14.99")]
        self.assert_iap(fake, True)
        fake.price_entries["IAP-life"] = [("manual", None, "2026-01-31", "14.99"), ("manual", "2026-02-01", None, "9.99")]
        self.assert_iap(fake, False, "9.99")
        fake = FakeASC()  # F002: gleiche ID, fremder Typ zählt nicht
        fake.foreign_type_points["IAP-life"] = "4.99"
        fake.price_entries["IAP-life"] = [("manual", None, None, "14.99")]
        self.assert_iap(fake, True)
        fake.foreign_type_points["IAP-life"] = "14.99"
        fake.price_entries["IAP-life"] = [("manual", None, None, None)]
        self.assert_iap(fake, False, "lifetime")

    def test_no_valid_price_is_deviation(self):  # AC-22e
        fake = FakeASC()
        fake.decoys["IAP-life"] = "14.99"
        for entries in ([], [("manual", None, "2026-01-31", "14.99")], [("manual", None, None, None)],
                        [("manual", None, None, "14.99"), ("automatic", None, None, "19.99")]):
            fake.price_entries["IAP-life"] = entries
            self.assert_iap(fake, False, "lifetime")
        fake.price_entries["IAP-life"] = [("manual", None, None, "14.99"), ("automatic", None, None, None)]  # F001
        self.assertIn("Preispunkt fehlt", self.assert_iap(fake, False, "lifetime"))
        fake.price_entries["IAP-life"] = [("manual", None, None, "14.99"), ("automatic", None, None, "14.99")]
        self.assert_iap(fake, True)  # mehrere gültige mit gleichem Betrag

    def test_subscription_price_same_validity_rule(self):  # AC-22f
        fake = FakeASC()
        fake.decoys["SUB-monthly"] = "2.49"
        fake.price_entries["SUB-monthly"] = [("prices", None, "2026-03-31", "2.99"), ("prices", "2026-04-01", None, "1.99"),
                                             ("prices", "2027-01-01", None, "2.49")]
        self.assert_iap(fake, True)
        query = [unquote(urlsplit(c[1]).query) for c in fake.calls if "/v1/subscriptions/SUB-monthly/prices" in c[1]]
        self.assertEqual(query, ["include=subscriptionPricePoint,territory&filter[territory]=DEU"])
        fake.price_entries["SUB-monthly"] = [("prices", None, "2026-03-31", "1.99"), ("prices", "2026-04-01", None, "2.99")]
        out = self.assert_iap(fake, False, "1.99")
        self.assertIn("2.99", out)

    def test_today_is_injectable(self):  # AC-22g
        self.assertIn("today", inspect.signature(asc_check.main).parameters)
        fake = FakeASC()
        fake.price_entries["IAP-life"] = [("manual", None, "2026-12-31", "14.99"), ("manual", "2027-01-01", None, "19.99")]
        self.assert_iap(fake, True, today=datetime.date(2026, 10, 25))
        self.assert_iap(fake, False, "19.99", today=datetime.date(2027, 2, 1))

    def assert_appinfo(self, fake, ok, *needles):
        code, out = run(fake, "--section", "appinfo")
        self.assertEqual(code == 0, ok, out)
        for needle in needles:
            self.assertIn(needle, out)
        return out

    def test_privacy_fetch_sends_user_agent_and_no_authorization(self):  # AC-23a
        page = FakePage()
        guarded = lambda m, u, h, d: page(m, u, h, d) if h.get("User-Agent") == UA else (403, b"")  # sperrt Python-urllib
        code, out = run(FakeASC(), "--section", "privacy-url", page=guarded)
        self.assertEqual(code, 0, out)
        self.assertNotIn("403", out)
        self.assertEqual([(m, u) for m, u, _ in page.calls], [("GET", PRIVACY_URL)])
        self.assertEqual(page.calls[0][2].get("User-Agent"), UA)
        self.assertFalse(any(k.lower() == "authorization" for k in page.calls[0][2]))

    def test_age_rating_all_null_is_deviation(self):  # AC-23b, Antwortform des Erstlaufs
        fake = FakeASC()
        fake.age["attributes"] = age_attrs(lambda i: None)
        out = self.assert_appinfo(fake, False, "ageRatingDeclaration: Soll alle Angaben gesetzt, Ist leer: ")
        line = next(l for l in out.splitlines() if "ageRatingDeclaration" in l)
        self.assertTrue(line.startswith("Abweichung"), line)
        self.assertEqual(line.split("Ist leer: ", 1)[1], ", ".join(AGE_FIELDS))
        self.assertNotRegex(out, r"(?m)^ok\s+appinfo: ageRatingDeclaration")

    def test_age_rating_names_missing_field(self):  # AC-23b
        fake = FakeASC()
        fake.age["attributes"]["lootBox"] = None
        del fake.age["attributes"]["socialMedia"]  # fehlt ganz = leer
        out = self.assert_appinfo(fake, False, "ageRatingDeclaration")
        line = next(l for l in out.splitlines() if "ageRatingDeclaration" in l)
        self.assertEqual(line.split("Ist leer: ", 1)[1], "lootBox, socialMedia")

    def test_age_rating_complete_is_ok(self):  # AC-23b
        fake = FakeASC()  # false und NONE beantwortet; kidsAgeBand, URL und GRAC-Nummer null; Overrides NONE
        out = self.assert_appinfo(fake, True)
        self.assertRegex(out, r"(?m)^ok\s+appinfo: ageRatingDeclaration$")
        fake.age["attributes"] = {f: True for f in AGE_FIELDS}  # ohne die Zusatzfelder
        self.assert_appinfo(fake, True)

    def test_app_price_schedule_without_manual_prices_is_deviation(self):  # AC-23c
        fake = FakeASC()
        fake.app_prices = []
        self.assert_appinfo(fake, False, "Abweichung appinfo: App-Preis (DEU): Soll 0, Ist kein gültiger Preis")
        fake.app_prices = [(None, None, None)]
        self.assert_appinfo(fake, False, "Preispunkt fehlt")
        fake.app_prices = [(None, "2026-10-24", "0.0")]  # abgelaufen
        self.assert_appinfo(fake, False, "App-Preis (DEU)")
        fake = FakeASC()
        fake.base_territory = None
        self.assert_appinfo(fake, False, "Abweichung appinfo: Basisland: Soll DEU, Ist (leer)")

    def test_app_price_schedule_wrong_base_territory(self):  # AC-23c
        fake = FakeASC()
        fake.base_territory = {"id": "USA", "type": "territories"}
        self.assert_appinfo(fake, False, "Abweichung appinfo: Basisland: Soll DEU, Ist USA")
        fake = FakeASC()
        fake.app_prices = [(None, None, "0.99")]
        self.assert_appinfo(fake, False, "Abweichung appinfo: App-Preis (DEU): Soll 0, Ist 0.99")

    def test_app_price_schedule_complete_is_ok(self):  # AC-23c
        fake = FakeASC()
        out = self.assert_appinfo(fake, True)
        self.assertRegex(out, r"(?m)^ok\s+appinfo: Basisland$")
        self.assertRegex(out, r"(?m)^ok\s+appinfo: App-Preis \(DEU\)$")
        self.assertIn("/v1/appPriceSchedules/APS-1/baseTerritory", fake.paths)
        query = [unquote(urlsplit(c[1]).query) for c in fake.calls if "/v1/appPriceSchedules/APS-1/manualPrices" in c[1]]
        self.assertEqual(query, ["include=appPricePoint&filter[territory]=DEU"])
        self.assertFalse([p for p in fake.paths if p.startswith(f"/v1/appPriceSchedules/{APP}")], fake.paths)
        fake.app_prices = [(None, "2026-03-31", "0.99"), ("2026-04-01", None, "0.0")]
        self.assert_appinfo(fake, True)  # nur der zum Stichtag gültige zählt

    def test_availability_404_is_deviation(self):  # AC-23d
        fake = FakeASC()
        fake.status_override[f"/v1/apps/{APP}/appAvailabilityV2"] = 404
        out = self.assert_appinfo(fake, False, "Abweichung appinfo: appAvailabilityV2: Soll eingerichtet, Ist nicht eingerichtet")
        self.assertNotIn("Fehler appinfo", out)
        for rel in ("primaryCategory", "ageRatingDeclaration", "Basisland", "App-Preis (DEU)"):
            self.assertIn(rel, out)  # der Abschnitt läuft weiter
        for status in (403, 500):
            fake.status_override[f"/v1/apps/{APP}/appAvailabilityV2"] = status
            self.assert_appinfo(fake, False, f"Fehler appinfo: HTTP {status} bei GET /v1/apps/{APP}/appAvailabilityV2")

    def test_app_manual_prices_404_is_not_configured(self):  # AC-23c, Nachtrag nach dem zweiten Leselauf
        path = "/v1/appPriceSchedules/APS-1/manualPrices"
        fake = FakeASC()
        fake.status_override[path] = 404  # echte Antwort, solange kein App-Preis eingetragen ist
        out = self.assert_appinfo(fake, False, "Abweichung appinfo: App-Preis (DEU): Soll 0, Ist nicht eingerichtet")
        self.assertNotIn("Fehler appinfo", out)
        self.assertRegex(out, r"(?m)^ok\s+appinfo: Basisland$")
        self.assertIn(f"/v1/apps/{APP}/appAvailabilityV2", fake.paths)  # der Abschnitt läuft weiter
        self.assertRegex(out, r"(?m)^ok\s+appinfo: appAvailabilityV2$")
        for status in (403, 500):
            fake = FakeASC()
            fake.status_override[path] = status
            self.assert_appinfo(fake, False, f"Fehler appinfo: HTTP {status} bei GET {path}")

    def test_404_on_other_path_stays_error(self):  # AC-23d; manualPrices des App-Preisplans ist die Ausnahme aus AC-23c
        for path in ("/v1/appInfos/INFO-1/primaryCategory", f"/v1/apps/{APP}/appPriceSchedule",
                     "/v1/appInfos/INFO-1/ageRatingDeclaration", "/v1/appPriceSchedules/APS-1/baseTerritory"):
            fake = FakeASC()
            fake.status_override[path] = 404
            out = self.assert_appinfo(fake, False, f"Fehler appinfo: HTTP 404 bei GET {path}")
            self.assertNotIn("nicht eingerichtet", out)

    def test_fence_allows_only_app_price_schedule_paths(self):  # AC-23e
        send = mock.Mock(return_value=(200, b"{}"))
        reader = asc_check.Reader("T", send=send)
        reader.ids.update({APP, "APS-1"})
        for p in ("/v1/appPriceSchedules/APS-1/baseTerritory?include=x", "/v1/appPriceSchedules/APS-1/manualPrices",
                  "/v1/appPriceSchedules/APS-1/manualPrices?include=appPricePoint",
                  "/v1/appPriceSchedules/APS-1/automaticPrices?include=appPricePoint&filter[territory]=DEU",
                  "/v1/appPriceSchedules", "/v1/appPriceSchedules/APS-1",
                  "/v1/appPriceSchedules/APS-fremd/baseTerritory"):
            with self.assertRaises(Exception, msg=p):
                reader.get(p)
        send.assert_not_called()
        for m in ("POST", "PATCH"):
            with self.assertRaises(Exception, msg=m):
                asc_check.check_read(m, "/v1/appPriceSchedules/APS-1/baseTerritory", {"APS-1"})
        reader.get("/v1/appPriceSchedules/APS-1/baseTerritory")
        reader.get("/v1/appPriceSchedules/APS-1/manualPrices?include=appPricePoint&filter[territory]=DEU")
        self.assertEqual(send.call_count, 2)

    def test_protocol_has_timestamp_and_commit(self):  # AC-20g
        _, out = run(FakeASC(), "--all")
        head = out.splitlines()[0]
        self.assertIn("2026-10-25T12:00:00Z", head)
        self.assertIn("abc1234def", head)
        _, out = run(FakeASC(), "--all", commit=lambda: None)
        self.assertIn("unbekannt", out.splitlines()[0])

    def test_reader_get_error_includes_apple_code_and_title(self):  # AC-9 (Issue #227)
        raw = json.dumps({"errors": [{"code": "NOT_FOUND", "title": "Nicht da", "detail": "GEHEIMDETAIL"}]}).encode()
        reader = asc_check.Reader("GEHEIMTOKEN", send=lambda *a: (409, raw), today=TODAY)
        with self.assertRaises(asc_check.HttpError) as e:
            reader.get("/v1/apps?filter[bundleId]=com.johannesemmrich.Restock")
        self.assertEqual(e.exception.status, 409)
        msg = str(e.exception)
        self.assertTrue(msg.startswith("HTTP 409 bei GET /v1/apps"), msg)
        self.assertNotIn("filter", msg)
        self.assertIn("NOT_FOUND: Nicht da", msg)
        self.assertNotIn("GEHEIM", msg)
        plain = asc_check.Reader("T", send=lambda *a: (500, b""), today=TODAY)
        with self.assertRaises(asc_check.HttpError) as e:
            plain.get("/v1/apps?filter[bundleId]=com.johannesemmrich.Restock")
        self.assertEqual(str(e.exception), "HTTP 500 bei GET /v1/apps")

    def test_fetch_privacy_ignores_error_body(self):  # AC-10 (Issue #227)
        body = json.dumps({"errors": [{"code": "PRIV_CODE", "title": "PRIV_TITEL"}]}).encode()
        code, out = run(FakeASC(), "--section", "privacy-url", page=FakePage(status=404, body=body))
        self.assertNotEqual(code, 0)
        self.assertIn("404", out)
        self.assertNotIn("PRIV_CODE", out)
        self.assertNotIn("PRIV_TITEL", out)

    def test_error_with_secret_like_detail_never_leaks_in_check(self):  # AC-11 (Issue #227)
        leak = lambda m, u, h, d: (403, json.dumps({"errors": [{"code": "FORBIDDEN", "title": "Nein",
                                                                  "detail": h["Authorization"]}]}).encode())
        code, out = run(leak, "--section", "metadata")
        self.assertNotEqual(code, 0)
        self.assertIn("FORBIDDEN: Nein", out)
        self.assertNotIn("Bearer", out)
        self.assertNotIn(ENV["ASC_KEY_PATH"], out)


if __name__ == "__main__":
    unittest.main()
