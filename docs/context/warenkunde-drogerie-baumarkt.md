# Warenkunde Drogerie & Baumarkt

Abstraktes Wissen über Artikel außerhalb des Lebensmittelregals, gesammelt für Issue #221 am 2026-10-25.
Es dient als Grundlage für `AssignmentService+NonFoodCategories.swift` und für künftige Erweiterungen
(Preiskatalog, Bon-Namensauflösung, Zuordnung zum Laden). Quellen: Sortimentsgliederungen von dm,
Rossmann, Müller, Hornbach, OBI, Bauhaus und toom (Websuche, Stand 2026-10-25) und die Fehlerfälle der
bisherigen Zuordnung.

## 1. Wie Fachmärkte ihr Sortiment gliedern

**Drogerie** (dm, Rossmann, Müller) denkt in Körperzonen und Lebenslagen, nicht in Produktarten:
Make-up (Augen, Lippen, Nägel, Teint), Pflege & Parfum (Gesicht, Körper, Dusche, Rasur, Sonne, Düfte),
Haare (Shampoo, Spülung, Styling, Färben, Bürsten), Gesundheit (Zahnpflege, Vitamine, Erkältung,
Verbandsmaterial, Tests), Baby & Kind (Windeln, Nahrung, Pflege, Stillen), Haushalt (Waschen, Putzen,
Papier, Müllbeutel, Kerzen), Tier (Futter, Streu, Zubehör), dazu Ernährung (Bio, Nüsse, Müsli, Getränke)
und Randsortimente (Foto, Schreibwaren, Spielzeug, Textilien). Hygieneartikel (Damenhygiene, Taschentücher,
Toilettenpapier, Wattepads) hängen zwischen Pflege und Haushalt; im Supermarkt stehen sie als
„Drogerie“-Gang zusammen.

**Baumarkt** (Hornbach, OBI, Bauhaus, toom) gliedert nach Gewerk und Material, so wie ein Haus gebaut wird:
Baustoffe (Rohbau, Trockenbau, Dämmung, Dach, Steine, Kleb- und Dichtstoffe, Bauelemente wie Türen und
Fenster), Holz (Bauholz, Platten, Leisten, Terrasse, Zaun), Bodenbeläge & Fliesen (Laminat, Vinyl, Parkett,
Fliesen, Fugen, Sockelleisten, Estrich), Eisenwaren (Schrauben, Dübel, Nägel, Beschläge, Schlösser, Seile,
Ketten, Haken), Farben & Tapeten (Wandfarbe, Lack, Lasur, Grundierung, Tapete, Malerwerkzeug), Sanitär &
Heizung (Rohre, Armaturen, Dichtungen, Bad, Heizkörper, Klima), Leuchten & Elektro (Kabel, Schalter, Dosen,
Sicherungen, Leuchten, Leuchtmittel), Maschinen & Werkzeug (Hand- und Elektrowerkzeug, Zubehör,
Arbeitsschutz, Leitern, Werkstatt), Garten (Erde, Dünger, Saatgut, Bewässerung, Geräte, Zaun, Möbel, Grill,
Pool, Teich) und Pflanzen (Gartencenter: Beet, Kübel, Zimmer, Hecke, Obst, Kräuter, Saatgut).

## 2. Regale, die in mehreren Märkten dieselben sind

Die App bildet nicht Händler ab, sondern Regale. Gleiche Regale: Zahnpflege gibt es bei dm, Rewe und
Lidl; Tierbedarf bei dm, Rewe und Fressnapf; Pflanzen bei Hornbach, OBI und als Schnittblumen an jeder
Supermarktkasse; Reinigung in Drogerie und Supermarkt; Elektronik (Batterien, Glühbirnen) bei Action, dm
und Hornbach. Deshalb trägt jedes Stichwort zwei getrennte Informationen: das **Regal** (Kategorie, überall
gleich) und den **bevorzugten Ladentyp** (wo der Artikel zuerst gesucht wird; nil, wenn Supermarkt und
Fachmarkt gleich plausibel sind).

## 3. Regeln, die sich aus der deutschen Wortbildung ergeben

- **Das Grundwort steht hinten.** „Haarfarbe“ ist Haarpflege, nicht Farbe; „Katzenmilch“ ist Tierbedarf,
  nicht Milch; „Reinigungsmilch“ ist Kosmetik. Darum gewinnt das **längste** Stichwort, nie das erste, und
  Komposita brauchen eigene Einträge, sobald ihr Grundwort in die Irre führt.
- **Endungen tragen Bedeutung**, wenn nichts Genaueres bekannt ist: „…schrauben“, „…dübel“, „…beschlag“ →
  Eisenwaren; „…futter“, „…streu“, „…leckerli“ → Tierbedarf; „…shampoo“, „…spülung“, „…tönung“ → Haarpflege;
  „…tabletten“, „…tropfen“, „…salbe“ → Medikamente; „…reiniger“, „…waschmittel“ → Reinigung; „…fliese“,
  „…laminat“, „…parkett“ → Boden & Fliesen; „…dünger“, „…erde“, „…mulch“ → Garten; „…pflanze“, „…setzlinge“,
  „…stauden“ → Pflanzen; „…kabel“, „…leuchte“, „…schalter“ → Elektronik; „…rohr“, „…ventil“, „…armatur“ →
  Sanitär; „…farbe“, „…lack“, „…lasur“ → Farbe & Lack.
