import SwiftUI
import EventKit
import EventKitUI

struct CalendarView: View {
    @Environment(Store.self) private var store
    @State private var date = Date.now
    @State private var onlySaved = false
    @State private var filter = 0
    @State private var add = false
    var visible: [Opportunity] {
        store.state.events.filter { e in
            (!onlySaved || e.saved) && (filter == 2 ? e.date == nil : filter == 1 ? e.date.map { Calendar.current.isDate($0, inSameDayAs: date) || ($0 <= date && (e.end ?? $0) >= date) } ?? false : e.date.map { (e.end ?? $0) >= Calendar.current.startOfDay(for: .now) } ?? false)
        }.sorted { ($0.date ?? .distantFuture) < ($1.date ?? .distantFuture) }
    }
    var body: some View {
        Screen {
            Eyebrow(text: "Возможности для вашего пути")
            Text("За пределами\nрасписания").font(.largeTitle.bold())
            Picker("Показать", selection: $filter) { Text("Впереди").tag(0); Text("День").tag(1); Text("Без даты").tag(2) }.pickerStyle(.segmented)
            if filter == 1 { DatePicker("Выбрать дату", selection: $date, displayedComponents: .date).datePickerStyle(.graphical) }
            Toggle("Только сохранённые", isOn: $onlySaved).font(.subheadline)
            Text(filter == 2 ? "Программы для наблюдения. Здесь нет выдуманных дедлайнов: проверяйте новые наборы по официальным ссылкам." : "Каталог проверен 28 октября 2026. Автоматического обновления нет; перед подачей проверьте источник.").font(.caption).foregroundStyle(.secondary)
            if visible.isEmpty { ContentUnavailableView("Пока нет событий", systemImage: "calendar", description: Text("Выберите другую дату или добавьте своё событие.")) }
            ForEach(visible) { event in
                NavigationLink { OpportunityDetail(id: event.id) } label: {
                    Card {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack { Text(event.kind.uppercased()).font(.caption2.bold()).tracking(1).foregroundStyle(.secondary); Spacer(); if event.saved { Image(systemName: "bookmark.fill").foregroundStyle(.mint) } }
                            Text(event.title).font(.title3.bold()).foregroundStyle(.primary)
                            Text(event.timing).font(.subheadline).foregroundStyle(.secondary)
                            HStack { Text(event.date == nil ? "Ожидаем дату" : "Посмотреть детали"); Spacer(); Image(systemName: "arrow.up.right") }.font(.caption.bold()).foregroundStyle(.mint)
                        }
                    }
                }.buttonStyle(.plain)
            }
        }.navigationTitle("Календарь").navigationBarTitleDisplayMode(.inline)
            .toolbar { Button { add = true } label: { Image(systemName: "plus") }.accessibilityLabel("Добавить событие") }
            .sheet(isPresented: $add) { PersonalEventEditor() }
    }
}
struct OpportunityDetail: View {
    @Environment(Store.self) private var store
    var id: UUID
    @State private var calendar = false
    @State private var planned = false
    var event: Opportunity? { store.state.events.first { $0.id == id } }
    var body: some View {
        Screen {
            if let event {
                Eyebrow(text: event.kind)
                Text(event.title).font(.largeTitle.bold())
                Card { VStack(alignment: .leading, spacing: 12) { Label("Сроки", systemImage: "calendar").font(.headline); Text(event.timing); if let d = event.date { Text(d, format: .dateTime.day().month().year().hour().minute().timeZone()).font(.caption).foregroundStyle(.secondary) } } }
                Card { VStack(alignment: .leading, spacing: 12) { Text("Подходит ли мне?").font(.headline); Text(event.eligibility); Text("Профиль: 3-й курс МФТИ, английский B1. Допуск зависит от конкретного набора и условий принимающей стороны.").font(.caption).foregroundStyle(.secondary) } }
                Card { VStack(alignment: .leading, spacing: 12) { Text("Следующий шаг").font(.headline); Text(event.nextStep); Button(planned ? "Дело добавлено" : "Добавить подготовку на сегодня") { store.change { $0.tasks.append(DayTask(title: "\(event.title): \(event.nextStep)", day: Day.key(.now), minutes: 15, area: .career)) }; if store.error == nil { planned = true } }.disabled(planned) } }
                Button(event.saved ? "Убрать из сохранённых" : "Сохранить возможность", systemImage: event.saved ? "bookmark.fill" : "bookmark") { store.change { s in if let i = s.events.firstIndex(where: { $0.id == id }) { s.events[i].saved.toggle() } } }.buttonStyle(.bordered)
                if event.date != nil { Button("В календарь iPhone", systemImage: "calendar.badge.plus") { calendar = true }.buttonStyle(.borderedProminent).foregroundStyle(.black) }
                if let url = URL(string: event.url), ["https", "http"].contains(url.scheme ?? "") { Link("Официальный источник ↗", destination: url) }
                Text("Проверено: \(event.verified). Запись в календарь откроется для вашего подтверждения.").font(.caption).foregroundStyle(.secondary)
            }
        }.navigationTitle("Возможность").navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $calendar) { if let event { EventComposer(opportunity: event) } }
    }
}
struct EventComposer: UIViewControllerRepresentable {
    let opportunity: Opportunity
    @Environment(\.dismiss) private var dismiss
    func makeCoordinator() -> Coordinator { Coordinator { dismiss() } }
    func makeUIViewController(context: Context) -> EKEventEditViewController {
        let controller = EKEventEditViewController()
        let store = EKEventStore()
        controller.eventStore = store
        let event = EKEvent(eventStore: store)
        event.title = opportunity.title
        event.startDate = opportunity.date ?? .now
        event.endDate = opportunity.end ?? event.startDate.addingTimeInterval(1800)
        event.notes = "\(opportunity.timing)\n\(opportunity.nextStep)\nИсточник: \(opportunity.url)\nПроверено: \(opportunity.verified)"
        if let url = URL(string: opportunity.url) { event.url = url }
        controller.event = event
        controller.editViewDelegate = context.coordinator
        return controller
    }
    func updateUIViewController(_ uiViewController: EKEventEditViewController, context: Context) {}
    final class Coordinator: NSObject, EKEventEditViewDelegate {
        let close: () -> Void
        init(close: @escaping () -> Void) { self.close = close }
        func eventEditViewController(_ controller: EKEventEditViewController, didCompleteWith action: EKEventEditViewAction) { close() }
    }
}
struct PersonalEventEditor: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var date = Date.now
    @State private var note = ""
    var body: some View {
        NavigationStack {
            Form { TextField("Семинар, встреча или дедлайн", text: $title); DatePicker("Дата и время", selection: $date); TextField("Заметка", text: $note, axis: .vertical) }
                .navigationTitle("Своё событие").toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("Добавить") {
                        let e = Opportunity(title: title, kind: "Моё событие", date: date, end: date.addingTimeInterval(3600), timing: "Дата и время заданы вами", eligibility: "Личная запись", nextStep: note, url: "", verified: Day.key(.now), saved: true)
                        store.change { $0.events.append(e) }; if store.error == nil { dismiss() }
                    }.disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
                }
        }
    }
}
