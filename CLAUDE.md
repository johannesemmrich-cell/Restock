# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build

```bash
# Build for simulator (no sudo needed after first setup)
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -scheme SmartCart \
             -project SmartCart.xcodeproj \
             -destination 'generic/platform=iOS Simulator' \
             build 2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"
```

There are no automated tests. UI verification requires running in Xcode or Simulator.

## Adding new Swift files

Xcode does **not** auto-discover files on disk. Every new `.swift` file must be manually registered in `SmartCart.xcodeproj/project.pbxproj` in three places:

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

### Services (`SmartCart/Services/`)

- **`AssignmentService`** — assigns a new item to the best `Store` based on: (1) purchase history dominance, (2) drugstore-keyword matching, (3) highest-visit grocery store. Also maps item names → category strings.
- **`QuickAddParser`** — parses freetext like `"500 gramm Hackfleisch"` → `{name, quantity, quantityAmount, unit}`. `knownUnits` contains both abbreviations (`g`, `kg`) and German long-forms (`gramm`, `kilogramm`, etc.).
- **`HabitService`** — reads `PurchaseRecord`s, calls `consumptionPattern()` on each group, returns items due for repurchase. IQR outlier filtering in `PurchaseRecord.swift` removes vacation gaps from interval averages.
- **`SeasonalService`** — returns seasonal suggestions per month. Controlled by `@AppStorage("seasonalSuggestionsEnabled")`.
- **`RecipeRecognitionService`** — Vision OCR + Apple Intelligence (`FoundationModels`, iOS 26+) to extract ingredients from a photo.
- **`NotificationService`** — schedules local replenishment notifications.

### Views

**`HomeView`** is the main screen. It composes: header card, quick-add bar (with `QuickAddParser` live preview chip), replenishment banner, seasonal suggestions banner, store grid. Toolbar: gear (Settings), fork.knife (MenuPlan), plus (AddItem).

**`StoreDetailView`** shows pending and completed items for one store. Items are sorted by `store.itemOrderMap` (learned aisle order from completion history).

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
