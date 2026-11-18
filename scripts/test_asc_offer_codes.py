#!/usr/bin/env python3
"""Tests für scripts/asc_offer_codes.py (Issue #273) gegen einen Schein-ASC über die send-Naht. Kein Netz, kein Schlüssel."""
import contextlib, datetime, io, json, stat, sys, tempfile, unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import asc_lib  # noqa: E402
import asc_offer_codes as oc  # noqa: E402

ENV = {"ASC_KEY_ID": "K", "ASC_ISSUER_ID": "I", "ASC_KEY_PATH": "/nicht/da"}
SIGN = lambda data, path: b"\x30\x06\x02\x01\x01\x02\x01\x01"  # noqa: E731
TODAY = datetime.date(2026, 11, 17)
CODES = b"Code\nGEHEIM-AAA111\nGEHEIM-BBB222\n"


class FakeASC:
    """Antwortet wie App Store Connect; zählt alle Aufrufe."""

    def __init__(self, state="APPROVED", live=True, offer=False, batch=False, paid=False, values=(CODES,)):
        self.state, self.live, self.offer, self.batch, self.paid = state, live, offer, batch, paid
        self.values, self.calls, self.bodies, self.fail = list(values), [], {}, {}

    def __call__(self, method, url, headers, data):
        path = url[len(asc_lib.HOST):]
        self.calls.append((method, path))
        if data:
            self.bodies[(method, path.partition("?")[0])] = json.loads(data)
        if (method, path.partition("?")[0]) in self.fail:
            return self.fail[(method, path.partition("?")[0])], b'{"errors":[{"code":"X","title":"T","detail":"geheim"}]}'
        j = lambda doc: (200, json.dumps(doc).encode())  # noqa: E731
        base = path.partition("?")[0]
        if base == "/v1/apps":
            return j({"data": [{"id": "APP1"}]})
        if base == "/v1/apps/APP1/appStoreVersions":
            return j({"data": [{"id": "V1", "attributes": {"appVersionState": "READY_FOR_DISTRIBUTION" if self.live else "REJECTED"}}]})
        if base == "/v1/apps/APP1/inAppPurchasesV2":
            return j({"data": [{"id": "IAP1", "attributes": {"productId": oc.PRODUCT, "state": self.state}},
                               {"id": "IAP9", "attributes": {"productId": "fremd", "state": "APPROVED"}}]})
        if base == "/v2/inAppPurchases/IAP1/offerCodes":
            return j({"data": [{"id": "OFF1", "attributes": {"name": oc.OFFER_NAME}}] if self.offer else []})
        if base == "/v2/inAppPurchases/IAP1/inAppPurchaseAvailability":
            return j({"data": {"id": "AV1"}})
        if base == "/v1/inAppPurchaseAvailabilities/AV1/availableTerritories":
            return j({"data": [{"id": "USA"}, {"id": "DEU"}, {"id": "AUT"}]})
        if base == "/v2/inAppPurchases/IAP1/pricePoints":
            return j({"data": [{"id": "PP0", "attributes": {"customerPrice": "0.0"}}]})
        if method == "POST" and base == "/v1/inAppPurchaseOfferCodes":
            self.offer = True
            return 201, json.dumps({"data": {"id": "OFF1"}}).encode()
        if base == "/v1/inAppPurchaseOfferCodes/OFF1/prices":
            rel = {"pricePoint": {"data": {"type": "inAppPurchasePricePoints", "id": "PP9"}}} if self.paid else {}
            return j({"data": [{"id": f"P{i}", "relationships": rel} for i in range(3)],
                      "included": [{"type": "inAppPurchasePricePoints", "id": "PP9", "attributes": {"customerPrice": "4.99"}}]})
        if method == "PATCH" and base == "/v1/inAppPurchaseOfferCodes/OFF1":
            return j({"data": {"id": "OFF1"}})
        if base == "/v1/inAppPurchaseOfferCodes/OFF1/oneTimeUseCodes":
            return j({"data": [{"id": "B1", "attributes": {"environment": "PRODUCTION", "active": True}}] if self.batch else []})
        if method == "POST" and base == "/v1/inAppPurchaseOfferCodeOneTimeUseCodes":
            self.batch = True
            return 201, json.dumps({"data": {"id": "B1"}}).encode()
        if base == "/v1/inAppPurchaseOfferCodeOneTimeUseCodes/B1/values":
            if headers.get("Accept") != "text/csv":  # wie Apple: ohne CSV-Accept HTTP 406
                return 406, b'{"errors":[{"code":"NOT_ACCEPTABLE","title":"Not Acceptable"}]}'
            v = self.values.pop(0) if len(self.values) > 1 else self.values[0]
            return (404, b"") if v is None else (200, v)
        return 500, b""

    def writes(self):
        return [c for c in self.calls if c[0] != "GET"]


def run(fake, mode="create", today=TODAY):
    out = Path(tempfile.mkdtemp()) / "codes"
    buf, err = io.StringIO(), io.StringIO()
    with contextlib.redirect_stdout(buf), contextlib.redirect_stderr(err):
        rc = oc.main(["x", mode, str(out)], ENV, send=fake, sign=SIGN, today=today, sleep=lambda s: None)
    return rc, buf.getvalue() + err.getvalue(), out


