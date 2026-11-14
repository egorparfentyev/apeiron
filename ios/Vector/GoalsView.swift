import SwiftUI

struct GoalsView: View {
    @Environment(Store.self) private var store
    @State private var horizon = Horizon.half
    @State private var adding = false
    var body: some View {
        Screen {
            Eyebrow(text: "От намерения к результату")
            Text("Ваш горизонт").font(.largeTitle.bold())
            Text("Цель задаёт направление. Маленькие действия помогают двигаться.").foregroundStyle(.secondary)
            Picker("Горизонт", selection: $horizon) { ForEach(Horizon.allCases, id: \.self) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented)
            ForEach(store.state.goals.filter { $0.horizon == horizon }) { goal in
                NavigationLink { GoalDetail(id: goal.id) } label: {
                    Card {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack { AreaLabel(area: goal.area); Spacer(); Image(systemName: "arrow.up.right").foregroundStyle(.secondary) }
                            Text(goal.title).font(.title2.bold()).foregroundStyle(.primary)
                            Text(goal.why).font(.subheadline).foregroundStyle(.secondary)
                            ProgressView(value: goal.progress).tint(goal.area.color)
                            HStack { Text("\(goal.milestones.filter(\.done).count) / \(goal.milestones.count) этапов"); Spacer(); Text(goal.due, format: .dateTime.day().month().year()) }.font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }.buttonStyle(.plain)
            }
            Text("Сроки и этапы — стартовый ориентир. Настройте их под расписание и пересматривайте каждый месяц.").font(.caption).foregroundStyle(.secondary)
        }.navigationTitle("Цели").navigationBarTitleDisplayMode(.inline)
            .toolbar { Button { adding = true } label: { Image(systemName: "plus") }.accessibilityLabel("Новая цель") }
            .sheet(isPresented: $adding) { GoalEditor() }
    }
}
struct GoalDetail: View {
    @Environment(Store.self) private var store
    var id: UUID
    @State private var editing = false
    @State private var nextStep = ""
    @State private var added = false
    var goal: Goal? { store.state.goals.first { $0.id == id } }
    var body: some View {
        Screen {
            if let goal {
                AreaLabel(area: goal.area)
                Text(goal.title).font(.largeTitle.bold())
                Card { VStack(alignment: .leading, spacing: 12) { Eyebrow(text: "Зачем мне это"); Text(goal.why); ProgressView(value: goal.progress).tint(goal.area.color); Text("\(Int(goal.progress * 100))% этапов подтверждено вами").font(.caption).foregroundStyle(.secondary) } }
                Text("Что будет результатом").font(.title2.bold())
                ForEach(goal.milestones) { milestone in
                    Button {
                        store.change { s in
                            if let i = s.goals.firstIndex(where: { $0.id == id }), let j = s.goals[i].milestones.firstIndex(where: { $0.id == milestone.id }) { s.goals[i].milestones[j].done.toggle() }
                        }
                    } label: { Card { HStack { Image(systemName: milestone.done ? "checkmark.circle.fill" : "circle").foregroundStyle(goal.area.color); Text(milestone.title).foregroundStyle(.primary); Spacer() } } }.buttonStyle(.plain)
                        .accessibilityLabel("\(milestone.title). \(milestone.done ? "Достигнуто" : "Не достигнуто"). Изменить")
                }
                Card { VStack(alignment: .leading, spacing: 10) { Eyebrow(text: "Если будет трудно"); Text(goal.obstacle).font(.headline); Text(goal.plan).foregroundStyle(.secondary) } }
                Card {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Следующее действие").font(.headline)
                        TextField("Что можно сделать за 15 минут?", text: $nextStep, axis: .vertical)
                        Button(added ? "Добавлено на сегодня" : "В план на сегодня") {
                            store.change { $0.tasks.append(DayTask(title: nextStep.trimmingCharacters(in: .whitespacesAndNewlines), day: Day.key(.now), minutes: 15, area: goal.area, goalID: goal.id)) }
                            if store.error == nil { added = true; nextStep = "" }
                        }.disabled(nextStep.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                let count = store.state.tasks.filter { $0.goalID == id && $0.mark == .done }.count
                Text("\(count) выполненных дел связано с этой целью. Этапы отмечаются отдельно, когда есть результат.").font(.caption).foregroundStyle(.secondary)
            }
        }.navigationTitle("Траектория").navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Изменить") { editing = true } }
            .sheet(isPresented: $editing) { if let goal { GoalEditor(existing: goal) } }
    }
}
struct GoalEditor: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    var existing: Goal?
    @State private var title = ""
    @State private var why = ""
    @State private var obstacle = ""
    @State private var plan = ""
    @State private var due = Calendar.current.date(byAdding: .month, value: 6, to: .now)!
    @State private var area = Area.physics
    @State private var horizon = Horizon.half
    @State private var steps: [Milestone] = []
    @State private var newStep = ""
    var body: some View {
        NavigationStack {
            Form {
                Section("Направление") {
                    TextField("Цель", text: $title, axis: .vertical)
                    Picker("Область", selection: $area) { ForEach(Area.allCases) { Text($0.rawValue).tag($0) } }
                    Picker("Горизонт", selection: $horizon) { ForEach(Horizon.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
                    DatePicker("Ориентир по сроку", selection: $due, displayedComponents: .date)
                    TextField("Почему это важно мне", text: $why, axis: .vertical)
                }
                Section("План на трудный день · WOOP") { TextField("Главное препятствие", text: $obstacle, axis: .vertical); TextField("Если…, то я…", text: $plan, axis: .vertical) }
                Section("Проверяемые этапы") {
                    ForEach($steps) { $step in TextField("Результат этапа", text: $step.title, axis: .vertical) }.onDelete { steps.remove(atOffsets: $0) }
                    HStack { TextField("Новый этап", text: $newStep); Button { steps.append(Milestone(title: newStep.trimmingCharacters(in: .whitespacesAndNewlines))); newStep = "" } label: { Image(systemName: "plus.circle.fill") }.disabled(newStep.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
                }
            }.navigationTitle(existing == nil ? "Новая цель" : "Настроить цель").toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Сохранить") {
                    var finalSteps = steps.filter { !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                    if !newStep.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { finalSteps.append(Milestone(title: newStep)) }
                    let g = Goal(id: existing?.id ?? UUID(), title: title, area: area, horizon: horizon, due: due, why: why, obstacle: obstacle, plan: plan, milestones: finalSteps)
                    store.change { s in if let i = s.goals.firstIndex(where: { $0.id == g.id }) { s.goals[i] = g } else { s.goals.append(g) } }
                    if store.error == nil { dismiss() }
                }.disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
            }.onAppear { if let g = existing { title = g.title; why = g.why; obstacle = g.obstacle; plan = g.plan; due = g.due; area = g.area; horizon = g.horizon; steps = g.milestones } }
        }
    }
}
