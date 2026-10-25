# Zuordnung alt → neu (Python-Nachbildung, 2026-10-25)

Nachbildung von `AssignmentService.category(for:)` und der Ladentyp-Erkennung aus `assignDetailed` in Python
(Skript `sim.py` liest die Stichwortlisten direkt aus den Swift-Dateien). Kein Swift-Lauf; der Nachweis ist die CI.

## Zusammenfassung

```
entries 33 keywords 4425 endings 192

== food keywords whose category changed: 7
   ('cremefraiche', 'Körperpflege', 'Milchprodukte')
   ('creme fraiche', 'Körperpflege', 'Milchprodukte')
   ('multivitaminsaft', 'Medikamente', 'Getränke')
   ('whisky', 'Haushaltswaren', 'Getränke')
   ('whiskey', 'Haushaltswaren', 'Getränke')
   ('eiscreme', 'Körperpflege', 'Tiefkühlkost')
   ('rohrzucker', 'Sanitär', 'Gewürze & Backen')

== old non-food keywords whose category changed: 204
   ('abdeckband', 'Werkzeug', 'Farbe & Lack')
   ('abklebeband', 'Schreibwaren', 'Farbe & Lack')
   ('abtropfsieb', 'Haushaltswaren', 'Küchenausstattung')
   ('alufolie', 'Körperpflege', 'Haushaltswaren')
   ('astschere', 'Werkzeug', 'Garten')
   ('auflaufform', 'Haushaltswaren', 'Küchenausstattung')
   ('augensalbe', 'Körperpflege', 'Medikamente')
   ('augentropfen', 'Körperpflege', 'Medikamente')
   ('backform', 'Haushaltswaren', 'Küchenausstattung')
   ('badeteppich', 'Haushaltswaren', 'Sanitär')
   ('badteppich', 'Haushaltswaren', 'Sanitär')
   ('beize', 'Werkzeug', 'Farbe & Lack')
   ('beton', 'Werkzeug', 'Baumaterial')
   ('betonmix', 'Werkzeug', 'Baumaterial')
   ('bilderrahmen', 'Haushaltswaren', 'Dekoration')
   ('binden', 'Körperpflege', 'Hygieneartikel')
   ('bitumen', 'Werkzeug', 'Baumaterial')
   ('blumenerde', 'Haushaltswaren', 'Garten')
   ('blumenstab', 'Haushaltswaren', 'Pflanzen')
   ('blumentopf', 'Küchenausstattung', 'Garten')
   ('bolzen', 'Baumaterial', 'Eisenwaren')
   ('bratpfanne', 'Elektronik', 'Küchenausstattung')
   ('briketts', 'Haushaltswaren', 'Garten')
   ('cable', 'Haushaltswaren', 'Elektronik')
   ('cement', 'Werkzeug', 'Baumaterial')
   ('charger', 'Haushaltswaren', 'Elektronik')
   ('chopping board', 'Haushaltswaren', 'Küchenausstattung')
   ('christbaumkugel', 'Haushaltswaren', 'Dekoration')
   ('comb', 'Körperpflege', 'Haarpflege')
   ('conditioner', 'Körperpflege', 'Haarpflege')
   ('cotton pads', 'Körperpflege', 'Hygieneartikel')
   ('dachpappe', 'Werkzeug', 'Baumaterial')
   ('dielenboden', 'Werkzeug', 'Holz')
   ('dosenöffner', 'Haushaltswaren', 'Küchenausstattung')
   ('duschvorhang', 'Haushaltswaren', 'Sanitär')
   ('duschvorhangstange', 'Haushaltswaren', 'Sanitär')
   ('dübel', 'Baumaterial', 'Eisenwaren')
   ('elektrische zahnbürste', 'Haushaltswaren', 'Zahnpflege')
   ('extension cord', 'Haushaltswaren', 'Elektronik')
   ('eye drops', 'Körperpflege', 'Medikamente')
   ('feuerschale', 'Haushaltswaren', 'Garten')
   ('fliegengitter', 'Haushaltswaren', 'Baumaterial')
   ('fliese', 'Baumaterial', 'Boden & Fliesen')
   ('fliesen', 'Baumaterial', 'Boden & Fliesen')
   ('flower pot', 'Küchenausstattung', 'Garten')
   ('foundation', 'Körperpflege', 'Kosmetik')
   ('freischneider', 'Werkzeug', 'Garten')
   ('frischhaltefolie', 'Körperpflege', 'Haushaltswaren')
   ('fugenmasse', 'Werkzeug', 'Boden & Fliesen')
   ('fugenspachtel', 'Farbe & Lack', 'Baumaterial')
   ('gartenschere', 'Werkzeug', 'Garten')
   ('gartenwerkzeug', 'Haushaltswaren', 'Garten')
   ('gefrierbeutel', 'Körperpflege', 'Haushaltswaren')
   ('gießkanne', 'Haushaltswaren', 'Garten')
   ('glaswolle', 'Werkzeug', 'Baumaterial')
   ('grater', 'Haushaltswaren', 'Küchenausstattung')
   ('grill', 'Haushaltswaren', 'Garten')
   ('grillabdeckung', 'Haushaltswaren', 'Garten')
   ('grillbesteck', 'Haushaltswaren', 'Garten')
   ('grillbriketts', 'Haushaltswaren', 'Garten')
   ('grillhandschuh', 'Haushaltswaren', 'Garten')
   ('grillkohle', 'Haushaltswaren', 'Garten')
   ('grillrost', 'Haushaltswaren', 'Garten')
   ('grillspiess', 'Haushaltswaren', 'Garten')
   ('grillspieß', 'Haushaltswaren', 'Garten')
   ('grillthermometer', 'Haushaltswaren', 'Garten')
   ('grillzange', 'Werkzeug', 'Garten')
   ('haarband', 'Körperpflege', 'Haarpflege')
   ('haarbürste', 'Haushaltswaren', 'Haarpflege')
   ('haargel', 'Körperpflege', 'Haarpflege')
   ('haargummi', 'Körperpflege', 'Haarpflege')
   ('haarnadel', 'Körperpflege', 'Haarpflege')
   ('haarspray', 'Körperpflege', 'Haarpflege')
   ('hair brush', 'Körperpflege', 'Haarpflege')
   ('hair tie', 'Körperpflege', 'Haarpflege')
   ('halstabletten', 'Körperpflege', 'Medikamente')
   ('handtuchhalter', 'Textilien', 'Sanitär')
   ('hochdruckreiniger', 'Werkzeug', 'Garten')
   ('hohlwanddose', 'Werkzeug', 'Elektronik')
   ('holzkohle', 'Haushaltswaren', 'Garten')
   ('holzschutz', 'Werkzeug', 'Farbe & Lack')
   ('holzöl', 'Werkzeug', 'Farbe & Lack')
   ('hustenbonbons', 'Körperpflege', 'Medikamente')
   ('hustensaft', 'Körperpflege', 'Medikamente')
   ('installationsrohr', 'Sanitär', 'Elektronik')
   ('kabelkanal', 'Sanitär', 'Elektronik')
   ('kamm', 'Körperpflege', 'Haarpflege')
   ('kettensäge', 'Werkzeug', 'Garten')
   ('klinker', 'Werkzeug', 'Baumaterial')
   ('klobürste', 'Haushaltswaren', 'Sanitär')
   ('klopapierhalter', 'Haushaltswaren', 'Sanitär')
   ('kompost', 'Haushaltswaren', 'Garten')
   ('kondome', 'Körperpflege', 'Hygieneartikel')
   ('kupplung', 'Werkzeug', 'Sanitär')
   ('küchenrolle', 'Körperpflege', 'Hygieneartikel')
   ('küchenwaage', 'Haushaltswaren', 'Küchenausstattung')
   ('lacquer', 'Werkzeug', 'Farbe & Lack')
   ('laminat', 'Baumaterial', 'Boden & Fliesen')
   ('lawnmower', 'Werkzeug', 'Garten')
   ('leuchtmittel', 'Haushaltswaren', 'Elektronik')
   ('lichtschalter', 'Sanitär', 'Elektronik')
   ('lippenpflege', 'Schreibwaren', 'Körperpflege')
   ('lippenstift', 'Schreibwaren', 'Kosmetik')
   ('make-up', 'Körperpflege', 'Kosmetik')
   ('malerfolie', 'Werkzeug', 'Farbe & Lack')
   ('mascara', 'Körperpflege', 'Kosmetik')
   ('mdf', 'Werkzeug', 'Holz')
   ('messbecher', 'Haushaltswaren', 'Küchenausstattung')
   ('motorsäge', 'Werkzeug', 'Garten')
   ('muffe', 'Werkzeug', 'Sanitär')
   ('mundwasser', 'Körperpflege', 'Zahnpflege')
   ('müllbeutel', 'Körperpflege', 'Haushaltswaren')
   ('nagellack', 'Farbe & Lack', 'Kosmetik')
   ('nasal spray', 'Körperpflege', 'Medikamente')
   ('nasengel', 'Körperpflege', 'Medikamente')
   ('nasenpflege', 'Körperpflege', 'Medikamente')
   ('nasenspray', 'Körperpflege', 'Medikamente')
   ('nasentropfen', 'Körperpflege', 'Medikamente')
   ('nasenöl', 'Körperpflege', 'Medikamente')
   ('nägel', 'Werkzeug', 'Eisenwaren')
   ('o-ring', 'Werkzeug', 'Sanitär')
   ('ohrentropfen', 'Körperpflege', 'Medikamente')
   ('paint', 'Werkzeug', 'Farbe & Lack')
   ('papiertücher', 'Körperpflege', 'Hygieneartikel')
   ('parfum', 'Körperpflege', 'Kosmetik')
   ('parkett', 'Baumaterial', 'Boden & Fliesen')
   ('pfanne', 'Elektronik', 'Küchenausstattung')
   ('pflanzenstab', 'Haushaltswaren', 'Pflanzen')
   ('pflanzerde', 'Haushaltswaren', 'Garten')
   ('pflanzgefäß', 'Haushaltswaren', 'Garten')
   ('pflanzkübel', 'Haushaltswaren', 'Garten')
   ('pflasterstein', 'Werkzeug', 'Baumaterial')
   ('pipe', 'Werkzeug', 'Sanitär')
   ('plaster', 'Werkzeug', 'Baumaterial')
   ('powerbank', 'Haushaltswaren', 'Elektronik')
   ('putztuch', 'Körperpflege', 'Reinigung')
   ('rake', 'Werkzeug', 'Garten')
   ('rankgitter', 'Haushaltswaren', 'Garten')
   ('rasentrimmer', 'Werkzeug', 'Garten')
   ('rasierapparat', 'Haushaltswaren', 'Körperpflege')
   ('regenschirmständer', 'Haushaltswaren', 'Textilien')
   ('scheuertuch', 'Körperpflege', 'Reinigung')
   ('schneebesen', 'Haushaltswaren', 'Küchenausstattung')
   ('schraube', 'Baumaterial', 'Eisenwaren')
   ('schrauben', 'Baumaterial', 'Eisenwaren')
   ('schwamm', 'Körperpflege', 'Reinigung')
   ('sealant', 'Werkzeug', 'Baumaterial')
   ('seifenschale', 'Haushaltswaren', 'Sanitär')
   ('seifenspender', 'Schreibwaren', 'Sanitär')
   ('sekundenkleber', 'Werkzeug', 'Haushaltswaren')
   ('shampoo', 'Körperpflege', 'Haarpflege')
   ('shovel', 'Werkzeug', 'Garten')
   ('sieb', 'Haushaltswaren', 'Küchenausstattung')
   ('socket', 'Haushaltswaren', 'Elektronik')
   ('spade', 'Werkzeug', 'Garten')
   ('spanplatte', 'Werkzeug', 'Holz')
   ('sparschäler', 'Haushaltswaren', 'Küchenausstattung')
   ('sperrholz', 'Werkzeug', 'Holz')
   ('sponge', 'Körperpflege', 'Reinigung')
   ('sprinkler', 'Werkzeug', 'Garten')
   ('spülbürste', 'Haushaltswaren', 'Reinigung')
   ('staubtuch', 'Haushaltswaren', 'Reinigung')
   ('steckdosenrahmen', 'Werkzeug', 'Elektronik')
   ('stecker', 'Haushaltswaren', 'Elektronik')
   ('steckleiste', 'Haushaltswaren', 'Elektronik')
   ('steinwolle', 'Werkzeug', 'Baumaterial')
   ('styropor', 'Werkzeug', 'Baumaterial')
   ('suppentopf', 'Schreibwaren', 'Küchenausstattung')
   ('tacker', 'Haushaltswaren', 'Werkzeug')
   ('tampons', 'Körperpflege', 'Hygieneartikel')
   ('teppichboden', 'Werkzeug', 'Boden & Fliesen')
   ('terrassenplatte', 'Werkzeug', 'Baumaterial')
   ('tischset', 'Haushaltswaren', 'Küchenausstattung')
   ('tissues', 'Körperpflege', 'Hygieneartikel')
   ('toilet paper', 'Körperpflege', 'Hygieneartikel')
   ('toilettenbürste', 'Haushaltswaren', 'Sanitär')
   ('toilettenpapier', 'Körperpflege', 'Hygieneartikel')
   ('toilettenpapierhalter', 'Haushaltswaren', 'Sanitär')
   ('toothbrush', 'Körperpflege', 'Zahnpflege')
   ('toothpaste', 'Körperpflege', 'Zahnpflege')
   ('tropfschlauch', 'Werkzeug', 'Garten')
   ('unterputzdose', 'Werkzeug', 'Elektronik')
   ('untersetzer', 'Haushaltswaren', 'Küchenausstattung')
   ('varnish', 'Werkzeug', 'Farbe & Lack')
   ('vase', 'Haushaltswaren', 'Dekoration')
   ('vinylboden', 'Werkzeug', 'Boden & Fliesen')
   ('wandhaken', 'Haushaltswaren', 'Eisenwaren')
   ('wanduhr', 'Haushaltswaren', 'Dekoration')
   ('waschlappen', 'Schreibwaren', 'Textilien')
   ('watering can', 'Haushaltswaren', 'Garten')
   ('wattepads', 'Körperpflege', 'Hygieneartikel')
   ('wattestäbchen', 'Körperpflege', 'Hygieneartikel')
   ('wc-bürste', 'Haushaltswaren', 'Sanitär')
   ('wc-matte', 'Haushaltswaren', 'Sanitär')
   ('weihnachtsbaum', 'Dekoration', 'Pflanzen')
   ('wellrohr', 'Sanitär', 'Elektronik')
   ('whisk', 'Haushaltswaren', 'Küchenausstattung')
   ('wok', 'Haushaltswaren', 'Küchenausstattung')
   ('zahnbürste', 'Haushaltswaren', 'Zahnpflege')
   ('zahnbürstenköpfe', 'Körperpflege', 'Zahnpflege')
   ('zahnpasta', 'Körperpflege', 'Zahnpflege')
   ('zahnputzbecher', 'Haushaltswaren', 'Sanitär')
   ('zahnseide', 'Körperpflege', 'Zahnpflege')
   ('zeitschaltuhr', 'Haushaltswaren', 'Elektronik')

== store group changes: 47
   ('abklebeband', 'variety', 'hardware')
   ('alufolie', 'drugstore', 'variety')
   ('blumenerde', 'variety', 'hardware')
   ('blumenstab', 'variety', 'grocery')
   ('blumentopf', 'variety', 'hardware')
   ('briketts', 'variety', 'hardware')
   ('cable', 'variety', 'hardware')
   ('elektrische zahnbürste', 'variety', 'drugstore')
   ('feuerschale', 'variety', 'hardware')
   ('fliegengitter', 'variety', 'hardware')
   ('flower pot', 'variety', 'hardware')
   ('frischhaltefolie', 'drugstore', 'variety')
   ('gartenwerkzeug', 'variety', 'hardware')
   ('gefrierbeutel', 'drugstore', 'variety')
   ('gießkanne', 'variety', 'hardware')
   ('grill', 'variety', 'hardware')
   ('grillabdeckung', 'variety', 'hardware')
   ('grillbesteck', 'variety', 'hardware')
   ('grillbriketts', 'variety', 'hardware')
   ('grillhandschuh', 'variety', 'hardware')
   ('grillkohle', 'variety', 'hardware')
   ('grillrost', 'variety', 'hardware')
   ('grillspiess', 'variety', 'hardware')
   ('grillspieß', 'variety', 'hardware')
   ('grillthermometer', 'variety', 'hardware')
   ('haarbürste', 'variety', 'drugstore')
   ('holzkohle', 'variety', 'hardware')
   ('kompost', 'variety', 'hardware')
   ('lippenpflege', 'variety', 'drugstore')
   ('lippenstift', 'variety', 'drugstore')
   ('müllbeutel', 'drugstore', 'variety')
   ('nagellack', 'hardware', 'drugstore')
   ('pflanzenstab', 'variety', 'hardware')
   ('pflanzerde', 'variety', 'hardware')
   ('pflanzgefäß', 'variety', 'hardware')
   ('pflanzkübel', 'variety', 'hardware')
   ('rankgitter', 'variety', 'hardware')
   ('rasierapparat', 'variety', 'drugstore')
   ('socket', 'variety', 'hardware')
   ('spülbürste', 'variety', 'drugstore')
   ('staubtuch', 'variety', 'drugstore')
   ('steckdose', 'variety', 'hardware')
   ('tacker', 'variety', 'hardware')
   ('wandhaken', 'variety', 'hardware')
   ('watering can', 'variety', 'hardware')
   ('weihnachtsbaum', 'variety', 'hardware')
   ('zahnbürste', 'variety', 'drugstore')
```

