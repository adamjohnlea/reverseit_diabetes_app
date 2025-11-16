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
- [Usage Guide](#usage-guide)
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
  - Diabetes duration tracking
  - Average glucose calculations
  - Macro percentage breakdowns
  - Glucose impact analysis

### Apple Health Integration

- **Bidirectional Sync**
  - Import historical glucose data
  - Import nutrition and workout data
  - Export all tracked data to Apple Health
  - Real-time synchronization

- **Supported Health Data Types**
  - Blood glucose levels
  - Active energy burned
  - Workouts and activities
  - Dietary carbohydrates, protein, fat
  - Body mass and height

### User Experience

- **Onboarding Flow**
  - Three-step setup process
  - Profile creation
  - HealthKit authorization

- **Customization**
  - Metric (kg, cm) or Imperial (lb, in) units
  - Personalized health goals
  - Flexible date filtering
  - Swipe-to-delete actions

- **Data Management**
  - iCloud sync across devices
  - Automatic cleanup of old data (3+ months)
  - Batch data import/export
  - Reset option for fresh start

## Screenshots

_Coming soon_

## Technology Stack

### Frameworks & Libraries

- **SwiftUI** - Modern declarative UI framework for all views
- **SwiftData** - Apple's latest persistence framework (iOS 17+)
- **Swift Charts** - Native charting for data visualization
- **HealthKit** - Apple Health ecosystem integration
- **CloudKit** - Cross-device data synchronization

### Swift Language Features

- **Swift 6** - Latest version with strict concurrency checking
- **Observation Framework** - Modern state management with @Observable
- **Async/Await** - Modern concurrency for asynchronous operations
- **MainActor** - Thread safety for UI updates

### Architecture Patterns

- **MVVM-inspired** - Views observe SwiftData models
- **Singleton Pattern** - HealthKitManager shared instance
- **Dependency Injection** - Environment-based data sharing
- **Query-based Data** - @Query property wrapper for reactive data

## Requirements

### Minimum Requirements

- **iOS**: 17.0 or later
- **Xcode**: 15.0 or later (for development)
- **macOS**: Sonoma 14.0 or later (for development)
- **Swift**: 6.0

### Device Compatibility

- iPhone running iOS 17+
- iPad running iPadOS 17+

## Installation

### For Users

_App Store release coming soon_

### For Developers

#### Prerequisites

1. macOS with Xcode 15.0+ installed
2. XcodeGen installed (for project generation)

Install XcodeGen via Homebrew:
```bash
brew install xcodegen
```

#### Setup Steps

1. Clone the repository:
```bash
git clone https://github.com/yourusername/reverseit_diabetes_app.git
cd reverseit_diabetes_app
```

2. Generate the Xcode project:
```bash
xcodegen generate
```

3. Open the project:
```bash
open ReverseItApp.xcodeproj
```

4. Select your development team in Xcode:
   - Open project settings
   - Select the ReverseItApp target
   - Go to "Signing & Capabilities"
   - Select your team

5. Build and run:
   - Select a simulator or connected device
   - Press `Cmd + R` or click the Run button

## App Structure

```
reverseit_diabetes_app/
├── ReverseItApp/
│   ├── ReverseItApp.swift         # Main app entry point
│   ├── Models/                    # SwiftData models
│   │   ├── UserProfile.swift      # User profile and health goals
│   │   ├── GlucoseReading.swift   # Blood glucose tracking
│   │   ├── FoodEntry.swift        # Meal and nutrition logging
│   │   └── ExerciseEntry.swift    # Physical activity tracking
│   ├── Views/                     # SwiftUI views
│   │   ├── ContentView.swift      # Main tab navigation
│   │   ├── OnboardingView.swift   # First-time user setup
│   │   ├── DashboardView.swift    # Main dashboard
│   │   ├── GlucoseLogView.swift   # Glucose tracking interface
│   │   ├── FoodLogView.swift      # Food logging interface
│   │   ├── ExerciseLogView.swift  # Exercise tracking interface
│   │   └── SettingsView.swift     # Settings and configuration
│   ├── Services/
│   │   └── HealthKitManager.swift # Apple Health integration
│   ├── Info.plist                 # App configuration
│   └── ReverseIt.entitlements     # App capabilities
├── project.yml                    # XcodeGen configuration
└── README.md                      # This file
```

## Data Models

### UserProfile

Stores user demographics, health information, and personalized goals.

**Key Properties:**
- Personal info: name, age, weight, height, diagnosis date
- Health goals: target glucose range, daily carb limit, daily exercise minutes
- Preferences: metric/imperial units, onboarding status
- Computed: BMI, BMI category, diabetes duration

**Key Methods:**
- `glucoseProgress()` - Calculate in-range percentage
- `validateTargets()` - Ensure goals are reasonable
- `cleanupOldData()` - Remove readings older than 3 months

### GlucoseReading

Tracks blood glucose measurements over time.

**Key Properties:**
- Reading value (mg/dL)
- Timestamp
- Reading type (fasting, before/after meal, bedtime, random)
- Optional notes
- Relationship to food entries

**Key Methods:**
- `status` - Classification (low, normal, high)
- `colorForReading` - Visual color coding
- `isInRange()` - Check against user targets

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
- `macroPercentages()` - Calculate macro distribution
- `dailyTotals()` - Sum for specific date
- `glucoseImpact()` - Correlate with glucose readings

### ExerciseEntry

Tracks physical activity sessions.

**Key Properties:**
- Exercise type
- Start time and duration
- Intensity level
- Calories burned
- Optional notes

**Key Methods:**
- `estimatedCalories()` - Calculate using MET values
- `durationFormatted` - Human-readable duration
- `dailyTotal()` - Sum for specific date

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

- **Automatic Import**: Import historical health data on first authorization
- **Manual Import**: Trigger import from Settings
- **Continuous Sync**: Automatically write new entries to Apple Health
- **Toggle Control**: Enable/disable sync per data type

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

## Privacy & Security

### Data Storage

- All data stored locally on device using SwiftData
- Optional iCloud sync via CloudKit (encrypted in transit and at rest)
- No third-party servers or analytics
- No data sharing without explicit user consent

### Health Data

- HealthKit data access requires explicit user permission
- All health data syncing is optional
- Users can revoke access anytime via iOS Settings
- Health data never leaves Apple's ecosystem without permission

### Data Retention

- Glucose readings automatically archived after 3 months
- Users can manually reset all data via Settings
- Deletion is permanent and immediate

## Contributing

Contributions are welcome! Please follow these guidelines:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Code Standards

- Follow Swift API Design Guidelines
- Use SwiftLint for code formatting
- Write unit tests for new features
- Update documentation as needed
- Ensure Swift 6 concurrency compliance

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Created to help people manage and potentially reverse type 2 diabetes through lifestyle changes
- Inspired by research showing that lifestyle modifications can lead to remission in many type 2 diabetes cases
- Built with modern Apple technologies for the best iOS experience
- Special thanks to the diabetes management community for feedback and insights

## Support

For questions, issues, or feature requests:
- Open an issue on GitHub
- Contact: your.email@example.com

## Disclaimer

This app is designed to support diabetes management but is not a substitute for professional medical advice, diagnosis, or treatment. Always consult with your healthcare provider before making changes to your diabetes management plan.

---

**ReverseIt!** - Take control of your health, one day at a time.
