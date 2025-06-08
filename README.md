# ReverseIt! Diabetes Management App

## Overview

ReverseIt! is an iOS application designed to help individuals with type 2 diabetes track and potentially reverse their condition through lifestyle modifications. The app provides comprehensive tools for monitoring blood glucose levels, tracking food intake with a focus on carbohydrates, logging exercise activities, and visualizing progress over time.

## Features

- **Glucose Monitoring**: Log and track blood glucose readings
- **Food Logging**: Record meals with nutritional information, focusing on carbohydrate intake
- **Exercise Tracking**: Log physical activities with duration and intensity
- **Progress Dashboard**: Visualize health metrics and progress
- **Goal Setting**: Set personalized targets for glucose levels, carb intake, and exercise
- **Cross-Device Syncing**: Seamlessly access your data across all your Apple devices
- **Health App Integration**: Optional synchronization with Apple Health

## Technology Stack

- **SwiftUI**: Modern declarative UI framework
- **SwiftData**: Persistent storage framework for data management
- **Swift Charts**: Data visualization
- **CloudKit**: Cross-device data synchronization
- **HealthKit**: Integration with Apple Health (optional)

## Requirements

- iOS 17.0+
- Xcode 15.0+
- macOS Sonoma 14.0+ (for development)

## Setup Instructions

### Prerequisites
- macOS (required for Xcode)
- Xcode 15.0+ (Apple's IDE for iOS development)
- XcodeGen (tool for generating Xcode projects from YAML)

### Installation

1. Clone the repository:
```bash
git clone https://github.com/yourusername/reverseit-diabetes-app.git
cd reverseit-diabetes-app
```

2. Generate the Xcode project:
```bash
xcodegen generate
```

3. Open the project in Xcode:
```bash
open ReverseItApp.xcodeproj
```

4. Build and run the app on your simulator or device

## App Structure

```
ReverseItApp/
├── ReverseItApp.swift     # Main app entry point
├── Models/                # SwiftData models
│   ├── UserProfile.swift  # User profile data
│   ├── GlucoseReading.swift # Glucose readings
│   ├── FoodEntry.swift    # Food logging
│   └── ExerciseEntry.swift # Exercise tracking
├── Views/                 # UI components
│   ├── ContentView.swift  # Main container view
│   ├── OnboardingView.swift # First-time setup
│   ├── DashboardView.swift # Home screen
│   ├── GlucoseLogView.swift # Glucose tracking
│   ├── FoodLogView.swift  # Food logging
│   ├── ExerciseLogView.swift # Exercise tracking
│   └── SettingsView.swift # User settings
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Created as a tool to help people manage and potentially reverse type 2 diabetes
- Inspired by research showing that lifestyle changes can lead to remission in many cases
- Built with SwiftUI and SwiftData for a modern iOS experience