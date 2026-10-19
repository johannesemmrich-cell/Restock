# CloudKit-Schema `CommunityPrice`: Deploy nach Production (2026-10-19)

Bericht von Henning (PO), Weg: CloudKit-Dashboard statt `cktool` (auf dem Mac war keine Shell
verfügbar). Deshalb keine `.ckdb`-Exporte und keine Datei-Diffs; die Kontrolle lief über die
Dashboard-Ansichten. Wortlaut unverändert übernommen, nur Überschrift und Einordnung ergänzt.

Container `iCloud.com.johannesemmrich.SmartCart`, Team `XK87E2B3VR`.

- Vorher-Diff Dev→Prod: Record Types (0), Indexes (0), Security Roles (0)
- Deploy-Vorschau (bestätigt):
  - Record Types (1): Create CommunityPrice – 12 Felder (6 System + 6 eigene)
  - Indexes (1): Create 16 indexes for CommunityPrice
  - Security Roles: `_world` +read, `_icloud` +create, `_creator` +write (nur für den neuen Typ)
  - Keine anderen Typen, keine Löschungen, keine geänderten Felder.
- Nachher-Diff Dev→Prod: Record Types (0), Indexes (0), Security Roles (0) → Production entspricht Development.

`CommunityPrice` in Production, aus dem Dashboard abgeleitet, kein cktool-Export:

```
RECORD TYPE CommunityPrice (
    "___createTime" TIMESTAMP,
    "___createdBy"  REFERENCE,
    "___etag"       STRING,
    "___modTime"    TIMESTAMP,
    "___modifiedBy" REFERENCE,
    "___recordID"   REFERENCE,
    chain           STRING QUERYABLE SEARCHABLE SORTABLE,
    clientID        STRING QUERYABLE SEARCHABLE SORTABLE,
    itemKey         STRING QUERYABLE SEARCHABLE SORTABLE,
    observedAt      TIMESTAMP QUERYABLE SORTABLE,
    price           DOUBLE QUERYABLE SORTABLE,
    unit            STRING QUERYABLE SEARCHABLE SORTABLE,
    GRANT WRITE TO "_creator",
    GRANT CREATE TO "_icloud",
    GRANT READ TO "_world"
);
```

Alle anderen Typen in Prod haben dieselbe Feldzahl wie in Dev (CD_FeedbackItem 13,
CD_PurchaseRecord 15, CD_ShoppingItem 33, CD_Store 27, CD_TodoItem 12, SharedItemPhoto 8,
SharedStore 16, Users 7). In Prod nur gelesen, dort nichts verändert.

## Einordnung (Tech Lead)

- Der Block ist zeichengleich mit `docs/cloudkit/private-schema-aktuell.ckdb` (Vorlage aus PR #168).
- 16 Indizes passen zu den Markierungen: `chain`, `clientID`, `itemKey`, `unit` je 3
  (QUERYABLE, SEARCHABLE, SORTABLE), `observedAt`, `price` je 2 (QUERYABLE, SORTABLE).
- Maschineller Export nachgeholt am 2026-10-19, 11:49 UTC: `.github/workflows/cloudkit-schema.yml`
  `mode=export` (Issue #169, Lauf 3, run 39247424086) exportierte Development und Production mit
  `cktool`: je 9 Record-Typen, `diff development.ckdb production.ckdb` leer. `CommunityPrice` steht in
  beiden Exporten mit den sechs Feldern und Indizes wie oben. Der Development-Export ist seitdem
  byteidentisch `docs/cloudkit/private-schema-aktuell.ckdb`.
