import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Properties

    private var statusItem: NSStatusItem!
    private let service = TrainerRoadService()
    private var refreshTimer: Timer?
    private var lastRefresh: Date?
    private var allEntries: [DayEntry] = []

    // MARK: - Formatters

    private let dayHeaderFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f
    }()

    private let dayNameFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f
    }()

    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            if let img = NSImage(systemSymbolName: "bicycle", accessibilityDescription: "TrainerRoad") {
                button.image = img
            } else {
                button.title = "🚴"
            }
        }

        setLoadingMenu()
        refreshData()

        // Auto-refresh every 15 minutes
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 900, repeats: true) { [weak self] _ in
            self?.refreshData()
        }
    }

    // MARK: - Data

    private func refreshData() {
        Task {
            do {
                let entries = try await service.fetchTSSData()
                await MainActor.run {
                    allEntries = entries
                    buildMenu(from: entries)
                }
            } catch {
                await MainActor.run { buildErrorMenu(error) }
            }
        }
    }

    // MARK: - Menu builders

    private func setLoadingMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Loading…", action: nil, keyEquivalent: ""))
        menu.addItem(.separator())
        addFooter(to: menu)
        statusItem.menu = menu
    }

    private func buildMenu(from entries: [DayEntry]) {
        let menu = NSMenu()
        let cal = Calendar.current
        let today = Date()

        // ── Header (clickable → opens TR calendar) ──
        let header = NSMenuItem(title: "TrainerRoad", action: #selector(openTrainerRoadCalendar), keyEquivalent: "")
        header.target = self
        header.attributedTitle = NSAttributedString(
            string: "TrainerRoad",
            attributes: [.font: NSFont.systemFont(ofSize: 13, weight: .semibold)]
        )
        menu.addItem(header)
        menu.addItem(.separator())

        // ── Today ──
        let todayLabel = "📅  Today — \(dayHeaderFormatter.string(from: today))"
        addSectionTitle(todayLabel, size: 12, to: menu)

        if let entry = service.todayEntry(from: entries) {
            addTodayDetails(entry, to: menu)
        } else {
            addDetail("   No data for today", to: menu)
        }

        menu.addItem(.separator())

        // ── Week ──
        var weekEntries = service.currentWeekEntries(from: entries)
        var weekLabel = "📋  This Week"

        if weekEntries.isEmpty {
            weekEntries = service.latestWeekEntries(from: entries)
            if let first = weekEntries.first?.parsedDate {
                let wf = DateFormatter()
                wf.dateFormat = "MMM d"
                weekLabel = "📋  Latest Week (from \(wf.string(from: first)))"
            }
        }

        addSectionTitle(weekLabel, size: 12, to: menu)

        if weekEntries.isEmpty {
            addDetail("   No weekly data available", to: menu)
        } else {
            addWeekRows(weekEntries, calendar: cal, today: today, to: menu)
        }

        // ── Weekly totals + progress bar ──
        let totalPlanned = weekEntries.reduce(0) { $0 + $1.totalPlannedTss }
        let totalActual  = weekEntries.reduce(0) { $0 + $1.actualRideTss }
        menu.addItem(.separator())
        addDetail("   Week Total:  \(Int(totalActual)) / \(Int(totalPlanned)) TSS", to: menu)
        if totalPlanned > 0 {
            let pct = min(totalActual / totalPlanned, 1.0)
            let filled = Int(pct * 20)
            let bar = String(repeating: "▓", count: filled) + String(repeating: "░", count: 20 - filled)
            addDetail("   [\(bar)] \(Int(pct * 100))%", to: menu)
        }

        // ── Compliance ──
        let planned = weekEntries.filter { $0.totalPlannedTss > 0 }
        let completed = planned.filter { $0.isCompleted }
        if !planned.isEmpty {
            addDetail("   Compliance:  \(completed.count)/\(planned.count) workouts done", to: menu)
        }

        menu.addItem(.separator())

        // ── Fitness / Fatigue / Form ──
        let stats = service.performanceStats(from: entries)
        addSectionTitle("💪  Training Load", size: 12, to: menu)
        addDetail("   Fitness (CTL):   \(Int(stats.ctl))", to: menu)
        addDetail("   Fatigue (ATL):   \(Int(stats.atl))", to: menu)
        let tsbSign = stats.tsb >= 0 ? "+" : ""
        let tsbEmoji = stats.tsb > 10 ? "🟢 Fresh" : stats.tsb > -10 ? "🟡 Neutral" : "🔴 Tired"
        addDetail("   Form (TSB):      \(tsbSign)\(Int(stats.tsb))  \(tsbEmoji)", to: menu)

        // ── Streak ──
        let streak = service.currentStreak(from: entries)
        if streak > 0 {
            addDetail("   Streak:          \(streak) day\(streak == 1 ? "" : "s") 🔥", to: menu)
        }

        menu.addItem(.separator())

        // ── Open links ──
        let openCalendar = NSMenuItem(title: "Open TrainerRoad Calendar", action: #selector(openTrainerRoadCalendar), keyEquivalent: "o")
        openCalendar.target = self
        menu.addItem(openCalendar)

        let openCareer = NSMenuItem(title: "Open Career", action: #selector(openTrainerRoadCareer), keyEquivalent: "")
        openCareer.target = self
        menu.addItem(openCareer)

        menu.addItem(.separator())
        addFooter(to: menu)
        statusItem.menu = menu
        lastRefresh = Date()
    }

    private func buildErrorMenu(_ error: Error) {
        let menu = NSMenu()
        addSectionTitle("⚠️  Error", size: 12, to: menu)
        addDetail("   \(error.localizedDescription)", to: menu)
        menu.addItem(.separator())
        addFooter(to: menu)
        statusItem.menu = menu
    }

    // MARK: - Menu helpers

    private func addTodayDetails(_ entry: DayEntry, to menu: NSMenu) {
        let planned = entry.totalPlannedTss
        let actual  = entry.actualRideTss

        if entry.isRestDay {
            addDetail("   Rest Day 🛌", to: menu)
            return
        }

        addDetail("   Planned TSS:     \(Int(planned))", to: menu)

        if entry.isCompleted {
            addDetail("   Completed TSS:   \(Int(actual))", to: menu)
            addDetail("   Status:  ✅ Completed", to: menu)
        } else if planned > 0 {
            addDetail("   Status:  ⏳ Pending", to: menu)
        }
    }

    private func addWeekRows(_ entries: [DayEntry], calendar cal: Calendar, today: Date, to menu: NSMenu) {
        guard let weekStart = cal.dateInterval(of: .weekOfYear, for: entries.first?.parsedDate ?? today)?.start else { return }

        let entryByDay: [Int: DayEntry] = Dictionary(
            uniqueKeysWithValues: entries.compactMap { e in
                guard let d = e.parsedDate else { return nil }
                return (cal.component(.day, from: d), e)
            }
        )

        for offset in 0..<7 {
            guard let day = cal.date(byAdding: .day, value: offset, to: weekStart) else { continue }
            let dayComp = cal.component(.day, from: day)
            let isToday = cal.isDateInToday(day)

            let dayName = dayNameFormatter.string(from: day)
            let dayNum  = cal.component(.day, from: day)
            let col1    = String(format: "%@ %2d", dayName, dayNum)  // "Mon  8" or "Wed 11" — always 6 chars

            var col2 = ""

            if let entry = entryByDay[dayComp] {
                let planned = entry.totalPlannedTss
                let actual  = entry.actualRideTss

                if entry.isRestDay {
                    col2 = "Rest Day"
                } else if entry.isCompleted {
                    col2 = "\(Int(actual)) TSS  ✓"
                } else if planned > 0 {
                    col2 = "\(Int(planned)) TSS planned"
                } else {
                    col2 = "—"
                }
            } else {
                col2 = "—"
            }

            var line = "   \(col1)   \(col2)"
            if isToday { line += "  ◀ today" }

            let item = makeDetailItem(line)
            if isToday {
                item.attributedTitle = NSAttributedString(
                    string: line,
                    attributes: [
                        .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .bold),
                        .foregroundColor: NSColor.labelColor
                    ]
                )
            }
            menu.addItem(item)
        }
    }

    // MARK: - Item factories

    /// No-op selector so info items render as enabled (full opacity).
    @objc private func noop() {}

    private func addSectionTitle(_ text: String, size: CGFloat, to menu: NSMenu) {
        let item = NSMenuItem(title: text, action: #selector(noop), keyEquivalent: "")
        item.target = self
        item.attributedTitle = NSAttributedString(
            string: text,
            attributes: [
                .font: NSFont.systemFont(ofSize: size, weight: .semibold),
                .foregroundColor: NSColor.labelColor
            ]
        )
        menu.addItem(item)
    }

    private func addDetail(_ text: String, to menu: NSMenu) {
        menu.addItem(makeDetailItem(text))
    }

    private func makeDetailItem(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: #selector(noop), keyEquivalent: "")
        item.target = self
        item.attributedTitle = NSAttributedString(
            string: title,
            attributes: [
                .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular),
                .foregroundColor: NSColor.labelColor
            ]
        )
        return item
    }

    private func addFooter(to menu: NSMenu) {
        let refresh = NSMenuItem(title: "↻ Refresh", action: #selector(handleRefresh), keyEquivalent: "r")
        refresh.target = self
        menu.addItem(refresh)

        if let t = lastRefresh {
            addDetail("   Updated \(timeFormatter.string(from: t))", to: menu)
        }

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit", action: #selector(handleQuit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
    }

    // MARK: - Actions

    @objc private func handleRefresh() {
        setLoadingMenu()
        refreshData()
    }

    @objc private func openTrainerRoadCalendar() {
        if let url = URL(string: "https://www.trainerroad.com/app/calendar") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func openTrainerRoadCareer() {
        if let url = URL(string: "https://www.trainerroad.com/app/career/pierceboggan") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func handleQuit() {
        NSApp.terminate(nil)
    }
}
