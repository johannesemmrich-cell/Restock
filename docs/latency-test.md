# Latenz-Näherung: Server gegen CloudKit

Keine wissenschaftliche Messung, nur eine Größenordnung. Ziel: Ist „Haken gesetzt → beim Partner sichtbar“ im Laden deutlich schneller als mit CloudKit?

## Teil A: Websocket-Server (Hetzner), ca. 5 Minuten

1. Auf dem Server (nichts davon öffnet einen Port nach außen):
   `pip install websockets && python3 scripts/latency/ws_server.py`
2. Auf dem Mac, Terminal 1: `ssh -N -L 8765:127.0.0.1:8765 <benutzer>@<server>`
3. Auf dem Mac, Terminal 2: `pip install websockets && python3 scripts/latency/ws_client.py 50`
4. Ergebnis notieren (Median, p95). Einweg ≈ RTT / 2.

Grenze: Messung über den SSH-Tunnel und vom Mac, nicht vom iPhone im Mobilfunk. Die Zahl ist eher zu schlecht als zu gut. Es fehlt die App-Schicht (Datenbank, Auth).

## Teil B: CloudKit mit zwei iPhones, ca. 15 Minuten

Voraussetzung: zwei iPhones mit zwei Apple-IDs, eine geteilte Liste.

1. Beide Geräte nebeneinander legen und mit einem dritten Gerät als Video (60 fps) filmen.
2. A hakt einen Artikel ab. Beim Video die Frames bis zur Änderung auf B zählen (Frames / 60 = Sekunden).
3. 10 Durchläufe je Fall:
   - B im Vordergrund, WLAN
   - B im Vordergrund, Mobilfunk
   - B im Hintergrund (Display an, andere App), WLAN
   - B gesperrt
4. Median und Maximum je Fall notieren.

## Ergebnistabelle

| Fall | Median | Maximum |
|---|---|---|
| Server (Teil A), Einweg | | |
| CloudKit, Vordergrund, WLAN | | |
| CloudKit, Vordergrund, Mobilfunk | | |
| CloudKit, Hintergrund | | |
| CloudKit, gesperrt | | |

## Faustregel für die Entscheidung

- CloudKit im Vordergrund unter 3 s und Hintergrund akzeptabel: CloudKit/CKShare genügt, kein eigenes Backend nötig.
- CloudKit im Vordergrund regelmäßig über 5 s: eigenes Backend lohnt sich für „live im Laden“.
- Dazwischen: Entscheidung nach Zielgruppe (WGs/PWA sprechen für das eigene Backend).
