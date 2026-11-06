# Upload-Weg Kopfbild (Issue #241, AC-8)

Stand: 2026-11-06. Nichts hochgeladen, nichts an Apple gesendet; nur die öffentliche OpenAPI-Datei gelesen.

## Quelle

- `https://developer.apple.com/sample-code/app-store-connect/app-store-connect-openapi-specification.zip`,
  geladen am 2026-11-06, SHA-256 des Zips `f41ed4489c78bf1488cd2291f23394565364fe37b402130f48c3e3c3f5ea1acd`,
  enthält `openapi.oas.json` (Dateidatum 2026-11-04).
- **Version in der Datei: `4.6`** (`info.version`), nicht mehr 4.5.1 wie am 2026-10-25. Eine Fassung 4.5.1 liegt nicht
  mehr vor; ob der unten genannte Weg schon in 4.5.1 stand, ist daher nicht belegt.
- Ausgewertet mit `python3 -I` im Scratchpad (Suche über alle 1027 Pfade und alle Schemata nach
  header/banner/hero/feature/nomination/promotional/artwork/productPage/asset).

## Befund: Die API kennt einen Weg

Es gibt die **App-Asset-Bibliothek** („App Asset Library“) mit Platzierungen für genau die beiden Plätze des Kopfbilds:

| Element in `openapi.oas.json` | Inhalt |
|---|---|
| `components.schemas.AppAssetLibraryPlacementType` (enum) | u. a. `PRODUCT_PAGE_HEADER_ASSET`, `APP_STORE_SEARCH_RESULTS_ASSET` (daneben `APP_SCREENSHOT`, `APP_PREVIEW`, `EVENT_CARD_ASSET`, …) |
| `components.schemas.AppAssetLibraryAssetCategory` (enum) | `CREATIVE_ASSETS`, `APP_SCREENSHOTS_AND_PREVIEWS` |
| `GET /v1/apps/{id}/assetLibrary` | Bibliothek der App (`apps_assetLibrary_getToOneRelated`) |
| `POST /v1/appAssetLibraryImages` | Bild anlegen: `fileName`, `fileSize`, `category`, optional `referenceName`; Beziehung `assetLibrary` (Pflicht), `placements` |
| `AppAssetLibraryImageAwaitingUploadAttributes.uploadOperations` | Hochladen in Teilen wie bei Screenshots (`UploadOperation`), danach `PATCH /v1/appAssetLibraryImages/{id}` mit `uploaded: true` |
| `POST /v1/appAssetLibraryPlacements` | Platzierung: `placementType`, `placementGroup`; Beziehungen `image` und u. a. `appStoreVersionLocalization` (also je Sprache der Version) |
| `GET /v1/appStoreVersionLocalizations/{id}/placements` | Platzierungen einer Sprachfassung lesen |
| `GET /v1/appAssetLibraryRefData` | Vorgaben je Bildart (`imageSpecs`: Mindest-/Höchstmaße, `aspectRatio`, `alphaAllowed`, `compatiblePlacementTypes`, `maxFileSize`) |

Der Ablauf wäre also: Bibliothek der App holen → je Sprache ein Bild (`CREATIVE_ASSETS`) anlegen und hochladen →
Platzierung `PRODUCT_PAGE_HEADER_ASSET` bzw. `APP_STORE_SEARCH_RESULTS_ASSET` an die `appStoreVersionLocalization`
(de-DE, en-US) der Version 1.0 hängen. Die Bildzustände reichen bis `IN_REVIEW`/`APPROVED`/`REJECTED`
(`AppAssetLibraryAssetState`): das Kopfbild durchläuft offenbar eine eigene Prüfung bei Apple.

## Was das für den Upload heißt

- `scripts/asc_lib.py` (`ALLOWED`) kennt keinen dieser Pfade; laut Spec (Requirement 7) darf er erst erweitert werden,
  wenn ein Pfad belegt ist. Das ist hiermit belegt, die Erweiterung selbst ist **nicht** Teil dieses Schritts
  (Scope: keine Änderung an `asc_lib`/`asc_check`) und braucht eine eigene Entscheidung des Tech Leads.
- Ungeklärt: welche `imageSpecs` Apple für die beiden Platzierungen tatsächlich liefert (nur zur Laufzeit über
  `GET /v1/appAssetLibraryRefData` lesbar, nicht in der OpenAPI-Datei), ob `placementGroup` für den Kopf nötig ist und
  ob ein 16:9-Bild beide Platzierungen bedienen kann.
- Rückfallweg unverändert: Upload im Browser (App Store Connect), wie bei den Screenshots.
- In jedem Fall gilt AC-9: hochgeladen wird erst nach getipptem Wort des PO („Upload jetzt“), eingereicht wird nichts.
