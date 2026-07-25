import Foundation

/// Imperial accessors over the canonical metric storage (kilograms / centimeters).
///
/// All persistence and calculations use metric; views converting for display or
/// input must go through these accessors instead of hand-rolled constants.
extension UserProfile {
    var weightInPounds: Double {
        get { Measurement(value: weight, unit: UnitMass.kilograms).converted(to: .pounds).value }
        set { weight = Measurement(value: newValue, unit: UnitMass.pounds).converted(to: .kilograms).value }
    }

    var heightInInches: Double {
        get { Measurement(value: height, unit: UnitLength.centimeters).converted(to: .inches).value }
        set { height = Measurement(value: newValue, unit: UnitLength.inches).converted(to: .centimeters).value }
    }
}
