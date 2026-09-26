# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build

```bash
# Build for simulator (no sudo needed after first setup)
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -scheme Restock \
             -project Restock.xcodeproj \
             -destination 'generic/platform=iOS Simulator' \
             build 2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```

Unit tests live in `RestockTests/` and UI tests in `RestockUITests/`, both run via `xcodebuild test` (Xcode or Simulator). The Share Extension's cross-app flow additionally has `scripts/run-share-extension-uitest.sh`, which drives Photos → Share → Restock in the Simulator and checks the app-group container and crash logs directly, since a plain XCUITest cannot reach into the extension's own process.

The `Restock` scheme's Test Action pins `language="de"` / `region="DE"`, so UI tests always run in German regardless of the simulator's system language — relevant because the CI runner defaults to English. The tests assert on German label text, so this override is what makes them pass there; passing an explicit `-testLanguage`/`-testRegion` on the command line still overrides the scheme setting. `scripts/verify-ui-test-language.sh` proves this on a freshly erased, English-language simulator: one run without a language flag (expected 0 failures) and one with `-testLanguage en -testRegion US` as a negative control (expected the three known failures). Because the UI tests key off displayed text rather than `accessibilityIdentifier`s in the product code, copy changes can break them.

Some UI tests need a fixture screen that's normally only reachable via camera/OCR; these use DEBUG-only launch arguments in `SmartCartApp.swift` to seed the required data directly through the app's real data path. Because the app-group container persists across tests in the same `xcodebuild test` run, every test class that seeds data this way **must** remove it again in `tearDown()` via its own matching cleanup launch argument — otherwise leftover stores/items break other tests' assumptions, since the existing suite does not reset its own state.

## Adding new Swift files

Xcode does **not** auto-discover files on disk. Every new `.swift` file must be manually registered in `Restock.xcodeproj/project.pbxproj` in three places:

1. `PBXBuildFile` — links build UUID → file reference UUID
2. `PBXFileReference` — declares the file path
3. `PBXGroup` child list — places it in the correct folder group
4. `PBXSourcesBuildPhase` — adds it to the compile sources

Use 24-character hex UUIDs that don't conflict with existing ones. Use the `general-purpose` agent to do this reliably (it can read and edit pbxproj without external tools).

## Architecture

**iOS 18+, Swift 5.9, SwiftUI + SwiftData. No third-party dependencies.**

### Data layer — SwiftData models (`SmartCart/Models/`)

| Model | Role |
|-------|------|
| `Store` | A shop (name, emoji, color, visit frequency, learned item order). Owns `ShoppingItem`s. |
| `ShoppingItem` | One item on a list. Belongs to a `Store`. On completion, creates a `PurchaseRecord`. |
| `PurchaseRecord` | Historical log of a completed purchase. Powers habit/frequency analysis. |
| `FeedbackItem` | Dev-mode feedback entry (context, text, priority, isResolved). SwiftData only. |
| `TodoItem` | Dev-mode todo/idea. SwiftData only. |

`ModelContainer` is created in `SmartCartApp.init()` with all five models. **When adding a new `@Model`, it must be added to the `ModelContainer` initializer.**

