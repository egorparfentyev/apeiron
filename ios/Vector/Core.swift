import Foundation

enum Area: String, Codable, CaseIterable, Identifiable {
    case physics = "Физика и фотоника", data = "DS · CV · ML · AI", english = "Английский", career = "Лаборатория и карьера", travel = "Путешествия", people = "Знакомства", startup = "Доход и стартапы"
    var id: String { rawValue }
    var icon: String {
        switch self { case .physics: "waveform.path"; case .data: "cpu"; case .english: "bubble.left.and.bubble.right"; case .career: "flask"; case .travel: "airplane"; case .people: "person.2"; case .startup: "sparkles" }
    }
    var keywords: [String] {
        switch self {
        case .physics: ["физик", "фотон", "оптик", "квант", "physics", "photon", "лазер"]
        case .data: ["python", "pytorch", "датасет", "нейросет", "машинн", "ds", "cv", "ml", "ai", "модел", "computer vision"]
        case .english: ["англий", "english", "speaking", "ielts", "разговорн", "произнош"]
        case .career: ["лаборатор", "лабе", "лаб", "сколтех", "skoltech", "стажиров", "резюме", "oist", "gist", "kaust", "магистрат"]
        case .travel: ["таиланд", "тайланд", "коре", "билет", "поездк", "путешеств", "thailand", "korea"]
        case .people: ["знаком", "нетворк", "контакт", "ментор", "коллег", "встрет"]
        case .startup: ["стартап", "доход", "заработ", "клиент", "бюджет", "startup", "заказ", "портфолио"]
        }
    }
}
enum Mark: String, Codable, CaseIterable { case planned = "В плане", done = "Сделано", missed = "Не сделал", rest = "Отдых" }
enum Horizon: String, Codable, CaseIterable { case half = "Полгода", year = "Год", future = "5–10 лет" }
struct Milestone: Codable, Identifiable { var id = UUID(); var title: String; var done = false }
struct Goal: Codable, Identifiable {
    var id = UUID(); var title: String; var area: Area; var horizon: Horizon; var due: Date; var why: String; var obstacle: String; var plan: String; var milestones: [Milestone]
    var progress: Double { milestones.isEmpty ? 0 : Double(milestones.filter(\.done).count) / Double(milestones.count) }
}
struct DayTask: Codable, Identifiable {
    var id = UUID(); var title: String; var day: String; var minutes: Int; var area: Area?; var goalID: UUID?; var mark: Mark = .planned; var note = ""
}
struct Habit: Codable, Identifiable {
    var id = UUID(); var title: String; var minimum: String; var cue: String; var area: Area; var weekdays: [Int]; var startDay: String; var archived = false; var archiveDay: String? = nil
    func scheduled(_ date: Date, calendar: Calendar = .current) -> Bool { (archiveDay.map { Day.key(date, calendar: calendar) < $0 } ?? !archived) && Day.key(date, calendar: calendar) >= startDay && weekdays.contains(calendar.component(.weekday, from: date)) }
}
struct HabitLog: Codable { var habitID: UUID; var day: String; var mark: Mark }
struct Opportunity: Codable, Identifiable {
    var id = UUID(); var title: String; var kind: String; var date: Date?; var end: Date?; var timing: String; var eligibility: String; var nextStep: String; var url: String; var verified: String; var saved = false
}
struct Reflection: Codable { var day: String; var text: String }
struct AppState: Codable {
    var version = 1; var goals: [Goal]; var tasks: [DayTask]; var habits: [Habit]; var logs: [HabitLog] = []; var events: [Opportunity]; var reflections: [Reflection] = []; var busy = true
}
enum Day {
    static func key(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }
    static func date(_ text: String) -> Date { ISO8601DateFormatter().date(from: text)! }
    static func shifted(_ date: Date, by days: Int, calendar: Calendar = .current) -> Date { calendar.date(byAdding: .day, value: days, to: date)! }
}
struct Match: Identifiable { var area: Area; var words: [String]; var id: String { area.id } }
enum Analyzer {
    static func matches(_ text: String) -> [Match] {
        let lower = text.lowercased().replacingOccurrences(of: "ё", with: "е")
        let words = lower.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
        return Area.allCases.compactMap { area in
            let found = area.keywords.filter { key in
                if key.contains(" ") { return lower.contains(key) }
                return words.contains { key.count <= 4 ? $0 == key : $0.hasPrefix(key) }
            }
            return found.isEmpty ? nil : Match(area: area, words: found)
        }
    }
    static func completed(_ state: AppState, area: Area, from: Date, through: Date) -> Int {
        let lo = Day.key(from), hi = Day.key(through)
        return state.tasks.filter { $0.day >= lo && $0.day <= hi && $0.mark == .done && $0.area == area }.count
    }
    static func habitRate(_ state: AppState, from: Date, through: Date) -> (done: Int, planned: Int) {
        var d = Calendar.current.startOfDay(for: from); var total = 0; var done = 0
        while d <= through {
            for habit in state.habits where habit.scheduled(d) {
                let mark = state.logs.first { $0.day == Day.key(d) && $0.habitID == habit.id }?.mark
                if mark != .rest { total += 1; if mark == .done { done += 1 } }
            }
            d = Day.shifted(d, by: 1)
        }
        return (done, total)
    }
}
enum Persistence {
    static func encode(_ state: AppState) throws -> Data { let e = JSONEncoder(); e.outputFormatting = [.prettyPrinted, .sortedKeys]; return try e.encode(state) }
    static func decode(_ data: Data) throws -> AppState {
        let s = try JSONDecoder().decode(AppState.self, from: data)
        guard s.version == 1,
              Set(s.goals.map(\.id)).count == s.goals.count,
              Set(s.tasks.map(\.id)).count == s.tasks.count,
              Set(s.habits.map(\.id)).count == s.habits.count,
              Set(s.events.map(\.id)).count == s.events.count,
              Set(s.logs.map { "\($0.habitID)-\($0.day)" }).count == s.logs.count,
              s.tasks.allSatisfy({ task in task.minutes >= 0 && task.minutes <= 1440 && (task.goalID == nil || s.goals.contains(where: { g in g.id == task.goalID })) }),
              s.habits.allSatisfy({ !$0.weekdays.isEmpty && $0.weekdays.allSatisfy { (1...7).contains($0) } }),
              s.logs.allSatisfy({ log in s.habits.contains { $0.id == log.habitID } }) else { throw CocoaError(.fileReadCorruptFile) }
        return s
    }
}
