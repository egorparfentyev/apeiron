import SwiftUI
import Charts

struct ProgressScreen: View {
    @Environment(Store.self) private var store
    @State private var period = 7
    var start: Date { Day.shifted(Calendar.current.startOfDay(for: .now), by: -(period - 1)) }
    var tasks: [DayTask] { store.state.tasks.filter { $0.day >= Day.key(start) && $0.day <= Day.key(.now) } }
    var body: some View {
        Screen {
            Eyebrow(text: "Замечать движение")
            Text("Вы уже в пути").font(.largeTitle.bold())
            Picker("Период", selection: $period) { Text("7 дней").tag(7); Text("30 дней").tag(30) }.pickerStyle(.segmented)
            Card {
                VStack(alignment: .leading, spacing: 14) {
                    Text("\(tasks.filter { $0.mark == .done }.count)").font(.system(size: 64, weight: .bold, design: .rounded)).foregroundStyle(.mint)
                    Text("выполненных дел за \(period) дней").font(.headline)
                    Text("\(tasks.filter { $0.mark == .missed }.count) не сделано · \(tasks.filter { $0.mark == .planned }.count) без результата").font(.caption).foregroundStyle(.secondary)
                    Chart(0..<period, id: \.self) { offset in
                        let date = Day.shifted(start, by: offset)
                        let count = tasks.filter { $0.day == Day.key(date) && $0.mark == .done }.count
                        BarMark(x: .value("День", date, unit: .day), y: .value("Сделано", count)).foregroundStyle(.mint.gradient).cornerRadius(4)
                    }.frame(height: 150).chartYAxis { AxisMarks(values: .automatic(desiredCount: 3)) }.accessibilityLabel("Дела по дням за выбранный период")
                }
            }
            Text("Куда направлена энергия").font(.title2.bold())
            ForEach(Area.allCases) { area in
                let count = Analyzer.completed(store.state, area: area, from: start, through: .now)
                Card {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack { AreaLabel(area: area); Spacer(); Text("\(count)").font(.title2.bold()) }
                        Text(advice(area: area, count: count)).font(.subheadline).foregroundStyle(.secondary)
                    }
                }
            }
            Card { VStack(alignment: .leading, spacing: 12) { Text("Еженедельный обзор · 10 минут").font(.headline); Text("1. Какой результат могу показать?\n2. Что помогало, а что мешало?\n3. Какую нагрузку выдержу на следующей неделе?\n4. Какое одно действие приближает важную цель?"); Text("Выполненное дело — факт действия. Освоенный навык или готовый проект подтверждайте этапами в целях.").font(.caption).foregroundStyle(.secondary) } }
        }.navigationTitle("Прогресс").navigationBarTitleDisplayMode(.inline)
    }
    func advice(area: Area, count: Int) -> String {
        if count == 0 { return "За этот период нет отмеченных дел по направлению. Если оно сейчас важно, добавьте один небольшой шаг. Если нет — пауза допустима." }
        switch area {
        case .english: return "Практика есть. Раз в месяц запишите один и тот же рассказ о своём проекте: сравните паузы и понятность речи."
        case .physics: return "Сохраните конкретный результат: конспект, график, расчёт или вопрос научному руководителю."
        case .data: return "Проверьте воспроизводимость: baseline, отдельная тестовая выборка, метрика и README проекта."
        case .career: return "Зафиксируйте договорённость с наставником и следующий срок. Количество писем само по себе не равно результату."
        case .travel: return "Свяжите следующий шаг с бюджетом и учебным календарём. Условия поездки проверяйте перед оплатой."
        case .people: return "Продолжите один содержательный разговор. Лучше узнавать людей постепенно, без гонки за количеством контактов."
        case .startup: return "Проверьте, что изменилось для клиента: получен отзыв, протестирован спрос или выполнен оплаченный заказ."
        }
    }
}
struct GuideView: View {
    @Environment(Store.self) private var store
    var body: some View {
        Screen {
            Eyebrow(text: "Поддержка без гонки")
            Text("Ваша опора").font(.largeTitle.bold())
            Card { VStack(alignment: .leading, spacing: 12) { Image(systemName: "leaf").font(.largeTitle).foregroundStyle(.mint); Text("Не нужно становиться\nидеальным за неделю.").font(.title2.bold()); Text("Устойчивый ритм начинается с посильного шага. Пропуск — информация о нагрузке, а не оценка вас.").foregroundStyle(.secondary) } }
            Card { VStack(alignment: .leading, spacing: 12) { Text("Ваш стартовый режим").font(.headline); Text("3-й курс МФТИ · английский B1\nЧтение увереннее, чем разговорная речь."); Text("В учебные дни: 2–5 минут речи. В свободные окна: 15–25 минут исследования или кода. Один содержательный контакт в неделю. Это предложение, а не обязательная норма.").foregroundStyle(.secondary) } }
            Text("Идеи, которые можно применять").font(.title2.bold())
            ForEach(Reading.all) { book in
                Card {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(book.author.uppercased()).font(.caption2.bold()).tracking(1).foregroundStyle(.secondary)
                        Text(book.title).font(.title3.bold())
                        Text(book.idea)
                        Text(book.practice).font(.subheadline).padding(12).frame(maxWidth: .infinity, alignment: .leading).background(.mint.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
                        Link("Источник и подробнее ↗", destination: URL(string: book.url)!).font(.caption)
                    }
                }
            }
            Text("Краткий синтез опубликованных материалов авторов и издателей. Это не замена полным книгам и не обещание гарантированного успеха.").font(.caption).foregroundStyle(.secondary)
            NavigationLink("Настройки и резервная копия") { SettingsView() }
        }.navigationTitle("Опора").navigationBarTitleDisplayMode(.inline)
    }
}