Every process that opens the shared store (main app, Siri intent, widget, Share Extension) must go through `SharedModelContainer.make()` (`SmartCart/Models/SharedModelContainer.swift`). It branches exactly once, on whether the calling process is an app extension (`isAppExtension(bundleURL:)`, detected via the `.appex` bundle suffix): extensions open the local app-group store only, the main app keeps CloudKit mirroring with a local fallback. Read the warning comment at the top of that file before changing the branching or fallback order — it documents a prior data-loss incident and a since-corrected crash (Issue #4).

### Services (`SmartCart/Services/`)

- **`AssignmentService`** — assigns a new item to the best `Store` based on: (1) purchase history dominance, (2) drugstore-keyword matching, (3) highest-visit grocery store. Also maps item names → category strings.
- **`QuickAddParser`** — parses freetext like `"500 gramm Hackfleisch"` → `{name, quantity, quantityAmount, unit}`. `knownUnits` contains both abbreviations (`g`, `kg`) and German long-forms (`gramm`, `kilogramm`, etc.).
- **`HabitService`** — reads `PurchaseRecord`s, calls `consumptionPattern()` on each group, returns items due for repurchase. IQR outlier filtering in `PurchaseRecord.swift` removes vacation gaps from interval averages. The interval is not scaled by purchase quantity (Issue #30, A1). `ShoppingItem.markPending()` deletes the `PurchaseRecord` its `markCompleted()` created unless a receipt price was attached (A2). `OverdueNotificationLedger` limits the immediate overdue push to once per item and purchase cycle (A3); `ReplenishmentFeedback.resolveAccepted` (called from `HomeView.refreshDueSoon()`) treats a banner suggestion that was added and then deleted without a purchase like a ✕ dismissal (A4). Package B/D: `consumptionPattern()` collapses same-day purchases (B6), uses a recency-weighted interval (B1) and a consumption rate when all purchases share a unit (B5), switches to a weekday mode for items bought on fixed weekdays such as Mo + Mi (`PurchaseDay.fixedWeekdays`, 4a), and moves a date on a Sunday/German public holiday to the day before via `RetailClosedDays` (4b; default `.none`, `HabitService` passes `.current`). `HabitService.ineligibility` enforces ≥3 purchase days, coefficient of variation ≤ 0.5 in interval mode (measured on the consumption rates when B5 applies, else on the intervals), and ends a habit after 2.5× the typical gap (B2/B4); `ConsumptionPattern.dueWindowDays` is 20 % of the cycle, clamped to 1…7 days (B3). `HabitService.backtest` and `ReplenishmentMetrics` feed the dev-mode `ReplenishmentStatsView` (Settings → Nachkauf-Statistik, D1). C1: the banner's ✕ is a menu — „Hab noch“ (`ReplenishmentSnoozes`, shifts the date by half the usual gap, 1…14 days, but always at least due window + 2 days after now so it never reappears immediately, until the next purchase; the pattern keeps the computed date in `originalEstimatedDate`) and „Nicht mehr vorschlagen“ (`ReplenishmentBlocklist`); both are passed to `HabitService.dueSoonItems(from:snoozes:blocked:)` and can be undone in Settings → Developer → Ausgeblendete Vorschläge (`HiddenReplenishmentsView`). A3, A4, C1 and the D1 „shown“ count identify a purchase cycle by `ConsumptionPattern.purchaseKey` (timestamp of the latest `PurchaseRecord`), never by the computed date, which shifts with country (4b) and time zone without a purchase; `ReplenishmentKeyMigration` converted the older date-keyed entries once.
- **`SeasonalService`** — returns seasonal suggestions per month. Controlled by `@AppStorage("seasonalSuggestionsEnabled")`.
- **`RecipeRecognitionService`** — Vision OCR + Apple Intelligence (`FoundationModels`, iOS 26+) to extract ingredients from a photo.
- **`ReceiptParserService`** — parses receipt lines (Vision OCR/PDF) into `ReceiptLine`s (name, price, `quantity`, `weightBasis`). Two formats (`parseClassic` with VAT suffix, `parseEuroSuffixStyle`); quantity/weight confirmation lines under an item line are attributed to the preceding line (sanity check, Issue #9), never created as their own position; one directly following a STORNO line is skipped instead, without consuming `pendingStornoCancel` (Issue #24).
- **`NotificationService`** — schedules local replenishment notifications. Since Issue #30 C3 at most one bundled notification per day at 9:00 (`ReplenishmentDigestPlanner` in `SmartCart/Services/ReplenishmentDigest.swift`, 7 days ahead; overdue items go into the next digest instead of an immediate push). `HabitService.notificationCandidates` supplies the items (banner filters without the time window). An item enters `OverdueNotificationLedger` only after its digest's delivery time has passed (`ReplenishmentDigestLog.commitDelivered`), keyed by `ConsumptionPattern.notificationKey` (the purchase cycle, or the stored snooze date after „Hab noch“). `ReplenishmentBackgroundRefresh` re-plans via `BGAppRefreshTask` (`.backgroundTask(.appRefresh)` in `SmartCartApp`, identifier in `BGTaskSchedulerPermittedIdentifiers`, background mode `fetch`) so it works without opening the app.

### Views

**`HomeView`** is the main screen. It composes: header card, quick-add bar (with `QuickAddParser` live preview chip), replenishment banner, seasonal suggestions banner, store grid. Toolbar: gear (Settings), fork.knife (MenuPlan), plus (AddItem).

**`StoreDetailView`** shows pending and completed items for one store. Items are sorted by `store.itemOrderMap` (learned aisle order from completion history).

**`ReceiptReviewCard`** (`SmartCart/Views/Prices/ReceiptReviewCard.swift`) renders each parsed receipt line in `ReceiptScannerView`'s review list as its own card: the unedited printed receipt text, up to four selectable name options (best list match, AI suggestion, or a custom name field), a price/quantity summary line, and an inline "Ändern" editor for price and quantity. Replaces the former single-row `ReceiptLineRow`.

**`SettingsView`** handles: country/language pickers, store setup, notification toggles, version tap (5× to unlock dev mode), dev section (Feedback + Todos).

### Developer mode

Activated by tapping the version number 5× in Settings → password sheet (SHA256-hashed). Password hash stored in `SettingsView.devPasswordHash`. Once active:

- Orange **DEV pill** appears top-right (counts open `FeedbackItem`s via `@Query`; tap → `FeedbackListView`).
- Every screen shows a red **thumbs-down button** (bottom-right) via the `.devFeedback(context:)` view modifier — opens `DevFeedbackSheet` which saves a `FeedbackItem` via `modelContext`.
- Settings dev section exposes `FeedbackListView` and `TodoListView`.

**`FeedbackListView`**: two segmented pickers (Status + Priority), rows with inline priority segmented picker + green toggle for `isResolved`, swipe-to-delete, "Gelöste löschen" toolbar button.

**`TodoListView`**: Offen/Erledigt sections, tap row for notes, swipe actions (complete/delete/reopen), `+` toolbar button.

### Design conventions

- **Haptics**: always use `Haptics.impact(.light/.medium/.heavy)` or `Haptics.success()` — never `UIImpactFeedbackGenerator` directly.
- **Colors**: use semantic tokens from `DesignSystem.swift` (`Color.brand`, `.success`, `.warning`, `.destructive`) and `LinearGradient.brand`.
- **Card styling**: `.cardStyle()` view modifier gives white background + rounded corners + shadow.
- **Localization**: all user-facing strings via `String(localized: "key")`. Keys are defined in `Resources/`.
- **Dev feedback on every screen**: apply `.devFeedback(context: "Screen Name")` to the outermost view of every full-screen view. For `StoreDetailView`, include the store name: `.devFeedback(context: "Liste: \(store.name)")`.

### Siri / App Intents

`SmartCart/Intents/AddItemIntent.swift` — `AddShoppingItemIntent` creates its own `ModelContainer` (intents run out-of-process). Phrases must not contain `\(\.$parameter)` placeholders for `String` parameters (only `AppEntity`/`AppEnum` allowed); Siri will prompt for missing values via `requestValueDialog`.

### Barcode scanning

`BarcodeScannerSheet` wraps `DataScannerViewController` (VisionKit, iOS 16+). On barcode tap, calls Open Food Facts API (`world.openfoodfacts.org/api/v2/product/{barcode}`) for product name. Camera permission is already declared in the project settings.
