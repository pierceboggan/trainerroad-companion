import Foundation

// MARK: - API Response

struct TSSResponse: Codable {
    let tssByDay: [[DayEntry]]

    enum CodingKeys: String, CodingKey {
        case tssByDay = "TssByDay"
    }
}

struct DayEntry: Codable, Identifiable {
    let date: String
    let tss: Double
    let tssTrainerRoad: Double
    let tssOther: Double
    let plannedTssTrainerRoad: Double
    let plannedTssOther: Double
    let hasRides: Bool

    var id: String { date }

    enum CodingKeys: String, CodingKey {
        case date = "Date"
        case tss = "Tss"
        case tssTrainerRoad = "TssTrainerRoad"
        case tssOther = "TssOther"
        case plannedTssTrainerRoad = "PlannedTssTrainerRoad"
        case plannedTssOther = "PlannedTssOther"
        case hasRides = "HasRides"
    }

    // MARK: - Helpers

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        f.timeZone = TimeZone.current
        return f
    }()

    var parsedDate: Date? {
        Self.dateFormatter.date(from: date)
    }

    var totalPlannedTss: Double {
        plannedTssTrainerRoad + plannedTssOther
    }

    /// Actual recorded ride TSS (not including planned/scheduled).
    var actualRideTss: Double {
        tssTrainerRoad + tssOther
    }

    /// Whether the rider has actually completed a ride (recorded TSS > 0).
    var isCompleted: Bool {
        actualRideTss > 0
    }

    var isRestDay: Bool {
        totalPlannedTss == 0 && actualRideTss == 0
    }
}
