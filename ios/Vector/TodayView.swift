import SwiftUI

struct TodayView: View {
    @Environment(Store.self) private var store
    @State private var date = Date.now
    @State private var addTask = false
    @State private var editingTask: DayTask?
    @State private var reflection = ""
    @State private var journalSaved = false
    var tasks: [DayTask] { store.state.tasks.filter { $0.day == Day.key(date) } }
    var body: some View {
        Screen {
            HStack { Eyebrow(text: "Вектор / ваш следующий шаг"); Spacer(); NavigationLink { SettingsView() } label: { Image(systemName: "slider.horizontal.3").frame(width: 44, height: 44) }.accessibilityLabel("Настройки и резервная копия") }
            Text("Маленькие шаги.\nБольшая траектория.").font(.largeTitle.bold()).tracking(-1)
            DatePicker("День", selection: $date, displayedComponents: .date)
            Card {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 5) {
                            Eyebrow(text: "Фокус дня")
                            Text(store.state.busy ? "Учёба — в приоритете" : "Есть место для глубины").font(.title2.bold())
                        }
                        Spacer()
                        Image(systemName: "sparkle").font(.largeTitle).foregroundStyle(.mint)
                    }
                    Text(store.state.busy ? "Один маленький шаг уже считается. Сегодня достаточно 2 минут английского или одного вопроса к статье." : "Выберите одну важную задачу и свободное окно на 25 минут. Оставьте время на восстановление.").foregroundStyle(.secondary)
                    Toggle("Загруженный день", isOn: Binding(get: { store.state.busy }, set: { busy in store.change { $0.busy = busy } }))
                    HStack { Label("\(tasks.filter { $0.mark == .done }.count) из \(tasks.count) дел", systemImage: "checkmark.circle"); Spacer(); Text("\(tasks.filter { $0.mark == .planned }.reduce(0) { $0 + $1.minutes }) мин в плане") }.font(.caption).foregroundStyle(.secondary)
                }
            }
            HStack { Text("Мой день").font(.title2.bold()); Spacer(); Button { addTask = true } label: { Label("Дело", systemImage: "plus") }.buttonStyle(.bordered) }
            if tasks.isEmpty {
                Card { VStack(alignment: .leading, spacing: 10) { Text("С чего начнём?").font(.headline); Text("Запишите одно конкретное действие. Например: «Записать 2 минуты речи на английском».").foregroundStyle(.secondary); Button("Добавить первое дело") { addTask = true } } }
            }
            ForEach(tasks) { task in
                Card {
                    HStack(alignment: .top) {
                        MarkPicker(mark: task.mark) { store.markTask(task.id, $0) }.disabled(Day.key(date) > Day.key(.now))
                        Button { editingTask = task } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(task.title).font(.headline).strikethrough(task.mark == .done).foregroundStyle(.primary)
                                if let area = task.area { AreaLabel(area: area) }
                                Text("\(task.minutes) мин · \(task.mark.rawValue)").font(.caption).foregroundStyle(.secondary)
                                if !task.note.isEmpty { Text(task.note).font(.caption).foregroundStyle(.secondary) }
                            }.frame(maxWidth: .infinity, alignment: .leading)
                        }.buttonStyle(.plain)
                    }
                }
            }
            Card {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Вечерняя заметка", systemImage: "pencil.and.outline").font(.headline)
                    Text("Что получилось? Что помешало? Какой следующий маленький шаг?").font(.subheadline).foregroundStyle(.secondary)
                    TextField("Сегодня я…", text: $reflection, axis: .vertical).lineLimit(3...8)
                    let matches = Analyzer.matches(reflection)
                    ForEach(matches) { match in Label("\(match.area.rawValue): \(match.words.joined(separator: ", "))", systemImage: match.area.icon).font(.caption).foregroundStyle(match.area.color) }
                    if !matches.isEmpty { Text("Это темы заметки, а не оценка результата. Прогресс учитывает только отмеченные дела и этапы.").font(.caption).foregroundStyle(.secondary) }
                    Button(journalSaved ? "Сохранено" : "Сохранить заметку") { store.saveJournal(reflection, date: date); journalSaved = store.error == nil }.buttonStyle(.bordered)
                }
            }
        }
        .navigationTitle("Сегодня").navigationBarTitleDisplayMode(.inline)
        .onAppear { reflection = store.journal(date) }
        .onChange(of: date) { _, _ in reflection = store.journal(date); journalSaved = false }
        .onChange(of: reflection) { _, _ in journalSaved = false }
        .sheet(isPresented: $addTask) { TaskEditor(day: date) }
        .sheet(item: $editingTask) { TaskEditor(day: date, existing: $0) }
    }
}

struct TaskEditor: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    var day: Date
    var existing: DayTask?
    @State private var title = ""
    @State private var minutes = 15
    @State private var area: Area?
    @State private var goalID: UUID?
    @State private var note = ""
    @State private var scheduled = Date.now
    @State private var confirmDelete = false
    var body: some View {
        NavigationStack {
            Form {
                Section("Одно конкретное действие") {
                    TextField("Например: разобрать статью по фотонике", text: $title, axis: .vertical)
                    DatePicker("Когда", selection: $scheduled, displayedComponents: .date)
                    Stepper("\(minutes) минут", value: $minutes, in: 0...480, step: 5)
                }
                let matches = Analyzer.matches(title)
                if !matches.isEmpty {
                    Section("Подсказки по словам · выберите подходящую") {
                        ForEach(matches) { m in Button { area = m.area } label: { VStack(alignment: .leading) { AreaLabel(area: m.area); Text("Найдено: \(m.words.joined(separator: ", "))").font(.caption).foregroundStyle(.secondary) } } }
                    }
                }
                Section("Связь с целью") {
                    Picker("Направление", selection: $area) { Text("Не выбрано").tag(nil as Area?); ForEach(Area.allCases) { Text($0.rawValue).tag(Optional($0)) } }
                    Picker("Цель", selection: $goalID) { Text("Без привязки").tag(nil as UUID?); ForEach(store.state.goals) { Text($0.title).tag(Optional($0.id)) } }
                    Text("Подсказка не меняет статус дела. Отмечайте выполнение сами.").font(.caption).foregroundStyle(.secondary)
                }
                Section("Результат или причина переноса") { TextField("Что получилось / что помешало", text: $note, axis: .vertical).lineLimit(3...6) }
                if existing != nil { Button("Удалить дело", role: .destructive) { confirmDelete = true } }
            }
            .navigationTitle(existing == nil ? "Новое дело" : "Дело")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Сохранить") {
                    let task = DayTask(id: existing?.id ?? UUID(), title: title.trimmingCharacters(in: .whitespacesAndNewlines), day: Day.key(scheduled), minutes: minutes, area: area, goalID: goalID, mark: Day.key(scheduled) > Day.key(.now) ? .planned : (existing?.mark ?? .planned), note: note)
                    store.change { s in s.tasks.removeAll { $0.id == task.id }; s.tasks.append(task) }
                    if store.error == nil { dismiss() }
                }.disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
            }
            .onAppear { scheduled = day; if let t = existing { title = t.title; minutes = t.minutes; area = t.area; goalID = t.goalID; note = t.note } }
            .onChange(of: goalID) { _, id in if let goal = store.state.goals.first(where: { $0.id == id }) { area = goal.area } }
            .confirmationDialog("Удалить дело из истории?", isPresented: $confirmDelete) { Button("Удалить", role: .destructive) { store.change { s in s.tasks.removeAll { $0.id == existing?.id } }; if store.error == nil { dismiss() } } }
        }
    }
}

