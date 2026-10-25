#!/usr/bin/env python3
"""Liest den Entwurf von Version 1.0 aus App Store Connect und vergleicht ihn mit dem Repo (Issue #175, B2b).
Nur GET über einen eigenen Lesezaun; der Schreibweg von asc_lib wird nicht benutzt. Die Datenschutzseite wird
ohne Token abgerufen. Ausgabe je Prüfpunkt „ok“ oder „Abweichung: Feld, Soll, Ist“; Kontaktwerte nur als gesetzt/leer.
Aufruf: --section <metadata|privacy-url|appinfo|iap|screenshots|build|review|status> oder --all."""
import datetime, html, json, os, re, subprocess, sys
from decimal import Decimal
from pathlib import Path
from asc_lib import BUNDLE, HOST, VERSION_QUERY, make_token, openssl_sign, parse_texts, urllib_send

R = Path(__file__).resolve().parent.parent
PRIVACY_URL = "https://emmrich-business.com/datenschutz"
DRAFT = "PREPARE_FOR_SUBMISSION"
LOCALES = {"de-DE": "de.md", "en-US": "en.md"}
VERSION_FIELDS = {"description": "description", "keywords": "keywords", "promotionalText": "promotional_text",
                  "supportUrl": "support_url"}
INFO_FIELDS = {"name": "name", "subtitle": "subtitle", "privacyPolicyUrl": "privacy_url"}
PREFIX = "com.johannesemmrich.smartcart.premium."
PRICES = {"lifetime": "14.99", "monthly": "1.99", "yearly": "8.99"}
# Pfadform der Produkt-Lokalisierungen und Review-Screenshots ist erst in B3 am echten Konto belegt (Spec, API 4.4.1).
PRODUCT_PATHS = {"IAP": ("/v1/inAppPurchases/{id}/inAppPurchaseLocalizations", "/v1/inAppPurchases/{id}/appStoreReviewScreenshot"),
                 "SUB": ("/v1/subscriptions/{id}/subscriptionLocalizations", "/v1/subscriptions/{id}/appStoreReviewScreenshot")}
PRICE_PATHS = {"IAP": "/v1/inAppPurchasePriceSchedules/{id}/manualPrices", "SUB": "/v1/subscriptions/{id}/prices"}
PRICE_QUERY = {"IAP": "include=inAppPurchasePricePoint&filter[territory]=DEU",
               "SUB": "include=subscriptionPricePoint&filter[territory]=DEU"}
SECTIONS = ("metadata", "privacy-url", "appinfo", "iap", "screenshots", "build", "review", "status")
_ID = r"([A-Za-z0-9_-]+)"
FENCE = [(r"/v1/apps", f"filter[bundleId]={BUNDLE}"), (rf"/v1/apps/{_ID}/appStoreVersions", VERSION_QUERY),
         (rf"/v1/apps/{_ID}/(?:appInfos|appPriceSchedule|appAvailabilityV2|inAppPurchasesV2|subscriptionGroups)", None),
         (rf"/v1/appStoreVersions/{_ID}/(?:appStoreVersionLocalizations|build|appStoreReviewDetail)", None),
         (rf"/v1/appInfos/{_ID}/(?:appInfoLocalizations|ageRatingDeclaration|primaryCategory|secondaryCategory)", None),
         (rf"/v1/subscriptionGroups/{_ID}/subscriptions", None),
         (rf"/v1/appStoreVersionLocalizations/{_ID}/appScreenshotSets", None),
         (rf"/v1/appScreenshotSets/{_ID}/appScreenshots", None)]
FENCE += [(p.replace("{id}", _ID), None) for pair in PRODUCT_PATHS.values() for p in pair]
FENCE += [(PRICE_PATHS[k].replace("{id}", _ID), PRICE_QUERY[k]) for k in PRICE_PATHS]


def check_read(method, path, ids):
    """Lesezaun (AC-20a): nur GET, nur relative Pfade der Leseliste, Abfragen exakt, IDs nur aus Antworten."""
    if method != "GET":
        raise ValueError(f"Methode nicht erlaubt: {method}")
    if not isinstance(path, str) or not path.startswith("/") or path.startswith("//"):
        raise ValueError("Pfad muss relativ zu api.appstoreconnect.apple.com sein")
    base, sep, query = path.partition("?")
    for pattern, allowed_query in FENCE:
        m = re.fullmatch(pattern, base)
        if m and (query == allowed_query if sep else allowed_query is None):
            if all(g in ids for g in m.groups()):
                return
            raise ValueError(f"ID nicht aus einer Antwort: GET {base}")
    raise ValueError(f"Pfad nicht erlaubt: GET {base}")


