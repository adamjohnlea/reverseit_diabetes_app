import Foundation

/// Metric ↔ imperial conversions for body measurements.
///
/// All persistence and calculations use metric (kilograms / centimeters);
/// anything converting for display or input must go through these instead of
/// hand-rolled constants.
enum BodyMeasurement {
    static func kilograms(fromPounds pounds: Double) -> Double {
        Measurement(value: pounds, unit: UnitMass.pounds).converted(to: .kilograms).value
    }

    static func pounds(fromKilograms kilograms: Double) -> Double {
        Measurement(value: kilograms, unit: UnitMass.kilograms).converted(to: .pounds).value
    }

    static func centimeters(fromInches inches: Double) -> Double {
        Measurement(value: inches, unit: UnitLength.inches).converted(to: .centimeters).value
    }

    static func inches(fromCentimeters centimeters: Double) -> Double {
        Measurement(value: centimeters, unit: UnitLength.centimeters).converted(to: .inches).value
    }
}

/// Imperial accessors over the canonical metric storage.
extension UserProfile {
    var weightInPounds: Double {
        get { BodyMeasurement.pounds(fromKilograms: weight) }
        set { weight = BodyMeasurement.kilograms(fromPounds: newValue) }
    }

    var heightInInches: Double {
        get { BodyMeasurement.inches(fromCentimeters: height) }
        set { height = BodyMeasurement.centimeters(fromInches: newValue) }
    }
}