## 355 realistische Namen

| Name | alt | neu | Ladentyp neu | |
|---|---|---|---|---|
| Zahnbürste | Haushaltswaren | Zahnpflege | drugstore | geändert |
| Zahnseide | Körperpflege | Zahnpflege | drugstore | geändert |
| Haarfarbe | Lebensmittel | Haarpflege | drugstore | geändert |
| Shampoo | Körperpflege | Haarpflege | drugstore | geändert |
| Trockenshampoo | Körperpflege | Haarpflege | drugstore | geändert |
| Lippenstift | Schreibwaren | Kosmetik | drugstore | geändert |
| Mascara | Körperpflege | Kosmetik | drugstore | geändert |
| Parfum | Körperpflege | Kosmetik | drugstore | geändert |
| Tampons | Körperpflege | Hygieneartikel | drugstore | geändert |
| Toilettenpapier | Körperpflege | Hygieneartikel | drugstore | geändert |
| Küchenrolle | Körperpflege | Hygieneartikel | drugstore | geändert |
| Taschentücher | Lebensmittel | Hygieneartikel | drugstore | geändert |
| Müllbeutel | Körperpflege | Haushaltswaren | variety | geändert |
| Schwamm | Körperpflege | Reinigung | drugstore | geändert |
| Spülmittel | Reinigung | Reinigung | drugstore |  |
| Waschmittel | Reinigung | Reinigung | drugstore |  |
| Weichspüler | Lebensmittel | Reinigung | drugstore | geändert |
| Katzenstreu | Lebensmittel | Tierbedarf | grocery | geändert |
| Hundefutter | Lebensmittel | Tierbedarf | grocery | geändert |
| Katzenfutter | Lebensmittel | Tierbedarf | grocery | geändert |
| Whiskas | Haushaltswaren | Tierbedarf | grocery | geändert |
| Vogelfutter | Lebensmittel | Tierbedarf | grocery | geändert |
| Pflaster | Medikamente | Medikamente | drugstore |  |
| Ibuprofen | Medikamente | Medikamente | drugstore |  |
| Vitamin D | Medikamente | Medikamente | drugstore |  |
| Nasenspray | Körperpflege | Medikamente | drugstore | geändert |
| Windeln | Babybedarf | Babybedarf | drugstore |  |
| Babybrei | Lebensmittel | Babybedarf | drugstore | geändert |
| Duschgel | Körperpflege | Körperpflege | drugstore |  |
| Deo | Körperpflege | Körperpflege | drugstore |  |
| Sonnencreme | Körperpflege | Körperpflege | drugstore |  |
| Handcreme | Körperpflege | Körperpflege | drugstore |  |
| Crème fraîche | Milchprodukte | Milchprodukte | grocery |  |
| Cremefraiche | Körperpflege | Milchprodukte | grocery | geändert |
| Creme fraiche | Körperpflege | Milchprodukte | grocery | geändert |
| Mandelmilch | Milchprodukte | Milchprodukte | grocery |  |
| Hafermilch | Milchprodukte | Milchprodukte | grocery |  |
| Kokosmilch | Milchprodukte | Milchprodukte | grocery |  |
| Reinigungsmilch | Milchprodukte | Kosmetik | drugstore | geändert |
| Katzenmilch | Milchprodukte | Tierbedarf | grocery | geändert |
| Eiscreme | Körperpflege | Tiefkühlkost | grocery | geändert |
| Buttercreme | Körperpflege | Gewürze & Backen | grocery | geändert |
| Nusscreme | Körperpflege | Konserven | grocery | geändert |
| Bierschinken | Fleisch & Wurst | Fleisch & Wurst | grocery |  |
| Weingummi | Snacks | Snacks | grocery |  |
| Teewurst | Fleisch & Wurst | Fleisch & Wurst | grocery |  |
| Rosenkohl | Obst & Gemüse | Obst & Gemüse | grocery |  |
| Streusel | Lebensmittel | Gewürze & Backen | grocery | geändert |
| Zuckerwatte | Gewürze & Backen | Snacks | grocery | geändert |
| Pflanzenöl | Konserven | Konserven | grocery |  |
| Chiasamen | Lebensmittel | Konserven | grocery | geändert |
| Leinsamen | Lebensmittel | Konserven | grocery | geändert |
| Jasminreis | Konserven | Konserven | grocery |  |
| Sandwich | Lebensmittel | Lebensmittel | grocery |  |
| Amerikaner | Lebensmittel | Backwaren | grocery | geändert |
| Spax Schrauben 4x40 | Baumaterial | Eisenwaren | hardware | geändert |
| Schrauben | Baumaterial | Eisenwaren | hardware | geändert |
| Dübel | Baumaterial | Eisenwaren | hardware | geändert |
| Nägel | Werkzeug | Eisenwaren | hardware | geändert |
| Scharnier | Lebensmittel | Eisenwaren | hardware | geändert |
| Vorhängeschloss | Lebensmittel | Eisenwaren | hardware | geändert |
| Kabelbinder | Haushaltswaren | Eisenwaren | hardware | geändert |
| OSB-Platte | Lebensmittel | Holz | hardware | geändert |
| OSB Platte 18mm | Lebensmittel | Holz | hardware | geändert |
| Spanplatte | Werkzeug | Holz | hardware | geändert |
| Dachlatten | Lebensmittel | Holz | hardware | geändert |
| Kantholz | Lebensmittel | Holz | hardware | geändert |
| Terrassendielen Douglasie | Lebensmittel | Holz | hardware | geändert |
| Laminat | Baumaterial | Boden & Fliesen | hardware | geändert |
| Fliesen | Baumaterial | Boden & Fliesen | hardware | geändert |
| Fliesenkleber | Baumaterial | Boden & Fliesen | hardware | geändert |
| Vinylboden | Werkzeug | Boden & Fliesen | hardware | geändert |
| Sockelleisten | Lebensmittel | Boden & Fliesen | hardware | geändert |
| Zement | Baumaterial | Baumaterial | hardware |  |
| Mörtel | Baumaterial | Baumaterial | hardware |  |
| Rigips | Baumaterial | Baumaterial | hardware |  |
| Styropor | Werkzeug | Baumaterial | hardware | geändert |
| Silikon | Baumaterial | Baumaterial | hardware |  |
| Montagekleber | Werkzeug | Baumaterial | hardware | geändert |
| Bauschaum | Lebensmittel | Baumaterial | hardware | geändert |
| Wandfarbe weiß | Farbe & Lack | Farbe & Lack | hardware |  |
| Lack | Farbe & Lack | Farbe & Lack | hardware |  |
| Pinsel | Farbe & Lack | Farbe & Lack | hardware |  |
| Malerrolle | Farbe & Lack | Farbe & Lack | hardware |  |
| Tapete | Farbe & Lack | Farbe & Lack | hardware |  |
| Kleister | Lebensmittel | Farbe & Lack | hardware | geändert |
| Abdeckfolie | Lebensmittel | Farbe & Lack | hardware | geändert |
| Lichtschalter | Sanitär | Elektronik | hardware | geändert |
| Steckdose | Elektronik | Elektronik | hardware |  |
| Kabelkanal | Sanitär | Elektronik | hardware | geändert |
| NYM-J 3x1,5 | Lebensmittel | Elektronik | hardware | geändert |
| LED-Lampe | Elektronik | Elektronik | variety |  |
| Glühbirne E27 | Elektronik | Elektronik | variety |  |
| Batterien | Elektronik | Elektronik | variety |  |
| Verlängerungskabel | Elektronik | Elektronik | variety |  |
| Rauchmelder | Lebensmittel | Elektronik | hardware | geändert |
| Wasserhahn | Getränke | Sanitär | hardware | geändert |
| Siphon | Sanitär | Sanitär | hardware |  |
| Dichtung | Sanitär | Sanitär | hardware |  |
| Duschkopf | Lebensmittel | Sanitär | hardware | geändert |
| Heizkörperthermostat | Lebensmittel | Sanitär | hardware | geändert |
| Eckventil | Sanitär | Sanitär | hardware |  |
| Rohr | Sanitär | Sanitär | hardware |  |
| Blumenerde | Haushaltswaren | Garten | hardware | geändert |
| Rasendünger | Lebensmittel | Garten | hardware | geändert |
| Rasensamen | Lebensmittel | Garten | hardware | geändert |
| Gartenschlauch | Garten | Garten | hardware |  |
| Gießkanne | Haushaltswaren | Garten | hardware | geändert |
| Rasenmäher | Garten | Garten | hardware |  |
| Heckenschere | Garten | Garten | hardware |  |
| Spaten | Garten | Garten | hardware |  |
| Blumentopf | Küchenausstattung | Garten | hardware | geändert |
| Hochbeet | Lebensmittel | Garten | hardware | geändert |
| Zaun | Lebensmittel | Garten | hardware | geändert |
| Sichtschutz | Lebensmittel | Garten | hardware | geändert |
| Gartenstuhl | Lebensmittel | Garten | hardware | geändert |
| Sonnenschirm | Lebensmittel | Garten | hardware | geändert |
| Grillkohle | Haushaltswaren | Garten | hardware | geändert |
| Grill | Haushaltswaren | Garten | hardware | geändert |
| Tomatenpflanze | Obst & Gemüse | Pflanzen | hardware | geändert |
| Basilikum | Obst & Gemüse | Obst & Gemüse | grocery |  |
| Basilikum Topf | Obst & Gemüse | Obst & Gemüse | grocery |  |
| Kräutertopf | Lebensmittel | Pflanzen | hardware | geändert |
| Orchidee | Lebensmittel | Pflanzen | hardware | geändert |
| Rosen | Lebensmittel | Pflanzen | grocery | geändert |
| Tulpen | Schreibwaren | Pflanzen | grocery | geändert |
| Blumenstrauß | Lebensmittel | Pflanzen | grocery | geändert |
| Weihnachtsbaum | Dekoration | Pflanzen | hardware | geändert |
| Weihnachtsstern | Dekoration | Pflanzen | hardware | geändert |
| Lavendel | Lebensmittel | Pflanzen | hardware | geändert |
| Thuja | Lebensmittel | Pflanzen | hardware | geändert |
| Buchsbaum | Lebensmittel | Pflanzen | hardware | geändert |
| Akkuschrauber | Werkzeug | Werkzeug | hardware |  |
| Bohrmaschine | Werkzeug | Werkzeug | hardware |  |
| Hammer | Werkzeug | Werkzeug | hardware |  |
| Zange | Werkzeug | Werkzeug | hardware |  |
| Wasserwaage | Werkzeug | Werkzeug | hardware |  |
| Zollstock | Werkzeug | Werkzeug | hardware |  |
| Schleifpapier | Lebensmittel | Werkzeug | hardware | geändert |
| Säge | Werkzeug | Werkzeug | hardware |  |
| Cuttermesser | Werkzeug | Werkzeug | hardware |  |
| Schutzbrille | Werkzeug | Werkzeug | hardware |  |
| Arbeitshandschuhe | Werkzeug | Werkzeug | hardware |  |
| Leiter | Lebensmittel | Werkzeug | hardware | geändert |
| Werkzeugkoffer | Lebensmittel | Werkzeug | hardware | geändert |
| Kerzen | Dekoration | Dekoration | variety |  |
| Teelichter | Dekoration | Dekoration | variety |  |
| Backpapier | Lebensmittel | Haushaltswaren | variety | geändert |
| Alufolie | Körperpflege | Haushaltswaren | variety | geändert |
| Gefrierbeutel | Körperpflege | Haushaltswaren | variety | geändert |
| Servietten | Haushaltswaren | Haushaltswaren | variety |  |
| Küchenwaage | Haushaltswaren | Küchenausstattung | variety | geändert |
| Schneidebrett | Küchenausstattung | Küchenausstattung | variety |  |
| Pfanne | Elektronik | Küchenausstattung | variety | geändert |
| Kochtopf | Küchenausstattung | Küchenausstattung | variety |  |
| Handtuch | Textilien | Textilien | variety |  |
| Bettwäsche | Textilien | Textilien | variety |  |
| Kugelschreiber | Schreibwaren | Schreibwaren | variety |  |
| Puzzle | Spielzeug | Spielzeug | variety |  |
| Lichterkette | Dekoration | Dekoration | variety |  |
| Adventskranz | Dekoration | Dekoration | variety |  |
| Kissen | Textilien | Textilien | variety |  |
| Ventilator | Elektronik | Elektronik | variety |  |
| Milch | Milchprodukte | Milchprodukte | grocery |  |
| Butter | Milchprodukte | Milchprodukte | grocery |  |
| Brot | Backwaren | Backwaren | grocery |  |
| Äpfel | Obst & Gemüse | Obst & Gemüse | grocery |  |
| Bananen | Obst & Gemüse | Obst & Gemüse | grocery |  |
| Hackfleisch | Fleisch & Wurst | Fleisch & Wurst | grocery |  |
| Nudeln | Konserven | Konserven | grocery |  |
| Olivenöl | Konserven | Konserven | grocery |  |
| Mehl | Konserven | Konserven | grocery |  |
| Zucker | Gewürze & Backen | Gewürze & Backen | grocery |  |
| Natron | Gewürze & Backen | Gewürze & Backen | grocery |  |
| Backpulver | Gewürze & Backen | Gewürze & Backen | grocery |  |
| Salz | Gewürze & Backen | Gewürze & Backen | grocery |  |
| Pfeffer | Gewürze & Backen | Gewürze & Backen | grocery |  |
| Kaffee | Getränke | Getränke | grocery |  |
| Tee | Getränke | Getränke | grocery |  |
| Bier | Getränke | Getränke | grocery |  |
| Wein | Getränke | Getränke | grocery |  |
| Cola | Getränke | Getränke | grocery |  |
| Chips | Snacks | Snacks | grocery |  |
| Schokolade | Snacks | Snacks | grocery |  |
| Pizza | Tiefkühlkost | Tiefkühlkost | grocery |  |
| Eis | Lebensmittel | Lebensmittel | grocery |  |
| Joghurt | Milchprodukte | Milchprodukte | grocery |  |
| Käse | Milchprodukte | Milchprodukte | grocery |  |
| Gouda | Milchprodukte | Milchprodukte | grocery |  |
| Eier | Lebensmittel | Lebensmittel | grocery |  |
| Honig | Konserven | Konserven | grocery |  |
| Marmelade | Konserven | Konserven | grocery |  |
| Ketchup | Konserven | Konserven | grocery |  |
| Senf | Konserven | Konserven | grocery |  |
| Nagelkäse | Baumaterial | Milchprodukte | grocery | geändert |
| Zwiebeln | Obst & Gemüse | Obst & Gemüse | grocery |  |
| Knoblauch | Obst & Gemüse | Obst & Gemüse | grocery |  |
| Kartoffeln | Obst & Gemüse | Obst & Gemüse | grocery |  |
| Hähnchen | Fleisch & Wurst | Fleisch & Wurst | grocery |  |
| Lachs | Fleisch & Wurst | Fleisch & Wurst | grocery |  |
| Fischstäbchen | Fleisch & Wurst | Fleisch & Wurst | grocery |  |
| Tomatenmark | Konserven | Konserven | grocery |  |
| Kidneybohnen | Konserven | Konserven | grocery |  |
| Müsli | Konserven | Konserven | grocery |  |
| Haferflocken | Konserven | Konserven | grocery |  |
| Primer | Lebensmittel | Kosmetik | drugstore | geändert |
| Serum | Getränke | Kosmetik | drugstore | geändert |
| Nagellack | Farbe & Lack | Kosmetik | drugstore | geändert |
| Rasierer | Körperpflege | Körperpflege | drugstore |  |
| Rasierklingen | Körperpflege | Körperpflege | drugstore |  |
| Wattepads | Körperpflege | Hygieneartikel | drugstore | geändert |
| Wattestäbchen | Körperpflege | Hygieneartikel | drugstore | geändert |
| Binden | Körperpflege | Hygieneartikel | drugstore | geändert |
| Kondome | Körperpflege | Hygieneartikel | drugstore | geändert |
| Hustensaft | Körperpflege | Medikamente | drugstore | geändert |
| Halstabletten | Körperpflege | Medikamente | drugstore | geändert |
| Magnesium | Lebensmittel | Medikamente | drugstore | geändert |
| Fieberthermometer | Lebensmittel | Medikamente | drugstore | geändert |
| Schwangerschaftstest | Lebensmittel | Medikamente | drugstore | geändert |
| FFP2 Maske | Lebensmittel | Medikamente | drugstore | geändert |
| Pampers | Lebensmittel | Babybedarf | drugstore | geändert |
| Schnuller | Lebensmittel | Babybedarf | drugstore | geändert |
| Milchpulver | Milchprodukte | Milchprodukte | grocery |  |
| Babyöl | Babybedarf | Babybedarf | drugstore |  |
| Feuchttücher | Lebensmittel | Hygieneartikel | drugstore | geändert |
| Spülmaschinentabs | Lebensmittel | Reinigung | drugstore | geändert |
| Klarspüler | Lebensmittel | Reinigung | drugstore | geändert |
| Entkalker | Lebensmittel | Reinigung | drugstore | geändert |
| Glasreiniger | Lebensmittel | Reinigung | drugstore | geändert |
| WC-Reiniger | Lebensmittel | Reinigung | drugstore | geändert |
| Allzweckreiniger | Reinigung | Reinigung | drugstore |  |
| Putzmittel | Lebensmittel | Reinigung | drugstore | geändert |
| Mikrofasertuch | Lebensmittel | Reinigung | drugstore | geändert |
| Gummihandschuhe | Reinigung | Reinigung | drugstore |  |
| Lufterfrischer | Lebensmittel | Reinigung | drugstore | geändert |
| Trockenfutter Katze | Lebensmittel | Tierbedarf | grocery | geändert |
| Leckerli | Lebensmittel | Tierbedarf | grocery | geändert |
| Kratzbaum | Lebensmittel | Tierbedarf | grocery | geändert |
| Napf | Lebensmittel | Tierbedarf | grocery | geändert |
| Heu | Lebensmittel | Tierbedarf | grocery | geändert |
| Scheuermilch | Milchprodukte | Reinigung | drugstore | geändert |
| Felix Katzenfutter | Lebensmittel | Tierbedarf | grocery | geändert |
| Kaffeekapseln | Getränke | Getränke | grocery |  |
| Teebeutel | Getränke | Getränke | grocery |  |
| Bierkasten | Getränke | Getränke | grocery |  |
| Küchenschere | Schreibwaren | Küchenausstattung | variety | geändert |
| Sonnenbrille | Lebensmittel | Kosmetik | drugstore | geändert |
| Winterhandschuhe | Reinigung | Textilien | variety | geändert |
| Gurkenhobel | Obst & Gemüse | Küchenausstattung | variety | geändert |
| Käsehobel | Milchprodukte | Küchenausstattung | variety | geändert |
| Frühstücksbrett | Lebensmittel | Küchenausstattung | variety | geändert |
| Herdplatte | Lebensmittel | Lebensmittel | grocery |  |
| Käseplatte | Milchprodukte | Milchprodukte | grocery |  |
| Yogamatte | Lebensmittel | Lebensmittel | grocery |  |
| Badeschaum | Lebensmittel | Lebensmittel | grocery |  |
| Autoschlüssel | Lebensmittel | Lebensmittel | grocery |  |
| Koffer | Lebensmittel | Lebensmittel | grocery |  |
| Konsole | Lebensmittel | Lebensmittel | grocery |  |
| Hosen | Lebensmittel | Lebensmittel | grocery |  |
| Schuhe | Lebensmittel | Lebensmittel | grocery |  |
| Textil | Lebensmittel | Lebensmittel | grocery |  |
| Keyboard | Lebensmittel | Lebensmittel | grocery |  |
| Skateboard | Lebensmittel | Lebensmittel | grocery |  |
| Farbpalette | Lebensmittel | Lebensmittel | grocery |  |
| Make-Up Palette | Körperpflege | Kosmetik | drugstore | geändert |
| Streichhölzer | Konserven | Haushaltswaren | variety | geändert |
| Feuerzeug | Lebensmittel | Haushaltswaren | variety | geändert |
| Kaminholz | Lebensmittel | Garten | hardware | geändert |
| Brennholz | Lebensmittel | Garten | hardware | geändert |
| Fahrradschlauch | Obst & Gemüse | Obst & Gemüse | grocery |  |
| Fahrradschloss | Haushaltswaren | Haushaltswaren | variety |  |
| Fahrradhelm | Lebensmittel | Lebensmittel | grocery |  |
| Laufschuhe | Lebensmittel | Lebensmittel | grocery |  |
| Zelt | Lebensmittel | Lebensmittel | grocery |  |
| Isomatte | Getränke | Getränke | grocery |  |
| Proteinriegel | Lebensmittel | Snacks | grocery | geändert |
| Müsliriegel | Snacks | Snacks | grocery |  |
| Energy Drink | Getränke | Getränke | grocery |  |
| Hundeshampoo | Körperpflege | Tierbedarf | grocery | geändert |
| Katzengras | Lebensmittel | Tierbedarf | grocery | geändert |
| Gelber Sack | Lebensmittel | Haushaltswaren | variety | geändert |
| Sekundenkleber | Werkzeug | Haushaltswaren | variety | geändert |
| Pattex | Haushaltswaren | Haushaltswaren | variety |  |
| Tesa | Haushaltswaren | Haushaltswaren | variety |  |
| Klebeband | Schreibwaren | Schreibwaren | variety |  |
| Panzertape | Schreibwaren | Eisenwaren | hardware | geändert |
| Doppelseitiges Klebeband | Schreibwaren | Eisenwaren | hardware | geändert |
| Nägel Maniküre | Werkzeug | Kosmetik | drugstore | geändert |
| Nagelfeile | Werkzeug | Kosmetik | drugstore | geändert |
| Nagelschere | Baumaterial | Kosmetik | drugstore | geändert |
| Pinzette | Lebensmittel | Kosmetik | drugstore | geändert |
| Deodorant | Körperpflege | Körperpflege | drugstore |  |
| Rasierschaum | Körperpflege | Körperpflege | drugstore |  |
| Gillette | Lebensmittel | Lebensmittel | grocery |  |
| Nivea | Lebensmittel | Lebensmittel | grocery |  |
| Balea Duschgel | Körperpflege | Körperpflege | drugstore |  |
| Alverde Shampoo | Haushaltswaren | Haarpflege | drugstore | geändert |
| Mivolis Magnesium | Lebensmittel | Medikamente | drugstore | geändert |
| Denkmit Spülmittel | Reinigung | Reinigung | drugstore |  |
| Zewa | Lebensmittel | Hygieneartikel | drugstore | geändert |
| Tempo | Lebensmittel | Hygieneartikel | drugstore | geändert |
| Hakle | Lebensmittel | Hygieneartikel | drugstore | geändert |
| Persil | Lebensmittel | Reinigung | drugstore | geändert |
| Lenor | Lebensmittel | Reinigung | drugstore | geändert |
| Somat | Lebensmittel | Lebensmittel | grocery |  |
| Frosch Reiniger | Lebensmittel | Reinigung | drugstore | geändert |
| Sagrotan | Lebensmittel | Reinigung | drugstore | geändert |
| Blend-a-med | Lebensmittel | Zahnpflege | drugstore | geändert |
| Oral-B Aufsteckbürsten | Körperpflege | Zahnpflege | drugstore | geändert |
| Elmex | Lebensmittel | Zahnpflege | drugstore | geändert |
| Odol | Lebensmittel | Zahnpflege | drugstore | geändert |
| Listerine | Lebensmittel | Lebensmittel | grocery |  |
| Essence Mascara | Körperpflege | Kosmetik | drugstore | geändert |
| Catrice Lidschatten | Konserven | Kosmetik | drugstore | geändert |
| Maybelline | Lebensmittel | Kosmetik | drugstore | geändert |
| NYX | Lebensmittel | Kosmetik | drugstore | geändert |
| L'Oréal Paris | Lebensmittel | Kosmetik | drugstore | geändert |
| Hipp Gläschen | Lebensmittel | Babybedarf | drugstore | geändert |
| Aptamil | Lebensmittel | Babybedarf | drugstore | geändert |
| Pampers Baby Dry | Lebensmittel | Babybedarf | drugstore | geändert |
| Whiskas Nassfutter | Haushaltswaren | Tierbedarf | grocery | geändert |
| Sheba | Lebensmittel | Tierbedarf | grocery | geändert |
| Dreamies | Lebensmittel | Tierbedarf | grocery | geändert |
| Felix | Lebensmittel | Tierbedarf | grocery | geändert |
| Bosch Akkuschrauber | Werkzeug | Werkzeug | hardware |  |
| Makita | Lebensmittel | Lebensmittel | grocery |  |
| Spax 4x50 | Lebensmittel | Eisenwaren | hardware | geändert |
| Fischer Dübel | Baumaterial | Eisenwaren | hardware | geändert |
| Knauf Rotband | Lebensmittel | Baumaterial | hardware | geändert |
| Alpinaweiß | Lebensmittel | Farbe & Lack | hardware | geändert |
| Weber Grill | Haushaltswaren | Garten | hardware | geändert |
| Gardena Schlauch | Obst & Gemüse | Garten | hardware | geändert |
| Kärcher | Lebensmittel | Garten | hardware | geändert |
| Hornbach Blumenerde | Haushaltswaren | Garten | hardware | geändert |
| Compo Sana | Lebensmittel | Lebensmittel | grocery |  |
| Substral | Lebensmittel | Lebensmittel | grocery |  |
| Celaflor | Lebensmittel | Lebensmittel | grocery |  |
| Gartenbank | Lebensmittel | Garten | hardware | geändert |
| Sandkasten | Lebensmittel | Garten | hardware | geändert |
| Spielsand | Lebensmittel | Baumaterial | hardware | geändert |
| Sand | Lebensmittel | Lebensmittel | grocery |  |
| Kies | Lebensmittel | Baumaterial | hardware | geändert |
| Splitt | Lebensmittel | Baumaterial | hardware | geändert |
| Pflastersteine | Werkzeug | Baumaterial | hardware | geändert |
| Terrassenplatten | Werkzeug | Baumaterial | hardware | geändert |
| Rasenkante | Lebensmittel | Baumaterial | hardware | geändert |
| Regentonne | Garten | Garten | hardware |  |
| Komposter | Haushaltswaren | Garten | hardware | geändert |
| Nistkasten | Lebensmittel | Garten | hardware | geändert |
| Vogelhaus | Lebensmittel | Garten | hardware | geändert |
| Insektenhotel | Getränke | Garten | hardware | geändert |
| Meisenknödel | Lebensmittel | Tierbedarf | grocery | geändert |
| Igelfutter | Lebensmittel | Tierbedarf | grocery | geändert |
| Hundeleine | Lebensmittel | Tierbedarf | grocery | geändert |
| Fressnapf | Lebensmittel | Tierbedarf | grocery | geändert |
