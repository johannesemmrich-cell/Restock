# Nachweise #194 — In-Memory-Testspeicher ohne CloudKit-Spiegelung

| Datei | Inhalt |
|---|---|
| `test-red-structure.txt` | Strukturtest `scripts/test_inmemory_containers_no_cloudkit.py` gegen den Stand vor dem Fix: 5 Verstöße (Datei:Zeile), Exit 1. Der eingebaute Selbsttest der Erkennung (mehrzeiliger Aufruf) ist grün. |
| `test-red-notificationdigest-full.log`, `test-red-notificationdigest.txt` | Lauf von `NotificationDigestChainTests` (und `ReceiptTextRecognizerTests`) auf iOS 27.0, Simulator `Restock-Validate-27`, am 2026-10-21 08:21 auf dem unveränderten Stand (Gegenprobe des Entwickler-Agenten aus #99, Wegwerf-Kopie von `e9a6b79`, deren Testdateien zu diesem Ticket identisch mit `main` sind). 8× „Restarting after unexpected exit", 16 Zeilen `No eligible connection available`, Klasse nie 8/8. Übernommen statt erneut gefahren, damit der PO nicht weitere acht Absturzmeldungen bekommt; die 24 Absturzberichte `~/Library/Logs/DiagnosticReports/Restock-2026-10-21-*.ips` belegen dasselbe. |
