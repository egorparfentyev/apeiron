import SwiftUI
import UniformTypeIdentifiers
import UserNotifications

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}
struct SettingsView: View {
    @Environment(Store.self) private var store
    @State private var exporting = false
    @State private var importing = false
    @State private var backup: BackupDocument?
    @State private var incoming: Data?
    @State private var confirmImport = false
    @State private var notificationStatus = ""
    @State private var reminderTime = Calendar.current.date(from: DateComponents(hour: 21, minute: 0))!
    @State private var addingHabit = false
    var body: some View {
        Form {
            Section("Вектор · iOS 26+") {
                Text("Личные цели, действия и привычки в одном месте.")
                Text("Данные хранятся на устройстве. Нет аккаунта, сервера, облачной синхронизации или фонового наблюдения. Анализ слов работает локально.").font(.caption).foregroundStyle(.secondary)
                if store.locked { Label("Хранилище заблокировано до восстановления", systemImage: "lock.trianglebadge.exclamationmark").foregroundStyle(.orange) }
            }
            Section("Напоминание о маленьком шаге") {
                DatePicker("Время", selection: $reminderTime, displayedComponents: .hourAndMinute)
                Button("Включить ежедневное напоминание") { Task { await setReminder() } }
                Button("Отключить напоминание") { UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["vector.daily"]); notificationStatus = "Напоминание отключено" }
                if !notificationStatus.isEmpty { Text(notificationStatus).font(.caption) }
            }
            Section("Привычки") {
                ForEach(store.state.habits) { h in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(h.title).font(.headline)
                        Text(h.minimum).font(.caption).foregroundStyle(.secondary)
                        if h.archived { Text("Завершена; история сохранена").font(.caption) }
                        else { Button("Завершить с завтрашнего дня") { store.change { s in if let i = s.habits.firstIndex(where: { $0.id == h.id }) { s.habits[i].archived = true; s.habits[i].archiveDay = Day.key(Day.shifted(.now, by: 1)) } } }.font(.caption) }
                    }
                }
                Button("Добавить привычку") { addingHabit = true }
                Text("Для нового расписания завершите прежнюю привычку и создайте новую: история останется неизменной.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Резервная копия") {
                Button("Экспортировать все данные") {
                    do { backup = BackupDocument(data: try Persistence.encode(store.state)); exporting = true }
                    catch { store.error = error.localizedDescription }
                }.disabled(store.locked)
                Button("Восстановить из файла JSON") { importing = true }
                Text("Импорт заменяет текущие данные после подтверждения. Предыдущая версия дополнительно сохраняется внутри приложения.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Как считается прогресс") {
                Text("Ключевые слова предлагают направление дела. Вы подтверждаете привязку и статус. Заметки не добавляют баллы; этапы целей отмечаются вручную. Приложение не оценивает вашу личность и не выводит уровень владения навыком из частоты слов.")
            }
            Section("Каталог возможностей") { Text("Проверка: 28.10.2026. Обновляйте сведения по официальным ссылкам. Автоматическое получение новых событий в эту версию не входит.") }
        }.navigationTitle("Настройки")
            .sheet(isPresented: $addingHabit) { HabitEditor() }
            .fileExporter(isPresented: $exporting, document: backup, contentType: .json, defaultFilename: "Vector-\(Day.key(.now))") { result in if case .failure(let error) = result { store.error = error.localizedDescription } }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
                do {
                    let url = try result.get(); let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }
                    let data = try Data(contentsOf: url)
                    _ = try Persistence.decode(data)
                    incoming = data; confirmImport = true
                } catch { store.error = "Не удалось прочитать копию: \(error.localizedDescription)" }
            }
            .confirmationDialog("Заменить все текущие данные этой резервной копией?", isPresented: $confirmImport, titleVisibility: .visible) {
                Button("Восстановить", role: .destructive) { if let incoming { store.restore(incoming) }; incoming = nil }
                Button("Отмена", role: .cancel) { incoming = nil }
            }
    }
    @MainActor private func setReminder() async {
        do {
            let center = UNUserNotificationCenter.current()
            guard try await center.requestAuthorization(options: [.alert, .sound]) else { notificationStatus = "Уведомления не разрешены. Доступ можно изменить в настройках iPhone."; return }
            let content = UNMutableNotificationContent(); content.title = "Один маленький шаг"; content.body = "Как прошёл день? Отметьте сделанное и выберите посильный шаг на завтра."; content.sound = .default
            let components = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            try await center.add(UNNotificationRequest(identifier: "vector.daily", content: content, trigger: trigger))
            notificationStatus = "Напоминание включено на \(reminderTime.formatted(date: .omitted, time: .shortened))"
        } catch { notificationStatus = "Не удалось включить: \(error.localizedDescription)" }
    }
}