- **Kurze Wörter sind Fallen.** „öl“ (Olivenöl/Holzöl), „creme“ (Eiscreme/Handcreme), „band“ (Türband/
  Haarband), „schloss“, „sand“ (Sandwich), „tür“ (natürlich, türkisch), „putz“ (Putzmittel/Innenputz), „kette“
  (Lichterkette), „reibe“ (Kugelschreiber), „streu“ (Streusel), „samen“ (Leinsamen), „eibe“ (Scheibe), „jasmin“
  (Jasminreis), „erika“ (Amerikaner), „nuts“ (Lebensmittel), „hose“/„hoe“ (Hosen, Schuhe), „tap“ (Tapete).
  Solche Wörter gehören nicht in eine Teilstring-Liste; stattdessen die konkreten Komposita.
- **Lebensmittel mit Non-Food-Stamm** brauchen Ausnahmen: Pflanzenöl, Pflanzenmilch, Streusel, Zuckerwatte,
  Nusscreme, Buttercreme, Eiscreme, Crème fraîche, Nagelkäse, Jasminreis, Chiasamen, Proteinriegel,
  Amerikaner, Heumilch, Eierlikör.

## 4. Mehrdeutigkeiten, die bewusst entschieden wurden

| Artikel | Regal | Ladentyp | Grund |
|---|---|---|---|
| Toilettenpapier, Küchenrolle, Taschentücher | Hygieneartikel | Drogerie | Papier liegt im Drogeriegang, nicht bei Reinigung |
| Müllbeutel, Alufolie, Gefrierbeutel, Backpapier | Haushaltswaren | Sonstiges | Verbrauchsartikel, kein Pflegeprodukt |
| Kerzen, Teelichter, Lichterketten | Dekoration | Sonstiges | wie bisher (Action), nicht Haushaltswaren |
| Sekundenkleber, Alleskleber, Tesafilm | Haushaltswaren | Sonstiges | überall erhältlich; Montagekleber, Bauschaum, Silikon → Baumaterial |
| Batterien, Glühbirnen, Wohnraumleuchten, Ladekabel | Elektronik | Sonstiges | wie bisher; Kabel, Schalter, Dosen, Sicherungen → Baumarkt |
| Klobürste, Seifenspender, Duschvorhang, Badematte | Sanitär | Sonstiges | Bad-Zubehör, nicht Installation |
| Blumenerde, Gießkanne, Blumentopf, Grill | Garten | Baumarkt | Gartencenter ist der Ort; vorher „Sonstiges“ |
| Tomatenpflanze, Orchidee, Thuja, Kräutertopf | Pflanzen | Baumarkt | Gartencenter |
| Schnittblumen, Blumenstrauß, Tulpen, Rosen | Pflanzen | keiner | Supermarktkasse ebenso |
| Katzenstreu, Hundefutter, Kratzbaum | Tierbedarf | keiner | Supermarkt, Drogerie und Fachmarkt |
| Weihnachtsbaum, Weihnachtsstern | Pflanzen | Baumarkt | echte Pflanzen; Christbaumkugeln bleiben Dekoration |
| Nagellack, Nagelfeile, Pinzette, Sonnenbrille | Kosmetik | Drogerie | vorher Farbe & Lack / Werkzeug |
| Pfanne, Gurkenhobel, Küchenschere, Frühstücksbrett | Küchenausstattung | Sonstiges | vorher Elektronik („fan“), Gemüse, Schreibwaren, Holz |
| Winterhandschuhe, Geschirrtücher | Textilien | Sonstiges | vorher Reinigung / Hygiene über Endung |
| Milchpulver | Milchprodukte | Supermarkt | Backzutat und Babynahrung; Anfangs-/Folgemilch bleiben Babybedarf |

## 5. Was sich daraus für andere Stellen ableiten lässt

- **Preiskatalog:** Die neuen Regale haben Pauschalen (Haarpflege 4,20 €, Zahnpflege 3,30 €, Kosmetik
  6,90 €, Hygieneartikel 3,60 €, Tierbedarf 4,80 €, Eisenwaren 5,50 €, Holz 16 €, Boden & Fliesen 18 €,
  Pflanzen 5,90 €), aber kaum Katalogeinträge; Baumarkt-Artikel liegen oft über
  `PriceEstimator.maxPlausibleLineTotal` (30 €) und bleiben „Preis?“.
- **Bon-Auflösung:** Baumarkt-Bons führen Artikelnummern und Mengen in anderer Form (Hornbach: Artikel-Nr.,
  Stück, Einzelpreis, Gesamt); die Parser kennen bisher Lebensmittel-, Drogerie- und Decathlon-Formate.
- **Zuordnung zum Laden:** Nutzerkorrektur und Kaufhistorie gehen vor jeder Warenkunde; die Warenkunde
  entscheidet nur, wenn beides fehlt.
- **Eigene Kategorien pro Laden** (#85) bleiben der Weg für alles, was hier fehlt („Gang 7“, „Kühltheke
  hinten“); die Emoji-Vorschläge kennen jetzt auch Haare, Zähne, Schrauben, Holz, Fliesen, Farben, Bad,
  Elektro, Werkzeug und Garten.
