import Foundation

@main struct CoreTests {
    @MainActor static func main() throws {
        var checks = 0
        func check(_ condition: @autoclosure () -> Bool, _ name: String) {
            checks += 1
            guard condition() else { fatalError("FAIL: \(name)") }
            print("PASS: \(name)")
        }
        let now = Day.date("2026-10-28T12:00:00+03:00")
        var state = Seed.make(now: now)
        check(state.tasks.isEmpty, "No fictional achievements")
        check(state.goals.count == 10 && state.goals.allSatisfy { $0.progress == 0 }, "Personal goals start at zero")
        check(Analyzer.matches("HTML email device").isEmpty, "Short acronyms match full tokens only")
        check(Set(Analyzer.matches("Python, ML и фотоника").map(\.area)) == Set([.data, .physics]), "Mixed Russian / English matches")
        check(Analyzer.matches("ANGлийский English speaking").contains { $0.area == .english }, "English classification")
        check(Analyzer.matches("не сделал ML").first?.area == .data, "Keywords propose topic, not completion")
        let todo = DayTask(title: "не сделал ML", day: Day.key(now), minutes: 15, area: .data)
        state.tasks.append(todo)
        check(Analyzer.completed(state, area: .data, from: now, through: now) == 0, "Planned work never counts as completed")
        state.tasks[0].mark = .missed
        check(Analyzer.completed(state, area: .data, from: now, through: now) == 0, "Missed work never counts as completed")
        state.tasks[0].mark = .done
        check(Analyzer.completed(state, area: .data, from: now, through: now) == 1, "Explicit done counts once")
        check(Analyzer.completed(state, area: .data, from: Day.shifted(now, by: 1), through: Day.shifted(now, by: 2)) == 0, "Date range excludes older completions")
        var h = state.habits[0]; h.weekdays = [1,2,3,4,5,6,7]
        state.habits = [h]
        check(Analyzer.habitRate(state, from: Day.shifted(now, by: -30), through: now).planned == 1, "No denominator before habit creation")
        state.logs = [HabitLog(habitID: h.id, day: Day.key(now), mark: .rest)]
        check(Analyzer.habitRate(state, from: now, through: now).planned == 0, "Rest excluded from denominator")
        state.logs[0].mark = .done
        check(Analyzer.habitRate(state, from: now, through: now).done == 1, "Done habit counted")
        state.habits[0].archived = true; state.habits[0].archiveDay = Day.key(Day.shifted(now, by: 1))
        check(Analyzer.habitRate(state, from: now, through: Day.shifted(now, by: 10)).planned == 1, "Archiving preserves history, excludes future days")
        let bytes = try Persistence.encode(state)
        let roundtrip = try Persistence.decode(bytes)
        check(roundtrip.goals.map(\.id) == state.goals.map(\.id) && roundtrip.logs.count == 1, "Backup round trip")
        var bad = state; bad.version = 99
        check((try? Persistence.decode(Persistence.encode(bad))) == nil, "Reject unsupported backup version")
        bad = state; bad.tasks.append(bad.tasks[0])
        check((try? Persistence.decode(Persistence.encode(bad))) == nil, "Reject duplicated task IDs")
        bad = state; bad.tasks[0].goalID = UUID()
        check((try? Persistence.decode(Persistence.encode(bad))) == nil, "Reject dangling goal reference")
        bad = state; bad.logs.append(bad.logs[0])
        check((try? Persistence.decode(Persistence.encode(bad))) == nil, "Reject duplicate habit logs")
        let dir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appending(path: "state.json")
        let store = Store(file: file)
        store.change { $0 = state }
        store.markTask(todo.id, .done); store.markTask(todo.id, .done)
        check(store.state.tasks.count == 1, "Repeated completion is idempotent")
        store.markHabit(h.id, day: now, mark: .done); store.markHabit(h.id, day: now, mark: .missed)
        check(store.state.logs.count == 1 && store.state.logs[0].mark == .missed, "Changing habit status replaces old entry")
        store.markHabit(h.id, day: now, mark: .planned)
        check(store.state.logs.isEmpty, "Undo habit mark")
        store.saveJournal("Test", date: now); store.saveJournal("Changed", date: now)
        check(store.state.reflections.count == 1 && store.journal(now) == "Changed", "Journal replaces same day only")
        let reloaded = Store(file: file)
        check(reloaded.state.tasks.count == 1 && reloaded.journal(now) == "Changed", "Persistence across launch")
        store.restore(Data("broken".utf8))
        check(store.state.tasks.count == 1, "Bad import leaves current data intact")
        try Data("corrupted original".utf8).write(to: file)
        let corrupted = Store(file: file)
        corrupted.markTask(todo.id, .done)
        check(corrupted.locked && (try? String(contentsOf: file, encoding: .utf8)) == "corrupted original", "Corrupt file preserved and writes locked")
        corrupted.restore(bytes)
        check(!corrupted.locked && corrupted.state.tasks.count == 1, "Valid backup recovers locked store")
        var moscow = Calendar(identifier: .gregorian); moscow.timeZone = TimeZone(identifier: "Europe/Moscow")!
        let deadline = state.events.first { $0.title.contains("OIST") }!.date!
        check(moscow.component(.hour, from: deadline) == 17 && moscow.component(.minute, from: deadline) == 59, "JST deadline converts to Moscow correctly")
        var ny = Calendar(identifier: .gregorian); ny.timeZone = TimeZone(identifier: "America/New_York")!
        let dst = Day.date("2026-03-07T12:00:00-05:00")
        check(Day.key(Day.shifted(dst, by: 1, calendar: ny), calendar: ny) == "2026-03-08", "Calendar arithmetic across daylight saving")
        check(state.events.filter { $0.date == nil }.count == 4, "Unannounced opportunities have no invented dates")
        let tomorrow = Day.shifted(.now, by: 1)
        let futureTask = DayTask(title: "Tomorrow", day: Day.key(tomorrow), minutes: 5, area: .english)
        corrupted.change { $0.tasks.append(futureTask) }
        corrupted.markTask(futureTask.id, .done)
        check(corrupted.state.tasks.first { $0.id == futureTask.id }?.mark == .planned, "Cannot mark future task complete")
        let before = corrupted.state.logs.count
        corrupted.markHabit(h.id, day: tomorrow, mark: .done)
        check(corrupted.state.logs.count == before, "Cannot mark future habit complete")
        let failingFile = dir.appending(path: "failing.json")
        let failing = Store(file: failingFile)
        let oldCount = failing.state.tasks.count
        try FileManager.default.removeItem(at: failingFile)
        try FileManager.default.createDirectory(at: failingFile, withIntermediateDirectories: true)
        failing.change { $0.tasks.append(todo) }
        check(failing.error != nil && failing.state.tasks.count == oldCount, "Failed disk write rolls back visible state")
        print("\(checks) checks passed")
    }
}
