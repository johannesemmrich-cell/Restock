# App Review Notes – Restock 1.0

Antwort auf Guideline 2.1 „Information Needed“ (Submission 660fc9f9-fa7f-4f98-a85b-c24fd4a51d19, eingereicht 2026-10-31).
Der Block unter `## notes` geht wortgleich ins Feld „Notes“ der App Review Information (Grenze 4000 Zeichen)
und als Antwort ins Resolution Center, zusammen mit der Bildschirmaufnahme vom iPhone.

## notes

1. SCREEN RECORDING
Attached to our reply: recorded on a physical iPhone (TestFlight build 1.0 (38)), starting with launching Restock from TestFlight. The one-time setup (country, stores) was already done on this device, so it opens on the home screen. It shows: quick-add with automatic store assignment ("Hackfleisch" to Lidl, "Zahnpasta" to dm); sharing a digital receipt from the Lidl Plus app to Restock, reviewing and saving it; a list with checked-off items; sharing a store (code, members); the Restock Pro paywall with prices, terms, Privacy/EULA links and "Restore Purchases" (the Apple Account prompt was cancelled, so the app shows its "restore not completed" notice). No purchase is completed; products are listed in section 3. Restock has no account registration or login, so there is no sign-up or account deletion flow.

2. PURPOSE AND AUDIENCE
Restock is a shopping list for households that shop at several stores. You type what you need ("500 g minced meat", "toothpaste") and Restock puts each item on the list of the store where you usually buy it. It learns the order in which you check items off and sorts the list along your route. Scanned receipts teach Restock real prices, so you see what a trip will roughly cost. Target audience: adults and families organizing their weekly shopping.

3. HOW TO USE / NO LOGIN
No login or demo account is needed.
- On first launch choose a country; Restock suggests matching stores (e.g. Lidl, Rewe, dm).
- Type an item into the field at the top of the home screen and tap Add; the card below shows the target store and why.
- Open a store tile to see its list; tap a row to check an item off.
- Receipt: after checking off at least one item, open the store's ··· menu and choose "Kassenbon scannen" (scan receipt), then photograph any supermarket receipt; or share a receipt image from Photos to Restock. You review the recognized lines and save.
- Barcode: tap + (top right), then the barcode icon next to the name field, and scan any food product.
- Restock Pro: the fork icon (Recipe Plan) and the chart icon (Spending Analysis) at the top of the home screen open the paywall. Products: monthly and yearly auto-renewable subscriptions and a non-consumable Lifetime purchase, group "Restock Pro". "Restore Purchases" is on the paywall.
- Shared store: in a store list tap the share button; Restock shows a code. The other person enters it via Settings > Join Shared List. Only people with the code see that list; there is no public content.

4. EXTERNAL SERVICES
- Apple iCloud / CloudKit: syncing the user's own data across their devices (private database); shared store lists and anonymous community prices (public database).
- Apple StoreKit: In-App Purchases for Restock Pro.
- Apple Vision (on device): text recognition on receipts and recipe photos.
- Apple Intelligence / Foundation Models (on device, only if available): helps read abbreviated receipt names and ingredients from recipe photos. All features work without it.
- Open Food Facts (world.openfoodfacts.org): product name lookup for a scanned barcode; only the barcode number is sent.
No ads, no analytics, no tracking, no third-party SDKs.

5. REGIONAL DIFFERENCES
The app works the same in all regions. Differences: onboarding store suggestions are prepared for DE, AT, CH, BE, NL, FR, IT, ES, GB and US (custom stores work anywhere); the UI is German and English; Apple Intelligence features appear only where Apple offers them, with a fallback everywhere.

6. REGULATED INDUSTRY / THIRD-PARTY MATERIAL
Not applicable; Restock is not in a regulated industry. Store names are only editable list labels; no retailer logos or trademarks are used. Price data comes from the user's own receipts, a hand-made catalog, and Open Food Facts data under the Open Database License.