class Reader:
    def __init__(self, token, send=urllib_send):
        self.token, self.send, self.ids = token, send, set()

    def get(self, path):
        check_read("GET", path, self.ids)
        status, raw = self.send("GET", HOST + path, {"Authorization": f"Bearer {self.token}"}, None)
        if not 200 <= status < 300:  # nur Status und Pfad, nie Antworttext oder Token
            raise RuntimeError(f"HTTP {status} bei GET {path.partition('?')[0]}")
        doc = json.loads(raw) if raw else {}
        items = doc.get("data")
        for x in (items if isinstance(items, list) else [items] if items else []) + doc.get("included", []):
            self.ids.add(x["id"])
        return doc

    def data(self, path):
        return self.get(path).get("data")


def fetch_privacy(url, send=urllib_send):
    """Datenschutzseite ohne Authorization-Header; urllib_send folgt keiner Weiterleitung (AC-20b)."""
    if url != PRIVACY_URL:
        raise ValueError("Nur die Datenschutz-URL ist erlaubt")
    return send("GET", url, {}, None)


def flat(value):
    return "(leer)" if value is None else str(value).replace("\n", " ⏎ ")


class Report:
    def __init__(self, out):
        self.out, self.bad = out, 0

    def check(self, sec, field, ok, want="", got=""):
        if ok:
            print(f"ok   {sec}: {field}", file=self.out)
        else:
            self.bad += 1
            print(f"Abweichung {sec}: {field}: Soll {flat(want)}, Ist {flat(got)}", file=self.out)

    def eq(self, sec, field, want, got):
        self.check(sec, field, want == got, want, got)

    def present(self, sec, field, value):
        ok = bool(value.strip() if isinstance(value, str) else value)  # nur Leerzeichen gilt als leer
        self.check(sec, field, ok, "gesetzt", "gesetzt" if ok else "leer")


def one(items, what):
    if not isinstance(items, list) or len(items) != 1:
        raise RuntimeError(f"{what}: {len(items or [])} Treffer statt genau 1")
    return items[0]


def context(rd, ctx):
    """App, Version 1.0 (IOS) und appInfo einmal je Lauf lesen."""
    if not ctx:  # erst nach dem Lesen aller Teile setzen, sonst KeyError in Folgeabschnitten
        app = one(rd.data(f"/v1/apps?filter[bundleId]={BUNDLE}"), f"App {BUNDLE}")
        versions = rd.data(f"/v1/apps/{app['id']}/appStoreVersions?{VERSION_QUERY}")
        ver = one([v for v in versions or [] if v["attributes"].get("versionString") == "1.0"
                   and v["attributes"].get("platform") == "IOS"], "Version 1.0 (IOS)")
        infos = rd.data(f"/v1/apps/{app['id']}/appInfos")
        info = one([i for i in infos or [] if i["attributes"].get("state") == DRAFT] or infos, "appInfo")
        ctx.update(app=app, ver=ver, info=info)
    return ctx["app"]["id"], ctx["ver"]["id"], ctx["info"]["id"]


def by_locale(items):
    return {x["attributes"].get("locale"): x for x in items or []}


def sec_metadata(rd, ctx, rep, page_send):
    _, ver, info = context(rd, ctx)
    texts = {loc: parse_texts(R / "docs" / "appstore" / name) for loc, name in LOCALES.items()}
    for path, fields in ((f"/v1/appStoreVersions/{ver}/appStoreVersionLocalizations", VERSION_FIELDS),
                         (f"/v1/appInfos/{info}/appInfoLocalizations", INFO_FIELDS)):
        locs = by_locale(rd.data(path))
        for loc, src in texts.items():
            if loc not in locs:
                rep.check("metadata", f"{path.split('/')[-1]} ({loc})", False, "vorhanden", "fehlt")
                continue
            for k, f in fields.items():
                rep.eq("metadata", f"{k} ({loc})", src.get(f), locs[loc]["attributes"].get(k))


def norm(text):
    return re.sub(r"\s+", " ", text).strip()


def privacy_expected():
    parts = re.split(r"^## (.+)$", (R / "docs" / "appstore" / "datenschutz.md").read_text(encoding="utf-8"), flags=re.M)
    sections = {parts[i].strip(): parts[i + 1] for i in range(1, len(parts), 2)}
    return {lang: [re.sub(r"^- ", "", norm(l.replace("**", ""))) for l in sections.get(lang, "").splitlines()
                   if l.strip() and l.strip() != "---"] for lang in ("Deutsch", "English")}


