# Abschlussbericht #105/#128, Durchgang 2 (Text für Ticket-Kommentare und PR)

**Was geändert wurde:** Der Start-Helfer der gesäten UI-Tests (`UITestLaunch`) schreibt bei einem nötigen
zweiten App-Start jetzt eine Messzeile ins Testprotokoll: Sekunden seit Lauf-Beginn und seit Helferaufruf,
Rechnerlast (1/5/15 min), Prozesskennung der App vor und nach dem Neustart, laufende Startnummer. Nicht
ermittelbare Werte stehen als „unbekannt“. Eine Datei (`RestockUITests/UITestWait.swift`), kein Produktcode.

**Was nicht geklärt ist:** Die Ursache des leeren ersten Starts ist unbekannt und heute nicht
reproduzierbar (5 gültige Versuche, nie leer; Hypothese „laufende Alt-App“ widerlegt, „später
Sitzungsaufbau“ und „parallele Installation“ offen). Es wurde nur eine dauerhafte Messung ergänzt; sie
liefert erst beim nächsten echten Fall Zahlen.

**Weiter gültig:**
- Die Abhilfe aus Durchgang 1 (zweiter Start mit Gegenprobe) bleibt.
- Sechs gesäte Klassen bleiben ungeschützt bzw. uneinheitlich; ihre Umstellung ist vorerst nicht geplant.
- Fehlstarts in Aufräumstarts (`cleaner.launch()`) werden nicht gemessen und nicht gezählt.
- Die Prozesskennung kommt über eine nicht öffentliche Eigenschaft (`processID`); ein künftiges Xcode kann
  sie zu „unbekannt“ machen. Heute (iOS 26.5, Simulator) liefert sie echte Werte (Wegwerf-Lauf).
- Es gibt keine Aussage „alle gesäten Tests starten zuverlässig“.

**Tickets:** #105, #128 und #133 bleiben offen. Geschlossen wird erst, wenn ein echter Fall mit Zahlen
vorliegt oder der PO anders entscheidet.

**Umfang:** +66/−2 Zeilen Testcode (Schätzung der Spec: ca. +40/−5), Limit eingehalten.
