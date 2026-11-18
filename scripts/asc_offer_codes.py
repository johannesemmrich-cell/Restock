#!/usr/bin/env python3
"""Legt ein Offer-Code-Angebot „Restock Pro gratis“ für den Einmalkauf an und erzeugt Einmalcodes (Issue #273).
Aufruf: asc_offer_codes.py plan|create <ausgabeordner>; Umgebung ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH.
`plan` liest nur (GET) und schreibt den Plan ins Log. `create` schreibt erst, wenn alle Vorbedingungen gelten,
und legt nur an, was fehlt (erneuter Lauf legt nichts doppelt an). Die Codes landen nur in <ausgabeordner>/codes.csv
(Datei 0600, Ordner 0700), nie im Log: das Repo und seine Lauf-Logs sind öffentlich.
Eigener Zaun im Skript, asc_lib.ALLOWED bleibt unverändert. Eingereicht wird nie etwas."""
import datetime, json, re, sys, time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))  # python3 -I nimmt den Skriptordner nicht in sys.path
from asc_lib import BUNDLE, HOST, apple_error_suffix, make_token, openssl_sign, urllib_send  # noqa: E402

PRODUCT = "com.johannesemmrich.smartcart.premium.lifetime"
OFFER_NAME = "Restock Pro gratis Presse und Tester 2026-11"
ELIGIBILITIES = ["NON_SPENDER", "ACTIVE_SPENDER", "CHURNED_SPENDER"]  # alle Kunden; wer Pro schon besitzt, braucht keinen
NUMBER_OF_CODES = 500  # Apples Mindestmenge je Ausgabe (500 bis 25.000)
EXPIRATION = "2027-05-15"  # Apple erlaubt höchstens sechs Monate
MAX_DAYS = 181
ATTEMPTS, VALUE_ATTEMPTS, VALUE_WAIT = 5, 20, 30

_I = r"([A-Za-z0-9_-][A-Za-z0-9._=-]*)"
READ = [  # (Pfadmuster, exakte Abfrage oder None)
    (r"/v1/apps", f"filter[bundleId]={BUNDLE}"),
    (rf"/v1/apps/{_I}/appStoreVersions", "limit=200"),
    (rf"/v1/apps/{_I}/inAppPurchasesV2", "limit=200"),
    (rf"/v2/inAppPurchases/{_I}/offerCodes", "limit=200"),
    (rf"/v2/inAppPurchases/{_I}/inAppPurchaseAvailability", None),
    (rf"/v1/inAppPurchaseAvailabilities/{_I}/availableTerritories", "limit=200"),
    (rf"/v2/inAppPurchases/{_I}/pricePoints", "filter[territory]=DEU&limit=8000"),
    (rf"/v1/inAppPurchaseOfferCodes/{_I}/prices", "include=pricePoint&limit=200"),
    (rf"/v1/inAppPurchaseOfferCodes/{_I}/oneTimeUseCodes", "limit=200"),
    (rf"/v1/inAppPurchaseOfferCodeOneTimeUseCodes/{_I}/values", None),
]
WRITE = {"POST": [r"/v1/inAppPurchaseOfferCodes", r"/v1/inAppPurchaseOfferCodeOneTimeUseCodes"],
         "PATCH": [rf"/v1/inAppPurchaseOfferCodes/{_I}"]}


def check(method, path, ids):
    """Zaun: nur die Pfade oben, Abfragen exakt, IDs im Pfad nur aus früheren Antworten."""
    if not isinstance(path, str) or not path.startswith("/") or path.startswith("//"):
        raise ValueError("Pfad muss relativ zu api.appstoreconnect.apple.com sein")
    base, sep, query = path.partition("?")
    if method == "GET":
        rules = [(p, q) for p, q in READ if re.fullmatch(p, base) and (q == query if q else not sep)]
    elif method in WRITE:
        rules = [(p, None) for p in WRITE[method] if re.fullmatch(p, base) and not sep]
    else:
        raise ValueError(f"Methode nicht erlaubt: {method}")
    if not rules:
        raise ValueError(f"Pfad nicht erlaubt: {method} {base}")
    m = re.fullmatch(rules[0][0], base)
    if m.groups() and m.group(1) not in ids:
        raise ValueError(f"ID nicht aus einer Antwort: {method} {base}")


