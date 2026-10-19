# Recherche #156 (2026-10-18, Sonnet-Agent, WebFetch)

Nicht auf Gerät/Simulator geprüft. „Belegt“ = Quelle gelesen, „Vermutung“ = nicht belegt.

## 1. Ereignisse bei SwiftData beobachten
- Belegt: SwiftData spiegelt intern über NSPersistentCloudKitContainer; `NSPersistentCloudKitContainer.eventChangedNotification` mit `object: nil` beobachtbar. https://developer.apple.com/forums/thread/763876
- `userInfo[NSPersistentCloudKitContainer.eventNotificationUserInfoKey] as? NSPersistentCloudKitContainer.Event`: `type` (.setup/.import/.export), `succeeded`, `error`, `startDate`, `endDate` (nil solange laufend), `identifier`, `storeIdentifier`.
- Grenze: Ereignisse melden einzelne Import/Export-Läufe, nicht „vollständig abgeglichen“. Kein konfigurierbarer Takt.
- Persistierte Events (`NSPersistentCloudKitContainerEventRequest`) nur mit Core-Data-Zugriff; für reines SwiftData keine Quelle.
- TN3163 (Synchronisation verstehen): https://developer.apple.com/documentation/technotes/tn3163-understanding-the-synchronization-of-nspersistentcloudkitcontainer (nicht abgerufen)

## 2. Fehler im Event
- Belegt: `partialFailure` → `CKPartialErrorsByItemIDKey` / `partialErrorsByItemID`. https://developer.apple.com/documentation/cloudkit/ckerror/partialfailure
- Belegt (Frameworks-Engineer): Live-Notification trägt volle Fehlernutzlast; persistierte nur Domain/Code. `quotaExceeded` kommt nicht zuverlässig an (FB13773922). https://developer.apple.com/forums/thread/830420
- Belegt: In eigener Zone atomar; unschuldige Items bekommen `batchRequestFailed` → den Eintrag suchen, der nicht `batchRequestFailed` ist. https://developer.apple.com/documentation/cloudkit/ckerror
- „Cannot create or modify field 'CD_x' … in production schema“ als BAD_REQUEST, Beispiel fehlendes `CD_moveReceipt_ckAsset`. https://developer.apple.com/forums/thread/845538
- Vermutung: genaue Verschachtelung von `event.error` (CKError, evtl. NSUnderlyingError) unbelegt. Kontostatus separat über `CKContainer.accountStatus()`.

## 3. Duplikate
- Belegt: Apple-Beispiel „Sharing Core Data objects between iCloud users“ dedupliziert Tags nach Remote-Änderung mit Persistent History. https://developer.apple.com/documentation/coredata/sharing_core_data_objects_between_icloud_users
- Belegt (DTS): Gewinner = kleinste UUID; `createdAt` taugt nicht (gleiche Zeiten, Serverzeit je Batch gleich). https://developer.apple.com/forums/thread/772421
- Regel muss auf allen Geräten deterministisch sein, sonst löschen sich Geräte gegenseitig die Gewinner (Ableitung).
- SwiftData: keine dokumentierte Persistent-History-/Merge-Policy-API. https://developer.apple.com/forums/thread/745329
- Vermutung: Dedup per Fetch auf ModelContext nach beendetem `.import`-Event reicht bei kleinen Stores.
- `@Attribute(.unique)` mit CloudKit nicht erlaubt. https://developer.apple.com/forums/thread/656380

## 4. CD_<feld>_ckAsset
- Belegt (Apple-Doku): Jedes String-, Binary-Data- und Transformable-Attribut hat ein Zusatzfeld `CD_<attribut>_ckAsset` (ASSET); Wert wandert hinein, wenn der Record 1 MB überschreitet. https://developer.apple.com/documentation/coredata/reading-cloudkit-records-for-core-data
- Fehlt es in Production, scheitert der Export beim ersten großen Wert (Forum 845538, 772595).
- `@Attribute(.externalStorage)`: keine Quelle, offen.

## 5. iOS 26/27
- Keine neue Sync-Status-API für SwiftData gefunden. Forum „SwiftData CloudKit sync broken on iOS 26“ ohne Lösung. https://developer.apple.com/forums/thread/811675
