# Pflicht-Durchlauf Durchgang 7 (AC-12)

- Stand: Commit a29356d85d1d27bed382f628f32b1e12e4a2648d, Lauf 2026-10-13 22:57 (MESZ)
- Ziel: Simulator Restock-Validate (8F696920-4B9A-40A7-96F0-7697BE887CC7). Kein Gerät des Users berührt (AC-14).
- Bau: `xcodebuild … build` auf Restock-Validate, BUILD SUCCEEDED; installiert mit `simctl install`.
- Start: `-hasCompletedOnboarding YES -developerMode YES -seedReplenishmentForUITests` (keine neuen Argumente).

## Beobachtung

- Startseite zeigt den Banner „Zeit zum Nachkaufen“ mit Bannerbutter und Bannerquark (je „etwa alle 10 Tage“), aus den gesäten Käufen von der App selbst berechnet: `durchlauf-startseite.png`.
- Kein Absturz, kein Absturzbericht in `~/Library/Logs/DiagnosticReports`.
- Ohne erteilte Mitteilungserlaubnis (Simulator, nie gefragt): `scheduledReplenishmentDigests` und `notifiedOverdueReplenishments` existieren in `UserDefaults` der App nicht (`defaults read`: „does not exist“). Es wurde nichts als geplant oder gemeldet geführt, die Artikel bleiben meldbar (Beleg des Produktfixes am echten Weg).
- Aufgeräumt mit `-clearReplenishmentForUITests`.

## Grenzen

Die Zentrale selbst ist von außen nicht lesbar; ihr Inhalt ist nur über die Fake-Zentrale in `NotificationDigestChainTests` belegt. Echte Zustellung um 9:00, vom System gestarteter Hintergrundlauf, `BGTaskScheduler.submit` im Simulator und der Systemdialog der Erlaubnis sind nicht geprüft.
