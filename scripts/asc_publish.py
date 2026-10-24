#!/usr/bin/env python3
"""Schreibt die Store-Texte aus docs/appstore/{de,en}.md nach App Store Connect (Issue #175, B2a).
Standard ist der Trockenlauf (nur GET, Plan ausgeben); geschrieben wird nur mit --apply.
Umgebung: ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH (Pfad zur .p8, wird nur an openssl übergeben)."""
import os, sys
from pathlib import Path
import asc_lib

BUNDLE = asc_lib.BUNDLE
DRAFT = "PREPARE_FOR_SUBMISSION"
SOURCES = {"de-DE": "de.md", "en-US": "en.md"}
VERSION_FIELDS = {"description": "description", "keywords": "keywords", "promotionalText": "promotional_text",
                  "supportUrl": "support_url"}
INFO_FIELDS = {"name": "name", "subtitle": "subtitle", "privacyPolicyUrl": "privacy_url"}


def one(items, what):
    if len(items) != 1:
        raise RuntimeError(f"{what}: {len(items)} Treffer statt genau 1")
    return items[0]


def check_state(get):
    """Nur GETs; liefert (Version-ID, appInfo-ID) oder bricht vor jedem Schreiben ab (AC-10d)."""
    app_id = one(get(f"/v1/apps?filter[bundleId]={BUNDLE}"), f"App {BUNDLE}")["id"]
    versions = get(f"/v1/apps/{app_id}/appStoreVersions?{asc_lib.VERSION_QUERY}")
    ver = one([v for v in versions if v["attributes"].get("versionString") == "1.0"
               and v["attributes"].get("platform") == "IOS"], "Version 1.0 (IOS)")
    if ver["attributes"].get("appVersionState") != DRAFT:
        raise RuntimeError(f"Version 1.0 ist im Zustand {ver['attributes'].get('appVersionState')}, erwartet {DRAFT}")
    info = one([i for i in get(f"/v1/apps/{app_id}/appInfos") if i["attributes"].get("state") == DRAFT],
               f"appInfo im Zustand {DRAFT}")
    return ver["id"], info["id"]


def plan_for(get, kind, parent_path, fields, rel, rel_type, parent_id, texts):
    existing = {x["attributes"]["locale"]: x for x in get(parent_path)}
    plan = []
    for locale, src in texts.items():
        want = {k: src[f] for k, f in fields.items()}
        if locale in existing:
            cur = existing[locale]
            diff = {k: v for k, v in want.items() if cur["attributes"].get(k) != v}
            if diff:
                body = {"data": {"type": kind, "id": cur["id"], "attributes": diff}}
                rows = [(k, cur["attributes"].get(k), v) for k, v in diff.items()]
                plan.append(("PATCH", f"/v1/{kind}/{cur['id']}", body, locale, rows))
        else:
            body = {"data": {"type": kind, "attributes": {"locale": locale, **want},
                             "relationships": {rel: {"data": {"type": rel_type, "id": parent_id}}}}}
            plan.append(("POST", f"/v1/{kind}", body, locale, [(k, None, v) for k, v in want.items()]))
    return plan


def build_plan(get, ver_id, info_id, texts):
    return (plan_for(get, "appStoreVersionLocalizations", f"/v1/appStoreVersions/{ver_id}/appStoreVersionLocalizations",
                     VERSION_FIELDS, "appStoreVersion", "appStoreVersions", ver_id, texts)
            + plan_for(get, "appInfoLocalizations", f"/v1/appInfos/{info_id}/appInfoLocalizations",
                       INFO_FIELDS, "appInfo", "appInfos", info_id, texts))


def short(value, n=60):
    if value is None:
        return "(leer)"
    flat = str(value).replace("\n", " ⏎ ")
    return flat if len(flat) <= n else flat[:n] + "…"


def print_plan(plan, out):
    for method, path, _, locale, rows in plan:
        kind = path.split("/")[2]
        for field, old, new in rows:
            print(f"{method} {kind} {locale} {field}: {short(old)} -> {short(new)}", file=out)
    print(f"{len(plan)} Schreibaufrufe geplant.", file=out)


def main(argv, env=os.environ, send=asc_lib.urllib_send, sign=asc_lib.openssl_sign, out=sys.stdout):
    unknown = [a for a in argv if a != "--apply"]
    if unknown:
        print(f"Unbekannte Argumente: {' '.join(unknown)} (erlaubt: --apply)", file=sys.stderr)
        return 2
    try:
        root = Path(__file__).resolve().parent.parent / "docs" / "appstore"
        texts = {loc: asc_lib.parse_texts(root / name) for loc, name in SOURCES.items()}
        token = asc_lib.make_token(env, sign=sign)
        get = lambda p: asc_lib.api("GET", p, token=token, send=send).get("data", [])
        ver_id, info_id = check_state(get)
        plan = build_plan(get, ver_id, info_id, texts)
        print_plan(plan, out)
        if "--apply" not in argv:
            print("Trockenlauf: nichts geschrieben. Schreiben mit --apply.", file=out)
            return 0
        for method, path, body, _, _ in plan:
            asc_lib.api(method, path, token=token, send=send, body=body)
            print(f"ok {method} {path}", file=out)
        print("Fertig.", file=out)
        return 0
    except Exception as e:  # Meldungen aus asc_lib enthalten nur Status und Pfad
        print(f"Fehler: {e}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