class Client:
    def __init__(self, token, send=urllib_send, sleep=time.sleep):
        self.token, self.send, self.sleep, self.ids = token, send, sleep, set()

    def call(self, method, path, body=None, raw=False, missing_ok=False):
        check(method, path, self.ids)
        shown = f"{method} {path.partition('?')[0]}"
        headers = {"Authorization": f"Bearer {self.token}"}
        if raw:  # die Codes liefert Apple nur als CSV, sonst HTTP 406 (Lauf 44258432535)
            headers["Accept"] = "text/csv"
        data = None
        if body is not None:
            headers["Content-Type"] = "application/json"
            data = json.dumps(body).encode()
        for attempt in range(1, ATTEMPTS + 1):
            try:
                status, payload = self.send(method, HOST + path, headers, data)
            except OSError as e:
                failure, retry = f"Netzfehler ({type(e).__name__}) bei {shown}", method == "GET"
            else:
                if 200 <= status < 300:
                    break
                if status == 404 and missing_ok:
                    return None
                failure = f"HTTP {status} bei {shown}{apple_error_suffix(payload)}"
                retry = method == "GET" and (status == 429 or status >= 500)  # Schreiben nie blind wiederholen
            if not retry or attempt == ATTEMPTS:
                raise RuntimeError(failure)
            self.sleep(attempt)
        if raw:
            return payload
        doc = json.loads(payload) if payload else {}
        if (doc.get("links") or {}).get("next"):
            raise RuntimeError(f"Antwort hat weitere Seiten, nicht vorgesehen: {shown}")
        items = doc.get("data")
        for x in items if isinstance(items, list) else [items] if isinstance(items, dict) else []:
            if isinstance(x, dict) and isinstance(x.get("id"), str):
                self.ids.add(x["id"])
        return doc


def data(doc):
    items = (doc or {}).get("data") or []
    return items if isinstance(items, list) else [items]


def gather(c):
    """Liest den Ist-Stand; schreibt nichts."""
    apps = data(c.call("GET", f"/v1/apps?filter[bundleId]={BUNDLE}"))
    if len(apps) != 1:
        raise RuntimeError(f"App zur Bundle-ID: {len(apps)} Treffer statt 1")
    app = apps[0]["id"]
    versions = data(c.call("GET", f"/v1/apps/{app}/appStoreVersions?limit=200"))
    live = any("READY_FOR_DISTRIBUTION" in (v.get("attributes", {}).get("appVersionState"),
                                              v.get("attributes", {}).get("appStoreState")) for v in versions)
    iaps = [x for x in data(c.call("GET", f"/v1/apps/{app}/inAppPurchasesV2?limit=200"))
            if x.get("attributes", {}).get("productId") == PRODUCT]
    if len(iaps) != 1:
        raise RuntimeError(f"Einmalkauf {PRODUCT}: {len(iaps)} Treffer statt 1")
    iap = iaps[0]["id"]
    offers = [o for o in data(c.call("GET", f"/v2/inAppPurchases/{iap}/offerCodes?limit=200"))
              if o.get("attributes", {}).get("name") == OFFER_NAME]
    avail = data(c.call("GET", f"/v2/inAppPurchases/{iap}/inAppPurchaseAvailability"))
    territories = sorted(t["id"] for t in data(c.call(
        "GET", f"/v1/inAppPurchaseAvailabilities/{avail[0]['id']}/availableTerritories?limit=200"))) if avail else []
    points = data(c.call("GET", f"/v2/inAppPurchases/{iap}/pricePoints?filter[territory]=DEU&limit=8000"))
    zero = any(is_zero(p.get("attributes", {}).get("customerPrice")) for p in points)
    return {"iap": iap, "state": iaps[0].get("attributes", {}).get("state"), "live": live, "offers": offers,
            "territories": territories, "zero_point_deu": zero}


def is_zero(value):
    try:
        return float(value) == 0
    except (TypeError, ValueError):
        return False


def problems(s, today):
    out = []
    if not s["live"]:
        out.append("keine Version im Zustand READY_FOR_DISTRIBUTION (Apple verlangt eine veröffentlichte App)")
    if s["state"] != "APPROVED":
        out.append(f"Einmalkauf nicht freigegeben (Zustand {s['state']}, Apple verlangt APPROVED)")
    if not s["territories"]:
        out.append("Einmalkauf in keinem Land verfügbar")
    days = (datetime.date.fromisoformat(EXPIRATION) - today).days
    if not 0 < days <= MAX_DAYS:
        out.append(f"Ablaufdatum {EXPIRATION} liegt nicht in den nächsten {MAX_DAYS} Tagen")
    if len(s["offers"]) > 1:
        out.append(f"Angebot „{OFFER_NAME}“ gibt es {len(s['offers'])}-mal")
    return out


def offer_body(territories):
    prices = [{"type": "inAppPurchaseOfferPrices", "id": f"${{p-{t}}}",
               "relationships": {"territory": {"data": {"type": "territories", "id": t}}}} for t in territories]
    return {"data": {"type": "inAppPurchaseOfferCodes",
                     "attributes": {"name": OFFER_NAME, "customerEligibilities": ELIGIBILITIES},
                     "relationships": {"inAppPurchase": {"data": {"type": "inAppPurchases", "id": None}},
                                       "prices": {"data": [{"type": p["type"], "id": p["id"]} for p in prices]}}},
            "included": prices}


def free_everywhere(c, offer):
    """Gratis heißt: kein Preispunkt oder ein Preispunkt mit Kundenpreis 0, und das in jedem Land des Angebots."""
    doc = c.call("GET", f"/v1/inAppPurchaseOfferCodes/{offer}/prices?include=pricePoint&limit=200")
    amounts = {(x.get("type"), x.get("id")): x.get("attributes", {}).get("customerPrice") for x in doc.get("included", [])}
    rows = data(doc)
    paid = [r for r in rows if (pp := (r.get("relationships", {}).get("pricePoint") or {}).get("data"))
            and not is_zero(amounts.get((pp.get("type"), pp.get("id"))))]
    return bool(rows) and not paid, len(rows)


