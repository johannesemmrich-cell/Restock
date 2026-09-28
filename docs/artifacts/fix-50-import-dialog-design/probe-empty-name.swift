// Prüft, ob ein leerer Artikelname in der Substring-Suche von
// `ReceiptScannerView.save()` (looseMatch) auf jeden beliebigen Kaufdatensatz passt.
let itemName = "maultaschen"
let lineLower = ""
print("record.itemName.contains(leer) =", itemName.lowercased().contains(lineLower))
print("leer.contains(record.itemName) =", lineLower.contains(itemName))
