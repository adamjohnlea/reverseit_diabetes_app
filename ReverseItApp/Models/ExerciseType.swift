import Foundation
import HealthKit

/// The exercise activities the app supports, bridged bidirectionally to HealthKit.
///
/// `ExerciseEntry.type` persists the raw value as a plain string, so raw values
/// must remain stable — they exist in users' SwiftData stores.
enum ExerciseType: String, CaseIterable, Sendable {
    case walking = "Walking"
    case running = "Running"
    case cycling = "Cycling"
    case swimming = "Swimming"
    case yoga = "Yoga"
    case hiit = "HIIT"
    case weightTraining = "Weight Training"
    case pilates = "Pilates"
    case dance = "Dance"
    case hiking = "Hiking"
    case tennis = "Tennis"
    case basketball = "Basketball"
    case soccer = "Soccer"
    case rowing = "Rowing"
    case elliptical = "Elliptical"
    case other = "Other Exercise"

    var workoutActivityType: HKWorkoutActivityType {
        switch self {
        case .walking: .walking
        case .running: .running
        case .cycling: .cycling
        case .swimming: .swimming
        case .yoga: .yoga
        case .hiit: .highIntensityIntervalTraining
        case .weightTraining: .traditionalStrengthTraining
        case .pilates: .pilates
        case .dance: .cardioDance
        case .hiking: .hiking
        case .tennis: .tennis
        case .basketball: .basketball
        case .soccer: .soccer
        case .rowing: .rowing
        case .elliptical: .elliptical
        case .other: .other
        }
    }

    init(workoutActivityType: HKWorkoutActivityType) {
        switch workoutActivityType {
        case .walking: self = .walking
        case .running: self = .running
        case .cycling: self = .cycling
        case .swimming: self = .swimming
        case .yoga: self = .yoga
        case .highIntensityIntervalTraining: self = .hiit
        case .traditionalStrengthTraining: self = .weightTraining
        case .pilates: self = .pilates
        case .cardioDance, .socialDance: self = .dance
        case .hiking: self = .hiking
        case .tennis: self = .tennis
        case .basketball: self = .basketball
        case .soccer: self = .soccer
        case .rowing: self = .rowing
        case .elliptical: self = .elliptical
        default: self = .other
        }
    }

    /// Matches free-form text (such as workout names imported from other apps)
    /// to a known type, defaulting to `.other` when nothing matches.
    init(matching freeText: String) {
        let text = freeText.lowercased()

        if text.contains("walk") {
            self = .walking
        } else if text.contains("run") || text.contains("jog") {
            self = .running
        } else if text.contains("bike") || text.contains("cycle") || text.contains("cycling") {
            self = .cycling
        } else if text.contains("swim") {
            self = .swimming
        } else if text.contains("yoga") {
            self = .yoga
        } else if text.contains("hiit") {
            self = .hiit
        } else if text.contains("weight") || text.contains("gym") || text.contains("strength") {
            self = .weightTraining
        } else if text.contains("pilates") {
            self = .pilates
        } else if text.contains("dance") {
            self = .dance
        } else if text.contains("hik") {
            self = .hiking
        } else if text.contains("tennis") {
            self = .tennis
        } else if text.contains("basketball") {
            self = .basketball
        } else if text.contains("soccer") || text.contains("football") {
            self = .soccer
        } else if text.contains("row") {
            self = .rowing
        } else if text.contains("elliptical") {
            self = .elliptical
        } else {
            self = .other
        }
    }
}

extension ExerciseEntry {
    /// Typed view over the persisted `type` string.
    ///
    /// Falls back to fuzzy matching for legacy rows whose stored value is not an
    /// exact `ExerciseType` raw value.
    var exerciseType: ExerciseType {
        get { ExerciseType(rawValue: type) ?? ExerciseType(matching: type) }
        set { type = newValue.rawValue }
    }
}