def sec_privacy(rd, ctx, rep, page_send):
    status, body = fetch_privacy(PRIVACY_URL, send=page_send)
    rep.eq("privacy-url", "HTTP-Status", 200, status)
    if status != 200:
        return
    text = norm(html.unescape(re.sub(r"<[^>]+>", " ", body.decode("utf-8", "replace"))))
    for lang, lines in privacy_expected().items():
        missing = [l for l in lines if l not in text]
        rep.check("privacy-url", f"Abschnitt {lang} ({len(lines)} Zeilen)", not missing,
                  "alle Zeilen aus docs/appstore/datenschutz.md", f"{len(missing)} fehlen, z. B. {missing[0][:80]}" if missing else "")


def sec_appinfo(rd, ctx, rep, page_send):
    app, _, info = context(rd, ctx)
    rep.present("appinfo", "contentRightsDeclaration", ctx["app"]["attributes"].get("contentRightsDeclaration"))
    cats = {}
    for rel in ("primaryCategory", "secondaryCategory"):
        cats[rel] = rd.data(f"/v1/appInfos/{info}/{rel}")
        rep.present("appinfo", rel, cats[rel])
    rep.eq("appinfo", "Kategorien", {"SHOPPING", "PRODUCTIVITY"}, {c["id"] for c in cats.values() if c})
    rep.present("appinfo", "ageRatingDeclaration", rd.data(f"/v1/appInfos/{info}/ageRatingDeclaration"))
    for rel in ("appPriceSchedule", "appAvailabilityV2"):
        rep.present("appinfo", rel, rd.data(f"/v1/apps/{app}/{rel}"))


def products(rd, app, rep):
    """Liefert {Kurzname: (Art, Ressource)}; meldet fremde und fehlende Produkte."""
    found, seen = {}, []

    def add(kind, x):
        seen.append(x["attributes"].get("productId"))
        found[seen[-1]] = (kind, x)

    for x in rd.data(f"/v1/apps/{app}/inAppPurchasesV2") or []:
        add("IAP", x)
    groups = [g for g in rd.data(f"/v1/apps/{app}/subscriptionGroups") or []
              if g["attributes"].get("referenceName") == "Restock Pro"]
    rep.eq("iap", "Abo-Gruppe „Restock Pro“", 1, len(groups))
    for g in groups:
        for x in rd.data(f"/v1/subscriptionGroups/{g['id']}/subscriptions") or []:
            add("SUB", x)
    for pid in sorted({p for p in seen if seen.count(p) > 1}):
        rep.check("iap", "doppeltes Produkt", False, "genau einmal", f"{pid} {seen.count(pid)}-mal")
    want = {PREFIX + "lifetime": "IAP", PREFIX + "monthly": "SUB", PREFIX + "yearly": "SUB"}
    for pid in sorted(set(found) - set(want)):
        rep.check("iap", "fremdes Produkt", False, "keins", pid)
    result = {}
    for pid, kind in want.items():
        name = pid[len(PREFIX):]
        rep.check("iap", f"{name} vorhanden ({kind})", found.get(pid, (None,))[0] == kind, kind,
                  found[pid][0] if pid in found else "fehlt")
        if found.get(pid, (None,))[0] == kind:
            result[name] = found[pid]
    return result


def check_product(rd, rep, name, kind, item):
    pid, attrs = item["id"], item["attributes"]
    if kind == "IAP":
        rep.eq("iap", f"{name} inAppPurchaseType", "NON_CONSUMABLE", attrs.get("inAppPurchaseType"))
    rep.eq("iap", f"{name} state", "READY_TO_SUBMIT", attrs.get("state"))
    doc = rd.get(f"{PRICE_PATHS[kind].format(id=pid)}?{PRICE_QUERY[kind]}")
    got = next((x["attributes"].get("customerPrice") for x in doc.get("included", [])
                if "customerPrice" in x.get("attributes", {})), None)
    rep.check("iap", f"{name} Preis (DEU)", got is not None and Decimal(str(got)) == Decimal(PRICES[name]), PRICES[name], got)
    locs_path, shot_path = (p.format(id=pid) for p in PRODUCT_PATHS[kind])
    locs = by_locale(rd.data(locs_path))
    for loc in LOCALES:
        a = locs.get(loc, {}).get("attributes", {})
        rep.check("iap", f"{name} Lokalisierung ({loc})", bool(a.get("name")) and bool(a.get("description")),
                  "name und description", "unvollständig" if loc in locs else "fehlt")
    rep.present("iap", f"{name} Review-Screenshot", rd.data(shot_path))


def sec_iap(rd, ctx, rep, page_send):
    app, _, _ = context(rd, ctx)
    for name, (kind, item) in products(rd, app, rep).items():
        check_product(rd, rep, name, kind, item)


