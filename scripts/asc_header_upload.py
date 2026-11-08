#!/usr/bin/env python3
"""Lädt die Kopfbilder (Issue #241) in die App-Asset-Bibliothek und hängt sie an Version 1.0 (de-DE, en-US).
Je Sprache zwei Platzierungen: Seitenkopf 21:9 (3840x1646) und Suchergebnisse 16:9 (5244x2950).
Standard ist der Trockenlauf (nur GET); geschrieben wird nur mit --apply. Eingereicht wird nie etwas.
Umgebung: ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH. Eigener Zaun: asc_lib.ALLOWED bleibt unverändert."""
import json, os, re, sys, urllib.parse
from pathlib import Path
import asc_lib

ART = Path(__file__).resolve().parent.parent / "docs/artifacts/feat-241-kopfbild"
LOCALES = {"de-DE": "de", "en-US": "en"}
SLOTS = [("PRODUCT_PAGE_HEADER_ASSET", "3840x1646"), ("APP_STORE_SEARCH_RESULTS_ASSET", "5244x2950")]
_ID = asc_lib._ID
NEW = {"GET": [rf"/v1/apps/{_ID}/assetLibrary", rf"/v1/appStoreVersionLocalizations/{_ID}/placements",
               rf"/v1/appAssetLibraryImages/{_ID}"],
       "POST": [r"/v1/appAssetLibraryImages", r"/v1/appAssetLibraryPlacements"],
       "PATCH": [rf"/v1/appAssetLibraryImages/{_ID}"]}


def call(method, path, token, body=None):
    if any(re.fullmatch(p, path) for p in NEW.get(method, [])):
        saved = asc_lib.ALLOWED
        asc_lib.ALLOWED = {m: saved.get(m, []) + NEW.get(m, []) for m in ("GET", "POST", "PATCH")}
        try:
            return asc_lib.api(method, path, token, body=body)
        finally:
            asc_lib.ALLOWED = saved
    return asc_lib.api(method, path, token, body=body)


def upload_parts(png, ops):
    data = png.read_bytes()
    for op in ops:
        url = op["url"]
        if urllib.parse.urlparse(url).scheme != "https" or op["method"] != "PUT":
            raise RuntimeError("Upload-Operation nicht https/PUT, Abbruch")
        headers = {h["name"]: h["value"] for h in op.get("requestHeaders", [])}
        status, _ = asc_lib.urllib_send("PUT", url, headers, data[op["offset"]:op["offset"] + op["length"]])
        if not 200 <= status < 300:
            raise RuntimeError(f"Upload-Teil HTTP {status}")


def main(argv):
    apply = "--apply" in argv
    token = asc_lib.make_token(os.environ)
    app = call("GET", f"/v1/apps?filter[bundleId]={asc_lib.BUNDLE}", token)["data"]
    if len(app) != 1:
        raise RuntimeError("App nicht eindeutig")
    app_id = app[0]["id"]
    vers = [v for v in call("GET", f"/v1/apps/{app_id}/appStoreVersions", token)["data"]
            if v["attributes"]["appVersionState"] == "PREPARE_FOR_SUBMISSION"
            and v["attributes"]["platform"] == "IOS"]
    if len(vers) != 1:  # Kopfbilder gehören an die eine Version im Entwurf (Apple lehnt sie sonst mit 409 ab)
        raise RuntimeError(f"{len(vers)} Versionen im Entwurf statt genau 1")
    print(f"Version {vers[0]['attributes']['versionString']}: PREPARE_FOR_SUBMISSION")
    locs = {x["attributes"]["locale"]: x["id"] for x in call(
        "GET", f"/v1/appStoreVersions/{vers[0]['id']}/appStoreVersionLocalizations", token)["data"]}
    lib_id = call("GET", f"/v1/apps/{app_id}/assetLibrary", token)["data"]["id"]
    plan = []
    for locale, lang in LOCALES.items():
        have = call("GET", f"/v1/appStoreVersionLocalizations/{locs[locale]}/placements", token)["data"]
        have_types = {p["attributes"].get("placementType") for p in have}
        for ptype, size in SLOTS:
            png = ART / f"kopfbild-{lang}-{size}.png"
            if ptype in have_types:
                print(f"{locale} {ptype}: schon belegt, übersprungen")
            else:
                plan.append((locale, ptype, png))
                print(f"{locale} {ptype}: {png.name} ({png.stat().st_size} Byte)")
    if not apply:
        print("Trockenlauf, nichts geschrieben (--apply zum Hochladen)")
        return 0
    for locale, ptype, png in plan:
        img = call("POST", "/v1/appAssetLibraryImages", token, {"data": {
            "type": "appAssetLibraryImages",
            "attributes": {"fileName": f"{png.stem}-v101.png", "fileSize": png.stat().st_size, "category": "CREATIVE_ASSETS",
                           "referenceName": f"{png.stem}-v101"},
            "relationships": {"assetLibrary": {"data": {"type": "appAssetLibraries", "id": lib_id}}}}})["data"]
        upload_parts(png, img["attributes"]["uploadOperations"])
        call("PATCH", f"/v1/appAssetLibraryImages/{img['id']}", token, {"data": {
            "type": "appAssetLibraryImages", "id": img["id"], "attributes": {"uploaded": True}}})
        call("POST", "/v1/appAssetLibraryPlacements", token, {"data": {
            "type": "appAssetLibraryPlacements",
            "attributes": {"placementType": ptype, "placementGroup": "DEFAULT_PROFILE"},
            "relationships": {"image": {"data": {"type": "appAssetLibraryImages", "id": img["id"]}},
                              "appStoreVersionLocalization": {"data": {"type": "appStoreVersionLocalizations",
                                                                       "id": locs[locale]}}}}})
        state = call("GET", f"/v1/appAssetLibraryImages/{img['id']}", token)["data"]["attributes"].get("state")
        print(f"{locale} {ptype}: hochgeladen, Bild {img['id']}, Zustand {state}")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv[1:]))
    except (RuntimeError, ValueError, KeyError) as e:
        print(f"Abbruch: {e}", file=sys.stderr)
        sys.exit(1)
