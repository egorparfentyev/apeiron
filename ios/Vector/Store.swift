import Foundation
import Observation
#if os(iOS)
import UserNotifications
#endif

@MainActor @Observable final class Store {
    private(set) var state: AppState
    var error: String?
    private(set) var locked = false
    let file: URL
    init(file: URL? = nil) {
        self.file = file ?? URL.applicationSupportDirectory.appending(path: "Vector/state.json")
        if FileManager.default.fileExists(atPath: self.file.path) {
            do { state = try Persistence.decode(Data(contentsOf: self.file)) }
            catch { state = Seed.make(); self.error = "Не удалось прочитать сохранённые данные. Исходный файл сохранён. Изменения заблокированы; восстановите резервную копию в настройках."; locked = true }
        } else {
            state = Seed.make()
            do { try Self.write(state, to: self.file) }
            catch { self.error = "Не удалось создать хранилище: \(error.localizedDescription)"; locked = true }
        }
    }
    private static func write(_ state: AppState, to file: URL) throws {
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Persistence.encode(state).write(to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
    func change(_ edit: (inout AppState) -> Void) {
        guard !locked else { error = "Хранилище заблокировано. Восстановите резервную копию в настройках."; return }
        var next = state; edit(&next)
        do { try Self.write(next, to: file); state = next; refreshReminders() }
        catch { self.error = "Изменение не сохранено: \(error.localizedDescription)" }
    }
    func restore(_ data: Data) {
        do {
            let next = try Persistence.decode(data)
            if FileManager.default.fileExists(atPath: file.path) {
                let backup = file.deletingLastPathComponent().appending(path: "before-import-\(UUID().uuidString).json")
                try FileManager.default.copyItem(at: file, to: backup)
            }
            try Self.write(next, to: file); state = next; locked = false; refreshReminders()
        } catch { self.error = "Копия не восстановлена: \(error.localizedDescription). Текущие данные сохранены." }
    }
    #if os(iOS)
    private var reminderUpdate: Task<Void, Never>?
    #endif
    func refreshReminders() {
        #if os(iOS)
        guard !locked else { return }
        let previous = reminderUpdate
        previous?.cancel()
        reminderUpdate = Task {
            await previous?.value
            guard !Task.isCancelled else { return }
            let center = UNUserNotificationCenter.current()
            let prefix = "apeiron.reminder."
            let pending = await center.pendingNotificationRequests()
            guard !Task.isCancelled else { return }
            let obsolete = pending.map(\.identifier).filter { $0.hasPrefix(prefix) || $0 == "vector.daily" }
            center.removePendingNotificationRequests(withIdentifiers: obsolete)
            func add(_ id: String, _ body: String, _ components: DateComponents, repeats: Bool) async throws {
                let content = UNMutableNotificationContent()
                content.title = "Кайрос"; content.body = body; content.sound = .default
                try await center.add(UNNotificationRequest(identifier: prefix + id, content: content,
                    trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: repeats)))
            }
            do {
                if UserDefaults.standard.bool(forKey: "apeiron.morning") {
                    try await add("morning", "Запишите дела на сегодня в план дня.", DateComponents(hour: 9, minute: 0), repeats: true)
                }
                guard UserDefaults.standard.bool(forKey: "apeiron.evening"), !Task.isCancelled else { return }
                let now = Date(), calendar = Calendar.current
                let planned = Dictionary(grouping: state.tasks.filter { $0.mark != .done && $0.day >= Day.key(now) }, by: \.day)
                for key in planned.keys.sorted().prefix(60) {
                    guard !Task.isCancelled else { return }
                    let parts = key.split(separator: "-").compactMap { Int($0) }
                    guard parts.count == 3 else { continue }
                    let time = DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 21, minute: 0)
                    guard let fire = calendar.date(from: time), fire > now else { continue }
                    try await add(key, "Незавершённых дел в плане дня: " + String(planned[key]?.count ?? 0) + ". Откройте ежедневник, чтобы закончить их.", time, repeats: false)
                }
            } catch { if !Task.isCancelled { self.error = error.localizedDescription } }
        }
        #endif
    }
    func markTask(_ id: UUID, _ mark: Mark) {
        guard let task = state.tasks.first(where: { $0.id == id }), task.day <= Day.key(.now) else { error = "Будущие дела можно планировать; результат отмечается в день выполнения."; return }
        change { s in if let i = s.tasks.firstIndex(where: { $0.id == id }) { s.tasks[i].mark = mark } }
    }
    func markHabit(_ id: UUID, day: Date, mark: Mark) {
        guard day <= Calendar.current.startOfDay(for: Day.shifted(.now, by: 1)), let habit = state.habits.first(where: { $0.id == id }), habit.scheduled(day), Day.key(day) <= Day.key(.now) else { error = "Отметка доступна только для назначенного дня, который уже наступил."; return }
        change { s in
            let key = Day.key(day)
            s.logs.removeAll { $0.habitID == id && $0.day == key }
            if mark != .planned { s.logs.append(HabitLog(habitID: id, day: key, mark: mark)) }
        }
    }
    func habitMark(_ id: UUID, day: Date) -> Mark { state.logs.first { $0.habitID == id && $0.day == Day.key(day) }?.mark ?? .planned }
    func journal(_ date: Date) -> String { state.reflections.first { $0.day == Day.key(date) }?.text ?? "" }
    func saveJournal(_ text: String, date: Date) {
        change { s in s.reflections.removeAll { $0.day == Day.key(date) }; if !text.isEmpty { s.reflections.append(Reflection(day: Day.key(date), text: text)) } }
    }
}
