# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ReverseIt! is an iOS app (iOS 26+, Swift 6, strict concurrency) for type 2 diabetes management: glucose, food, and exercise tracking with Apple Health sync. SwiftUI + SwiftData + HealthKit + Swift Charts.

## Project Management

`ReverseItApp.xcodeproj` is the **source of truth** — edit it directly (via Xcode or the Xcode MCP tools). The project was originally generated with XcodeGen, but `project.yml` has been removed; do not reintroduce it.

Targets: `ReverseItApp` (app), `ReverseItAppTests` (Swift Testing unit tests), `ReverseItAppUITests` (XCUIAutomation UI tests). One shared scheme: `ReverseItApp`.

The project uses **explicit file references** (not synchronized folders), so new source files must be registered in the pbxproj — create them with the `XcodeWrite` MCP tool (which registers them) rather than plain filesystem writes. Resources (asset catalogs, string catalogs) additionally need a Resources build-phase entry.

## Localization

User-facing strings live in `ReverseItApp/Localizable.xcstrings`, auto-populated at build time (`SWIFT_EMIT_LOC_STRINGS` / `LOCALIZATION_PREFERS_STRING_CATALOGS` are on). English is the only language so far. When adding user-facing text: use `Text("literal")` in views (auto-extracted), `LocalizedStringResource` for display strings on model/non-view types (see the enum `description` properties), and `String(localized:)` for `errorDescription`. Use `Text(verbatim:)` for punctuation/symbols that must not be translated. A headless `xcodebuild` compiles strings into the product but doesn't sync them back to the source catalog — Xcode's editor does that on open, or run `xcodebuild -exportLocalizations`.

## Build Commands

```bash
make          # build (xcodebuild via xcbeautify)
make test     # unit tests only (ReverseItAppTests)
make ui-test  # UI tests (only at handoff points — takes over the simulator)
make lint     # swiftlint --strict
```

The Makefile exports `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer` because `xcode-select` on this machine points at CommandLineTools — don't run bare `xcodebuild` without it. When running inside Xcode, the `BuildProject` tool also works.

Zero-warnings policy applies to every build.

## Architecture

**Entry point** (`ReverseItApp/ReverseItApp.swift`): builds a `ModelContainer` with the four SwiftData models, injects it via `.modelContainer()`, and injects `HealthKitManager.shared` via `.environment()`.

**Navigation** (`Views/ContentView.swift`): if no `UserProfile` exists or `onboardingCompleted` is false, shows `OnboardingView`; otherwise a five-tab `TabView` (Dashboard, Food Log, Exercise, Glucose, Settings).

**No view-model layer.** Business logic lives on the SwiftData `@Model` classes themselves as computed properties and extension methods that take a `ModelContext` parameter (e.g. `UserProfile.glucoseProgress(modelContext:)`, `FoodEntry.totalCarbsForDay(_:modelContext:)`, `GlucoseReading.fetchLatestReadings(_:modelContext:)`). Views read data with `@Query` and call these helpers directly. Follow this pattern for new features rather than introducing separate view models or repositories.

**Models** (`Models/`): `UserProfile`, `GlucoseReading`, `FoodEntry`, `ExerciseEntry`.
- `UserProfile` is a de-facto singleton — views take `userProfiles.first` from `@Query`. It holds all user goals (glucose target range, daily carbs, daily exercise minutes) and the `useMetricSystem` flag.
- `GlucoseReading.relatedFood` and `FoodEntry.glucoseReadings` form an optional many-to-many `@Relationship` (`.nullify` delete rule) used for meal↔glucose correlation.
- Enums nested in models (`ReadingType`, `MealType`, `ExerciseIntensity`) are `String`-raw-valued and `Codable`; their raw values are persisted and also written into HealthKit metadata — don't rename cases casually.

**Units convention**: glucose is stored in mg/dL, weight in kg, height in cm — always. Imperial display conversion happens only at the view layer based on `UserProfile.useMetricSystem`.

**Data retention**: `UserProfile.cleanupOldData(modelContext:)` deletes glucose readings older than 3 months; `ModelContext.resetAllData()` (extension in `UserProfile.swift`) wipes all models in relationship-safe order.

## HealthKit Integration

`Services/HealthKitManager.swift` is a `@MainActor @Observable` singleton (`HealthKitManager.shared`), accessed in views via `@Environment(HealthKitManager.self)`.

- `healthStore` is `nil` when HealthKit is unavailable (e.g. some Simulators/iPads); every method guards on it and silently no-ops — preserve this guard in new methods.
- Older callback-based `HKSampleQuery` APIs are bridged to async/await with `withCheckedThrowingContinuation`; callbacks hop back to the main actor with `Task { @MainActor in ... }` before touching state or resuming.
- Exercise type mapping between the app's string-based exercise types and `HKWorkoutActivityType` lives in `workoutActivityType(for:)` / `exerciseTypeFromWorkout(_:)` — keep both directions in sync when adding exercise types.
- Import from HealthKit (`importDataFromHealthKit`) processes samples in small batches with a `modelContext.save()` per batch; follow that pattern for bulk inserts.

## Swift 6 Concurrency

The codebase compiles under Swift 6 strict concurrency. UI-adjacent classes are `@MainActor`; state management uses the Observation framework (`@Observable` + `@Environment`), not ObservableObject/Combine. Prefer async/await wrappers over adding new completion-handler APIs.
