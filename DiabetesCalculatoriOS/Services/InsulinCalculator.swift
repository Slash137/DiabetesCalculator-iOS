import Foundation

enum InsulinCalculator {
    static func calculateCarbs(carbsPer100g: Double, gramsConsumed: Double) -> Double {
        guard gramsConsumed > 0, carbsPer100g >= 0 else { return 0 }
        return (carbsPer100g / 100.0) * gramsConsumed
    }

    static func calculateRations(totalCarbs: Double, gramsPerRation: Double) -> Double {
        guard gramsPerRation > 0 else { return 0 }
        return totalCarbs / gramsPerRation
    }

    static func calculateInsulin(rations: Double, insulinRatio: Double) -> Double {
        guard rations > 0, insulinRatio > 0 else { return 0 }
        let unrounded = rations * insulinRatio
        return (unrounded * 2).rounded() / 2
    }

    static func calculateAll(
        carbsPer100g: Double,
        gramsConsumed: Double,
        gramsPerRation: Double,
        insulinRatio: Double
    ) -> (carbs: Double, rations: Double, insulin: Double) {
        let carbs = calculateCarbs(carbsPer100g: carbsPer100g, gramsConsumed: gramsConsumed)
        let rations = calculateRations(totalCarbs: carbs, gramsPerRation: gramsPerRation)
        let insulin = calculateInsulin(rations: rations, insulinRatio: insulinRatio)
        return (carbs, rations, insulin)
    }
}