class Fence(unittest.TestCase):
    def test_fence_allows_only_listed_paths_and_exact_queries(self):
        ids = {"APP1", "IAP1", "OFF1", "B1", "AV1"}
        for m, p in [("GET", f"/v1/apps?filter[bundleId]={asc_lib.BUNDLE}"), ("GET", "/v1/apps/APP1/inAppPurchasesV2?limit=200"),
                     ("GET", "/v2/inAppPurchases/IAP1/pricePoints?filter[territory]=DEU&limit=8000"),
                     ("GET", "/v1/inAppPurchaseOfferCodeOneTimeUseCodes/B1/values"), ("POST", "/v1/inAppPurchaseOfferCodes"),
                     ("POST", "/v1/inAppPurchaseOfferCodeOneTimeUseCodes"), ("PATCH", "/v1/inAppPurchaseOfferCodes/OFF1")]:
            oc.check(m, p, ids)
        for m, p in [("DELETE", "/v1/inAppPurchaseOfferCodes/OFF1"), ("GET", "/v1/apps?filter[bundleId]=fremd"),
                     ("GET", "/v1/apps/APP1/inAppPurchasesV2"), ("GET", "/v1/apps/APP1/inAppPurchasesV2?limit=200&x=1"),
                     ("POST", "/v1/inAppPurchaseOfferCodes?x=1"), ("POST", "/v1/subscriptionOfferCodes"),
                     ("PATCH", "/v1/inAppPurchaseOfferCodeOneTimeUseCodes/B1"), ("GET", "//evil/v1/apps"),
                     ("GET", "v1/apps"), ("POST", "/v1/apps/APP1/appStoreVersions")]:
            with self.assertRaises(ValueError, msg=(m, p)):
                oc.check(m, p, ids)

    def test_fence_rejects_id_not_from_response(self):
        with self.assertRaises(ValueError):
            oc.check("PATCH", "/v1/inAppPurchaseOfferCodes/OFF1", {"APP1"})

    def test_asc_lib_allowed_unchanged(self):
        flat = json.dumps(asc_lib.ALLOWED)
        self.assertNotIn("OfferCode", flat)
        self.assertEqual(set(asc_lib.ALLOWED), {"GET", "POST", "PATCH"})


class Flow(unittest.TestCase):
    def test_plan_only_reads_and_prints_plan(self):
        fake = FakeASC()
        rc, log, out = run(fake, "plan")
        self.assertEqual(rc, 0)
        self.assertEqual(fake.writes(), [])
        self.assertIn("500 Einmalcodes", log)
        self.assertIn("3 Länder", log)
        self.assertIn("Trockenlauf", log)
        self.assertFalse(out.exists())

    def test_create_aborts_before_any_write_when_preconditions_fail(self):
        for fake, why in [(FakeASC(state="READY_TO_SUBMIT"), "APPROVED"), (FakeASC(live=False), "READY_FOR_DISTRIBUTION")]:
            rc, log, _ = run(fake)
            self.assertEqual(rc, 1)
            self.assertEqual(fake.writes(), [])
            self.assertIn(why, log)
        fake = FakeASC()
        rc, log, _ = run(fake, today=datetime.date(2026, 11, 1))  # Ablaufdatum mehr als 181 Tage voraus
        self.assertEqual((rc, fake.writes()), (1, []))

    def test_create_happy_path_writes_codes_privately(self):
        fake = FakeASC()
        rc, log, out = run(fake)
        self.assertEqual(rc, 0, log)
        self.assertEqual([c[1].partition("?")[0] for c in fake.writes()],
                         ["/v1/inAppPurchaseOfferCodes", "/v1/inAppPurchaseOfferCodeOneTimeUseCodes"])
        body = fake.bodies[("POST", "/v1/inAppPurchaseOfferCodes")]
        self.assertEqual(body["data"]["relationships"]["inAppPurchase"]["data"]["id"], "IAP1")
        self.assertEqual(body["data"]["attributes"]["customerEligibilities"], oc.ELIGIBILITIES)
        self.assertEqual(sorted(p["relationships"]["territory"]["data"]["id"] for p in body["included"]), ["AUT", "DEU", "USA"])
        self.assertTrue(all("pricePoint" not in p["relationships"] for p in body["included"]))
        batch = fake.bodies[("POST", "/v1/inAppPurchaseOfferCodeOneTimeUseCodes")]["data"]
        self.assertEqual(batch["attributes"], {"numberOfCodes": 500, "expirationDate": oc.EXPIRATION, "environment": "PRODUCTION"})
        self.assertEqual((out / "codes.csv").read_bytes(), CODES)
        self.assertEqual(stat.S_IMODE((out / "codes.csv").stat().st_mode), 0o600)
        self.assertEqual(stat.S_IMODE(out.stat().st_mode), 0o700)
        self.assertNotIn("GEHEIM", log)

    def test_rerun_reuses_offer_and_batch(self):
        fake = FakeASC(offer=True, batch=True)
        rc, log, out = run(fake)
        self.assertEqual((rc, fake.writes()), (0, []))
        self.assertTrue((out / "codes.csv").exists())

    def test_paid_offer_is_deactivated_without_codes(self):
        fake = FakeASC(paid=True)
        rc, log, out = run(fake)
        self.assertEqual(rc, 1)
        self.assertEqual([c[0] for c in fake.writes()], ["POST", "PATCH"])
        self.assertEqual(fake.bodies[("PATCH", "/v1/inAppPurchaseOfferCodes/OFF1")]["data"]["attributes"], {"active": False})
        self.assertFalse(out.exists())

    def test_waits_until_codes_are_ready(self):
        fake = FakeASC(values=(None, b"", CODES))
        rc, log, out = run(fake)
        self.assertEqual(rc, 0, log)
        self.assertEqual(log.count("noch nicht bereit"), 2)

    def test_codes_never_ready_fails_cleanly(self):
        rc, log, out = run(FakeASC(values=(None,)))
        self.assertEqual(rc, 1)
        self.assertIn("später wiederholen", log)

    def test_post_error_is_not_retried_and_hides_detail(self):
        fake = FakeASC()
        fake.fail[("POST", "/v1/inAppPurchaseOfferCodes")] = 503
        rc, log, _ = run(fake)
        self.assertEqual(rc, 1)
        self.assertEqual(len(fake.writes()), 1)
        self.assertIn("HTTP 503", log)
        self.assertNotIn("geheim", log)

    def test_get_5xx_is_retried(self):
        fake = FakeASC()
        fake.fail[("GET", "/v1/apps")] = 502
        rc, log, _ = run(fake, "plan")
        self.assertEqual(rc, 1)
        self.assertEqual(sum(1 for c in fake.calls if c[1].startswith("/v1/apps?")), oc.ATTEMPTS)

    def test_further_pages_are_an_error(self):
        fake = FakeASC()
        orig = fake.__call__

        def paged(method, url, headers, data):
            status, raw = orig(method, url, headers, data)
            if "availableTerritories" in url:
                doc = json.loads(raw)
                doc["links"] = {"next": url + "&cursor=x"}
                raw = json.dumps(doc).encode()
            return status, raw
        rc, log, _ = run(paged, "plan")
        self.assertEqual(rc, 1)
        self.assertIn("weitere Seiten", log)

    def test_ci_lists_offer_code_test(self):
        ci = (Path(__file__).resolve().parent.parent / ".github/workflows/ci.yml").read_text(encoding="utf-8")
        self.assertIn("scripts/test_asc_offer_codes.py", ci)