def sec_screenshots(rd, ctx, rep, page_send):
    _, ver, _ = context(rd, ctx)
    locs = by_locale(rd.data(f"/v1/appStoreVersions/{ver}/appStoreVersionLocalizations"))
    for loc in LOCALES:
        if loc not in locs:
            rep.check("screenshots", f"Lokalisierung ({loc})", False, "vorhanden", "fehlt")
            continue
        shots = [s for st in rd.data(f"/v1/appStoreVersionLocalizations/{locs[loc]['id']}/appScreenshotSets") or []
                 for s in rd.data(f"/v1/appScreenshotSets/{st['id']}/appScreenshots") or []]
        for s in shots:  # Maße aus den Attributen, nicht aus dem Enum-Namen des Display-Typs (AC-16)
            asset = s["attributes"].get("imageAsset") or {}
            size = f"{asset.get('width')}×{asset.get('height')}"
            if size != "1320×2868":
                rep.check("screenshots", f"Bildmaß ({loc}, {s['id']})", False, "1320×2868", size)
        rep.check("screenshots", f"Anzahl ({loc})", 3 <= len(shots) <= 10, "3 bis 10", len(shots))


def sec_build(rd, ctx, rep, page_send):
    _, ver, _ = context(rd, ctx)
    build = rd.data(f"/v1/appStoreVersions/{ver}/build")
    rep.check("build", "build zugeordnet", bool(build), "zugeordnet", "keiner")
    if not build:
        return
    a = build["attributes"]
    number = str(a.get("version"))
    rep.check("build", "version", number.isdigit() and int(number) >= 37, "≥ 37", number)
    rep.eq("build", "processingState", "VALID", a.get("processingState"))
    rep.check("build", "usesNonExemptEncryption", a.get("usesNonExemptEncryption") is False, False,
              a.get("usesNonExemptEncryption"))


def sec_review(rd, ctx, rep, page_send):
    _, ver, _ = context(rd, ctx)
    detail = rd.data(f"/v1/appStoreVersions/{ver}/appStoreReviewDetail")
    rep.present("review", "appStoreReviewDetail", detail)
    if not detail:
        return
    a = detail["attributes"]
    for field in ("contactFirstName", "contactLastName", "contactEmail", "contactPhone"):
        rep.present("review", field, a.get(field))  # nur gesetzt/leer, nie der Wert (AC-17a)
    rep.check("review", "demoAccountRequired", a.get("demoAccountRequired") is False, False, a.get("demoAccountRequired"))


def sec_status(rd, ctx, rep, page_send):
    context(rd, ctx)
    rep.eq("status", "appVersionState", DRAFT, ctx["ver"]["attributes"].get("appVersionState"))


RUN = dict(zip(SECTIONS, (sec_metadata, sec_privacy, sec_appinfo, sec_iap, sec_screenshots, sec_build, sec_review,
                          sec_status)))


def git_commit():
    try:
        done = subprocess.run(["git", "rev-parse", "HEAD"], cwd=R, capture_output=True, text=True)
    except OSError:
        return None
    return done.stdout.strip() if done.returncode == 0 else None


def main(argv, env=None, send=urllib_send, sign=openssl_sign, out=sys.stdout, page_send=urllib_send, commit=None, now=None):
    if argv == ["--all"]:
        chosen = SECTIONS
    elif len(argv) == 2 and argv[0] == "--section" and argv[1] in SECTIONS:
        chosen = (argv[1],)
    else:
        print(f"Aufruf: --section <{'|'.join(SECTIONS)}> oder --all", file=sys.stderr)
        return 2
    stamp = (now or datetime.datetime.now(datetime.timezone.utc)).strftime("%Y-%m-%dT%H:%M:%SZ")
    print(f"asc_check {stamp} Commit {(commit or git_commit)() or 'unbekannt'}", file=out)
    rep, ctx, failed = Report(out), {}, 0
    try:
        rd = Reader(make_token(os.environ if env is None else env, sign=sign), send=send)
    except Exception as e:  # Meldungen aus asc_lib nennen nie Schlüsselpfad oder Token
        print(f"Fehler: {e}", file=sys.stderr)
        return 1
    for name in chosen:
        print(f"== {name}", file=out)
        try:
            RUN[name](rd, ctx, rep, page_send)
        except Exception as e:  # Zaun- und HTTP-Fehler enthalten nur Status und Pfad
            failed += 1
            print(f"Fehler {name}: {e}", file=out)
    if chosen == SECTIONS:
        print("offen AC-14 App-Privacy-Fragebogen: per API nicht lesbar, manuell belegen (Beleg-Screenshot)", file=out)
    return 0 if rep.bad == 0 and failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
