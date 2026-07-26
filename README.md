# ReverseIt! Diabetes Management App

A comprehensive iOS application designed to help individuals with type 2 diabetes manage and potentially reverse their condition through evidence-based lifestyle modifications.

## Table of Contents

- [Overview](#overview)
- [Key Features](#key-features)
- [Screenshots](#screenshots)
- [Technology Stack](#technology-stack)
- [Requirements](#requirements)
- [Installation](#installation)
- [App Structure](#app-structure)
- [Data Models](#data-models)
- [Apple Health Integration](#apple-health-integration)
- [Testing](#testing)
- [Usage Guide](#usage-guide)
- [Accessibility & Localization](#accessibility--localization)
- [Privacy & Security](#privacy--security)
- [Contributing](#contributing)
- [License](#license)

## Overview

ReverseIt! is a modern iOS health tracking application that provides comprehensive tools for diabetes management. The app focuses on the three critical pillars of type 2 diabetes reversal: blood glucose monitoring, carbohydrate-conscious nutrition, and regular physical activity.

Built with Swift 6 and leveraging the latest Apple technologies (SwiftUI, SwiftData, HealthKit), ReverseIt! offers an intuitive interface for tracking daily health metrics, visualizing progress, and achieving personalized health goals.

## Key Features

### Core Tracking Capabilities

- **Blood Glucose Monitoring**
  - Log readings with type classification (fasting, before/after meal, bedtime, random)
  - Color-coded status indicators (low, normal, high)
  - Personalized target ranges
  - Visual trend analysis with charts
  - Calculate in-range percentage

- **Comprehensive Food Logging**
  - Track meals by type (breakfast, lunch, dinner, snack)
  - Detailed macronutrient breakdown (carbs, protein, fat)
  - Automatic calorie calculation from macros
  - Daily carbohydrate goal tracking
  - Visual macro distribution with donut charts
  - Optional meal photos
  - Correlate meals with glucose readings

- **Exercise & Activity Tracking**
  - 15 predefined exercise types (walking, running, cycling, swimming, etc.)
  - Duration and intensity tracking (light, moderate, vigorous)
  - Automatic calorie estimation using MET values
  - Daily exercise goal monitoring
  - Weekly activity visualization
  - Progress indicators

### Analytics & Visualization

- **Interactive Dashboard**
  - At-a-glance health summary
  - Latest glucose reading
  - Daily carb and exercise progress
  - Days on diabetes management journey
  - Weekly glucose trend chart
  - Quick-add action buttons

- **Progress Charts**
  - Glucose trends over time
  - Weekly exercise bar charts
  - Macronutrient distribution pie charts
  - Goal progress indicators

### Smart Features

- **Personalized Goals**
  - Custom glucose target ranges
  - Daily carbohydrate limits
  - Daily exercise minute targets
  - Goal validation and recommendations

- **Health Insights**
  - BMI calculation and categorization
  - Days-since-diagnosis tracking on the dashboard
  - Average / lowest / highest glucose statistics
  - Macro percentage breakdowns

### Apple Health Integration

- **Bidirectional Sync**
  - Import recent glucose readings and workouts from Apple Health
  - Export glucose, nutrition, and workout entries to Apple Health as they are logged

- **Supported Health Data Types**
  - Blood glucose levels
  - Active energy burned
  - Workouts and activities
  - Dietary carbohydrates, protein, fat
  - Body mass and height

### User Experience

- **Onboarding Flow**
  - Three-page setup: welcome, profile creation, optional HealthKit authorization
  - Input validation with clear error messages

- **Customization**
  - Metric (kg, cm) or Imperial (lb, in) units
  - Personalized health goals
  - Per-day filtering of food and exercise logs

- **Safe, Accessible Interactions**
  - Confirmation dialogs before deleting any entry
  - VoiceOver labels and combined-element rows throughout
  - Dynamic Type support and semantic colors that adapt to light/dark mode
  - Errors surfaced to the user, never silently swallowed

- **Data Management**
  - Local, on-device storage with SwiftData
  - Import from and export to Apple Health
  - Reset-all-data option for a fresh start

## Screenshots

_Coming soon_

## Technology Stack

### Frameworks & Libraries

- **SwiftUI** - Declarative UI framework for all views
- **SwiftData** - Apple's persistence framework, storing all data on-device
- **Swift Charts** - Native charting (line/point glucose trends, macro donut, weekly exercise bars)
- **HealthKit** - Apple Health integration via the modern async query descriptors and `HKWorkoutBuilder`
- **String Catalog** - `Localizable.xcstrings` for localization (English source)

### Swift Language Features

- **Swift 6 language mode** - Complete strict-concurrency checking enabled
- **Observation framework** - `@Observable` for state, not Combine/`ObservableObject`
- **Async/await** - all asynchronous work, including HealthKit reads/writes
- **`@MainActor`** - UI and the HealthKit manager are main-actor isolated; `Sendable` DTOs cross actor boundaries

### Architecture

- **No view-model layer** - views read data with `@Query` and call logic that lives directly on the SwiftData `@Model` types (see `UserProfile.glucoseProgress(modelContext:)`, `FoodEntry.totalCarbsForDay(_:modelContext:)`)
- **Shared helpers in `Support/`** - status→color mapping (`StatusStyle`) and metric/imperial conversion (`BodyMeasurements`) kept out of the models and views
- **`HealthKitManager`** - a `@MainActor @Observable` singleton injected via the SwiftUI environment
- **Reusable view modifiers** - `confirmDelete(...)` and `errorAlert(...)` give one code path for destructive actions and error surfacing

## Requirements

### Minimum Requirements

- **iOS**: 18.0 or later
- **Xcode**: 16.0 or later (for development)
- **Swift**: 6.0

### Device Compatibility

- iPhone running iOS 18+
- iPad running iPadOS 18+

## Installation

### For Users

_App Store release coming soon_

### For Developers

#### Prerequisites

- macOS with Xcode 16.0+ installed
- [xcbeautify](https://github.com/cpisciotta/xcbeautify) and [SwiftLint](https://github.com/realm/SwiftLint) (`brew install xcbeautify swiftlint`) for the `make` workflow

#### Setup Steps

1. Clone the repository:
```bash
git clone https://github.com/adamjohnlea/reverseit_diabetes_app.git
cd reverseit_diabetes_app
```

2. Open the project:
```bash
open ReverseItApp.xcodeproj
```

3. Select your development team in Xcode under the ReverseItApp target's Signing & Capabilities.

4. Build and run with `Cmd + R`, or from the command line:

```bash
make          # build
make test     # unit tests
make ui-test  # UI tests
make lint     # swiftlint --strict
```

## App Structure

```
reverseit_diabetes_app/
├── ReverseItApp/
│   ├── ReverseItApp.swift         # Main app entry point
│   ├── Models/                    # SwiftData models + ExerciseType enum
│   ├── Views/                     # SwiftUI views (+ Components/)
│   ├── Support/                   # Shared helpers (StatusStyle, BodyMeasurements)
│   ├── Services/
│   │   └── HealthKitManager.swift # Apple Health integration
│   ├── Assets.xcassets            # App icon + accent color
│   ├── Localizable.xcstrings      # String Catalog (localization)
│   ├── Info.plist                 # App configuration
│   └── ReverseIt.entitlements     # App capabilities (HealthKit)
├── ReverseItAppTests/             # Swift Testing unit tests
├── ReverseItAppUITests/           # XCUIAutomation UI tests
├── Makefile                       # build / test / ui-test / lint
├── .swiftlint.yml                 # Lint configuration
└── README.md                      # This file
```

> The Xcode project (`ReverseItApp.xcodeproj`) is the source of truth and is committed to the repo. The project was originally generated with XcodeGen, but `project.yml` has been removed — edit the project directly in Xcode.

## Data Models

### UserProfile

Stores user demographics, health information, and personalized goals.

**Key Properties:**
- Personal info: name, age, weight, height, diagnosis date
- Health goals: target glucose range, daily carb limit, daily exercise minutes
- Preferences: metric/imperial units, onboarding status
- Computed: BMI, BMI category, diabetes duration

**Key Methods:**
- `glucoseProgress(modelContext:days:)` - In-range percentage and average over a window
- `isOnTrackWithDailyCarbs(modelContext:)` / `isOnTrackWithExercise(modelContext:)` - Goal checks for today
- `validateTargets()` - Clamp goals to sensible bounds

Imperial display values are provided by `weightInPounds` / `heightInInches` accessors (in `Support/BodyMeasurements.swift`) over the canonical metric storage.

### GlucoseReading

Tracks blood glucose measurements over time.

**Key Properties:**
- Reading value (mg/dL)
- Timestamp
- Reading type (fasting, before/after meal, bedtime, random)
- Optional notes
- Relationship to food entries

**Key Methods:**
- `readingStatus` - Classification (low, normal, high); its color comes from the `StatusStyle` extension
- `isInRange(min:max:)` - Check against the user's target range
- `fetchLatestReadings(_:modelContext:)` / `averageForPeriod(start:end:modelContext:)` - Queries

### FoodEntry

Logs meals and nutritional intake.

**Key Properties:**
- Food name and meal type
- Macronutrients: carbs, protein, fat (grams)
- Calculated calories
- Optional photo
- Optional notes
- Relationship to glucose readings

**Key Methods:**
- `macroPercentages` / `carbPercentage` / `proteinPercentage` / `fatPercentage` - Macro distribution (Atwater factors)
- `validate()` - Reject empty names and negative values
- `totalCarbsForDay(_:modelContext:)` / `totalCaloriesForDay(_:modelContext:)` - Daily sums
- `glucoseImpact(timeWindow:)` - Correlate a meal with nearby glucose readings

### ExerciseEntry

Tracks physical activity sessions.

**Key Properties:**
- Exercise type
- Start time and duration
- Intensity level
- Calories burned
- Optional notes

**Key Methods:**
- `estimatedCalories(weightKg:)` - MET-based estimate (uses measured calories when available)
- `formattedDuration` - Human-readable duration (e.g. "1h 5m")
- `progressTowardDailyGoal(targetMinutes:)` - Fraction of the daily goal, capped at 1.0
- `totalDurationForDay(_:modelContext:)` - Daily sum

Exercise types are modeled by the `ExerciseType` enum, which maps bidirectionally to `HKWorkoutActivityType` and matches free-text names for imported workouts.

## Apple Health Integration

### Permissions

The app requests permission to read and write the following HealthKit data types:

**Read:**
- Blood glucose (HKQuantityType.bloodGlucose)
- Active energy burned (HKQuantityType.activeEnergyBurned)
- Workouts (HKObjectType.workout)
- Dietary carbohydrates (HKQuantityType.dietaryCarbohydrates)
- Dietary fat (HKQuantityType.dietaryFatTotal)
- Dietary protein (HKQuantityType.dietaryProtein)
- Body mass (HKQuantityType.bodyMass)
- Height (HKQuantityType.height)

**Write:**
- All of the above (bidirectional sync)

### Sync Features

- **Manual import**: Pull the last 7 days of glucose readings and workouts from Apple Health via Settings → "Import Data from Apple Health"
- **Export on save**: When "Sync with Apple Health" is enabled, each glucose reading, meal, and workout you log is written to Apple Health (each add screen also has a per-entry sync toggle)
- **Graceful degradation**: On devices without HealthKit, sync options are hidden and all sync methods no-op

## Testing

The project has separate unit and UI test targets and a `make`-based workflow.

- **Unit tests** (`ReverseItAppTests`, Swift Testing) cover the model logic: BMI and category boundaries, target clamping, glucose status thresholds and in-range/progress math, macro and calorie calculations, MET-based calorie estimation, metric/imperial round-trips, the `ExerciseType` ↔ HealthKit mapping, and day-boundary SwiftData queries (run against an in-memory `ModelContainer`).
- **UI tests** (`ReverseItAppUITests`, XCUIAutomation) cover the onboarding flow, launching into a seeded state, and swipe-to-delete confirmation. The app accepts `-uitest-reset` (empty in-memory store) and `-uitest-seeded` (profile + sample reading) launch arguments for deterministic runs.

```bash
make test      # unit tests
make ui-test   # UI tests (takes over the simulator)
```

Verified on both the deployment floor (iOS 18.6 simulator) and the latest OS (iOS 27 simulator).

## Usage Guide

### First-Time Setup

1. **Launch App**: Open ReverseIt! for the first time
2. **Welcome**: Read the introduction
3. **Create Profile**: Enter your personal information
   - Name, age, weight, height
   - Diabetes diagnosis date
   - Choose metric or imperial units
4. **Authorize HealthKit** (optional): Grant permissions to sync with Apple Health
5. **Start Tracking**: Begin logging your health data

### Daily Workflow

1. **Morning Routine**
   - Log fasting glucose reading
   - Set daily intentions

2. **Throughout the Day**
   - Log meals before or after eating
   - Record glucose readings (before/after meals)
   - Track exercise activities

3. **Review Progress**
   - Check dashboard for daily summary
   - Review charts for trends
   - Adjust goals as needed

### Tips for Success

- **Consistency**: Log data daily for accurate trends
- **Timing**: Test glucose at consistent times
- **Detail**: Add notes to track patterns (mood, stress, sleep)
- **Goals**: Start with achievable targets and adjust gradually
- **Review**: Weekly review of progress to identify patterns

## Accessibility & Localization

- **VoiceOver**: interactive elements are real `Button`s with accessibility labels; list rows are combined into single, meaningfully-labeled elements (e.g. a glucose row announces its type, value, and status rather than color alone), and swipe-to-delete is mirrored by a VoiceOver custom action.
- **Dynamic Type**: text uses system text styles so it scales with the user's preferred size.
- **Color**: status and UI colors are semantic system colors that adapt to light and dark mode; no hard-coded RGB.
- **Localization**: all user-facing strings are in `Localizable.xcstrings` and auto-extracted at build time. English is the only language today, but the app is ready to translate (model display strings use `LocalizedStringResource`, errors use `String(localized:)`).

## Privacy & Security

### Data Storage

- All data stored locally on device using SwiftData
- No third-party servers or analytics
- No data sharing without explicit user consent

### Health Data

- HealthKit data access requires explicit user permission
- All health data syncing is optional
- Users can revoke access anytime via iOS Settings
- Health data never leaves Apple's ecosystem without permission

### Data Retention

- Data is retained on device until the user deletes it
- Users can delete individual entries, or reset all data via Settings
- Deletion is permanent and immediate

## Contributing

Contributions are welcome! Please follow these guidelines:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Code Standards

- Follow the Swift API Design Guidelines
- `make lint` (SwiftLint, `--strict`) must pass — force-unwraps are an error in app code
- Builds are warning-free (`SWIFT_TREAT_WARNINGS_AS_ERRORS` is on); keep them that way
- Add or update tests for behavior changes; `make test` must pass
- No force-unwraps, no silently swallowed errors — surface failures to the user
- Ensure Swift 6 strict-concurrency compliance

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Created to help people manage and potentially reverse type 2 diabetes through lifestyle changes
- Inspired by research showing that lifestyle modifications can lead to remission in many type 2 diabetes cases
- Built with modern Apple technologies for the best iOS experience
- Special thanks to the diabetes management community for feedback and insights

## Support

For questions, issues, or feature requests, open an issue at
[github.com/adamjohnlea/reverseit_diabetes_app](https://github.com/adamjohnlea/reverseit_diabetes_app/issues).

## Disclaimer

This app is designed to support diabetes management but is not a substitute for professional medical advice, diagnosis, or treatment. Always consult with your healthcare provider before making changes to your diabetes management plan.

---

**ReverseIt!** - Take control of your health, one day at a time.