ROOT = Path(__file__).resolve().parent.parent
WF = ROOT / ".github/workflows/asc-offer-codes.yml"


class Workflow(unittest.TestCase):
    def setUp(self):
        import yaml
        self.text = WF.read_text(encoding="utf-8")
        self.wf = yaml.safe_load(self.text)
        self.job = self.wf["jobs"]["offer-codes"]
        self.runs = "\n".join(s.get("run", "") for s in self.job["steps"])

    def test_workflow_dispatch_only_plan_default_secrets_in_env(self):
        on = self.wf.get("on", self.wf.get(True))
        self.assertEqual(set(on), {"workflow_dispatch"})
        self.assertEqual(on["workflow_dispatch"]["inputs"]["mode"]["default"], "plan")
        self.assertEqual(self.wf["permissions"], {"contents": "read"})
        self.assertEqual({k for k, v in self.job["env"].items() if "secrets." in v}, {"ASC_KEY_ID", "ASC_ISSUER_ID", "ASC_KEY_P8"})
        self.assertNotIn("${{", self.runs)  # keine Ausdrücke im Skripttext (Secrets, Eingaben)

    def test_create_gate_runs_first_and_needs_main_and_confirm(self):
        gate = self.job["steps"][0]
        self.assertEqual(gate["if"], "${{ inputs.mode == 'create' }}")
        self.assertIn('"$GITHUB_REF" != "refs/heads/main"', gate["run"])
        self.assertIn('"$CONFIRM" != "anlegen"', gate["run"])

    def test_only_encrypted_codes_are_uploaded_and_cleanup_trapped(self):
        uploads = [s for s in self.job["steps"] if s.get("uses", "").startswith("actions/upload-artifact")]
        self.assertEqual([u["with"]["path"] for u in uploads], ["offer-codes.csv.gpg"])
        self.assertEqual(uploads[0]["with"]["retention-days"], 7)
        self.assertIn("--recipient-file .github/crash-recipient.asc --encrypt", self.runs)
        self.assertIn("trap 'rm -rf \"$KEY\" \"$OUT\"' EXIT", self.runs)
        self.assertIn("umask 077", self.runs)
        self.assertNotRegex(self.runs, r"\b(cat|head|tail|less)\b[^\n]*codes\.csv")

    def test_docs_explain_fetching_codes(self):
        docs = (ROOT / "docs/testflight-setup.md").read_text(encoding="utf-8")
        self.assertIn("## Offer Codes abholen", docs)
        self.assertIn("-n offer-codes", docs)


if __name__ == "__main__":
    unittest.main()
