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
    @AppStorage("apeiron.morning") private var morning = false
    @AppStorage("apeiron.evening") private var evening = false
    var body: some View {
        Form {
            Section("Кайрос · iOS 26+") {
                Text("Личные цели и дела в одном месте.")
                Text("Данные хранятся на устройстве. Нет аккаунта, сервера, облачной синхронизации или фонового наблюдения. Анализ слов работает локально.").font(.caption).foregroundStyle(.secondary)
                if store.locked { Label("Хранилище заблокировано до восстановления", systemImage: "lock.trianglebadge.exclamationmark").foregroundStyle(.orange) }
            }
            Section("Уведомления") {
                reminder("09:00 · Составить план дня", enabled: $morning)
                reminder("21:00 · Незавершённые дела дня", enabled: $evening)
                if !notificationStatus.isEmpty { Text(notificationStatus).font(.caption) }
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
            .fileExporter(isPresented: $exporting, document: backup, contentType: .json, defaultFilename: "Kairos-\(Day.key(.now))") { result in if case .failure(let error) = result { store.error = error.localizedDescription } }
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
    private func reminder(_ label: String, enabled: Binding<Bool>) -> some View {
        Toggle(label, isOn: Binding(get: { enabled.wrappedValue }, set: { value in
            Task { @MainActor in
                do {
                    if value {
                        guard try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) else {
                            notificationStatus = "Разрешите уведомления в настройках iPhone."; return
                        }
                    }
                    enabled.wrappedValue = value
                    notificationStatus = ""
                    store.refreshReminders()
                } catch { notificationStatus = error.localizedDescription }
            }
        }))
    }
}
