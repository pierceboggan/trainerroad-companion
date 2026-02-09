import Foundation

final class TrainerRoadService {

    private let username: String
    private let session: URLSession

    init(username: String = "pierceboggan") {
        self.username = username
        self.session = URLSession.shared
    }

    // MARK: - Fetch

    func fetchTSSData() async throws -> [DayEntry] {
        guard let url = URL(string: "https://www.trainerroad.com/app/api/tss/\(username)") else {
            throw ServiceError.invalidURL
        }

        let (data, response) = try await session.data(from: url)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw ServiceError.badResponse
        }

        let decoded = try JSONDecoder().decode(TSSResponse.self, from: data)
        return decoded.tssByDay.flatMap { $0 }
    }

    // MARK: - Queries

    func todayEntry(from entries: [DayEntry]) -> DayEntry? {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return entries.first { entry in
            guard let d = entry.parsedDate else { return false }
            return cal.isDate(d, inSameDayAs: today)
        }
    }

    func currentWeekEntries(from entries: [DayEntry]) -> [DayEntry] {
        let cal = Calendar.current
        guard let interval = cal.dateInterval(of: .weekOfYear, for: Date()) else { return [] }
        return entries
            .filter { entry in
                guard let d = entry.parsedDate else { return false }
                return interval.contains(d)
            }
            .sorted { ($0.parsedDate ?? .distantPast) < ($1.parsedDate ?? .distantPast) }
    }

    /// Returns the 7 most recent entries if no data exists for the current week.
    func latestWeekEntries(from entries: [DayEntry]) -> [DayEntry] {
        let sorted = entries
            .compactMap { entry -> (DayEntry, Date)? in
                guard let d = entry.parsedDate else { return nil }
                return (entry, d)
            }
            .sorted { $0.1 > $1.1 }

        return Array(sorted.prefix(7).reversed().map(\.0))
    }

    // MARK: - Performance Metrics

    struct PerformanceStats {
        let ctl: Double  // Chronic Training Load (fitness) — 42-day exponential avg
        let atl: Double  // Acute Training Load (fatigue)  — 7-day exponential avg
        let tsb: Double  // Training Stress Balance (form)  = CTL - ATL
    }

    /// Compute CTL / ATL / TSB from the full history using exponentially weighted moving averages.
    func performanceStats(from entries: [DayEntry]) -> PerformanceStats {
        let sorted = entries
            .compactMap { e -> (Date, Double)? in
                guard let d = e.parsedDate else { return nil }
                return (d, e.actualRideTss)
            }
            .sorted { $0.0 < $1.0 }

        guard !sorted.isEmpty else {
            return PerformanceStats(ctl: 0, atl: 0, tsb: 0)
        }

        var ctl: Double = 0
        var atl: Double = 0
        let ctlDecay = 1.0 / 42.0
        let atlDecay = 1.0 / 7.0

        for (_, tss) in sorted {
            // Use only actual recorded ride TSS for load calculations
            ctl = ctl + (tss - ctl) * ctlDecay
            atl = atl + (tss - atl) * atlDecay
        }

        return PerformanceStats(ctl: ctl, atl: atl, tsb: ctl - atl)
    }

    /// Count of consecutive recent days with completed rides (ending at yesterday or today).
    func currentStreak(from entries: [DayEntry]) -> Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        let byDate: [Date: DayEntry] = Dictionary(
            uniqueKeysWithValues: entries.compactMap { e in
                guard let d = e.parsedDate else { return nil }
                return (cal.startOfDay(for: d), e)
            }
        )

        var streak = 0
        var checkDate = today

        // Count backwards from today
        while true {
            if let entry = byDate[checkDate], entry.isCompleted {
                streak += 1
                guard let prev = cal.date(byAdding: .day, value: -1, to: checkDate) else { break }
                checkDate = prev
            } else if checkDate == today {
                // Today might not be done yet — check yesterday first
                guard let prev = cal.date(byAdding: .day, value: -1, to: checkDate) else { break }
                checkDate = prev
            } else {
                break
            }
        }

        return streak
    }

    // MARK: - Errors

    enum ServiceError: LocalizedError {
        case invalidURL
        case badResponse

        var errorDescription: String? {
            switch self {
            case .invalidURL: return "Invalid TrainerRoad API URL"
            case .badResponse: return "Bad response from TrainerRoad"
            }
        }
    }
}