def fetch_values(c, batch, sleep):
    for attempt in range(1, VALUE_ATTEMPTS + 1):
        raw = c.call("GET", f"/v1/inAppPurchaseOfferCodeOneTimeUseCodes/{batch}/values", raw=True, missing_ok=True)
        if raw and raw.strip():
            return raw
        print(f"Codes noch nicht bereit (Versuch {attempt}/{VALUE_ATTEMPTS})", flush=True)
        if attempt < VALUE_ATTEMPTS:
            sleep(VALUE_WAIT)
    raise RuntimeError("Codes nach Wartezeit nicht abrufbar; Lauf später wiederholen (legt nichts doppelt an)")


def run(mode, out, c, today, sleep=time.sleep):
    s = gather(c)
    print(f"Plan: Angebot „{OFFER_NAME}“ für {PRODUCT}, gratis, Berechtigte {', '.join(ELIGIBILITIES)}")
    print(f"Plan: {NUMBER_OF_CODES} Einmalcodes (PRODUCTION), gültig bis {EXPIRATION}, {len(s['territories'])} Länder")
    print(f"Ist: Einmalkauf {s['state']}, App veröffentlicht: {'ja' if s['live'] else 'nein'}, "
          f"Angebot vorhanden: {'ja' if s['offers'] else 'nein'}, Preispunkt 0 in DEU: {'ja' if s['zero_point_deu'] else 'nein'}")
    found = problems(s, today)
    for p in found:
        print(f"Vorbedingung fehlt: {p}")
    if mode == "plan":
        print("Trockenlauf: nichts angelegt.")
        return 0
    if found:
        print("Abbruch vor jedem Schreiben.")
        return 1
    if s["offers"]:
        offer = s["offers"][0]["id"]
        print("Angebot vorhanden, wird weiterverwendet.")
    else:
        body = offer_body(s["territories"])
        body["data"]["relationships"]["inAppPurchase"]["data"]["id"] = s["iap"]
        offer = c.call("POST", "/v1/inAppPurchaseOfferCodes", body)["data"]["id"]
        print("Angebot angelegt.")
    free, count = free_everywhere(c, offer)
    if not free:
        c.call("PATCH", f"/v1/inAppPurchaseOfferCodes/{offer}",
               {"data": {"type": "inAppPurchaseOfferCodes", "id": offer, "attributes": {"active": False}}})
        print(f"Angebot ist nicht in allen {count} Ländern gratis; deaktiviert, keine Codes erzeugt.")
        return 1
    print(f"Geprüft: gratis in {count} Ländern.")
    batches = [b for b in data(c.call("GET", f"/v1/inAppPurchaseOfferCodes/{offer}/oneTimeUseCodes?limit=200"))
               if b.get("attributes", {}).get("environment", "PRODUCTION") == "PRODUCTION"
               and b.get("attributes", {}).get("active") is not False]
    if batches:
        batch = batches[0]["id"]
        print("Code-Ausgabe vorhanden, wird weiterverwendet.")
    else:
        batch = c.call("POST", "/v1/inAppPurchaseOfferCodeOneTimeUseCodes", {"data": {
            "type": "inAppPurchaseOfferCodeOneTimeUseCodes",
            "attributes": {"numberOfCodes": NUMBER_OF_CODES, "expirationDate": EXPIRATION, "environment": "PRODUCTION"},
            "relationships": {"offerCode": {"data": {"type": "inAppPurchaseOfferCodes", "id": offer}}}}})["data"]["id"]
        print("Code-Ausgabe angelegt.")
    raw = fetch_values(c, batch, sleep)
    out.mkdir(mode=0o700, parents=True, exist_ok=True)
    out.chmod(0o700)
    target = out / "codes.csv"
    target.touch(mode=0o600)
    target.chmod(0o600)
    target.write_bytes(raw)
    lines = [ln for ln in raw.decode("utf-8", "replace").splitlines() if ln.strip()]
    print(f"Codes abgelegt: {len(lines)} Zeilen (Inhalt nicht im Log).")
    return 0


def main(argv, env, send=urllib_send, sign=openssl_sign, today=None, sleep=time.sleep):
    if len(argv) != 3 or argv[1] not in ("plan", "create"):
        print("Aufruf: asc_offer_codes.py plan|create <ausgabeordner>", file=sys.stderr)
        return 2
    try:
        c = Client(make_token(env, sign=sign), send=send, sleep=sleep)
        return run(argv[1], Path(argv[2]), c, today or datetime.date.today(), sleep=sleep)
    except (RuntimeError, ValueError, KeyError, IndexError, TypeError) as e:
        print(f"Fehler: {type(e).__name__}: {e}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    import os
    sys.exit(main(sys.argv, os.environ))
