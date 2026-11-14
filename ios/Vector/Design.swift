import SwiftUI

extension Area {
    var color: Color {
        switch self { case .physics: .mint; case .data: .indigo; case .english: .orange; case .career: .cyan; case .travel: .pink; case .people: .purple; case .startup: .yellow }
    }
}
struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View { content.padding(20).frame(maxWidth: .infinity, alignment: .leading).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 26)).overlay(RoundedRectangle(cornerRadius: 26).stroke(.primary.opacity(0.06))) }
}
struct Screen<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        ScrollView { VStack(alignment: .leading, spacing: 20) { content }.padding(.horizontal, 20).padding(.vertical, 12).frame(maxWidth: 720).frame(maxWidth: .infinity) }
            .background { LinearGradient(colors: [Color.mint.opacity(0.10), Color.indigo.opacity(0.06), Color(.systemBackground)], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea() }
    }
}
struct Eyebrow: View { var text: String; var body: some View { Text(text.uppercased()).font(.caption.weight(.bold)).tracking(2).foregroundStyle(.secondary) } }
struct AreaLabel: View {
    var area: Area
    var body: some View { Label(area.rawValue, systemImage: area.icon).font(.caption.weight(.medium)).foregroundStyle(area.color).padding(.horizontal, 10).padding(.vertical, 6).background(area.color.opacity(0.1), in: Capsule()) }
}
struct MarkPicker: View {
    var mark: Mark; var allowRest = false; var onChange: (Mark) -> Void
    var body: some View {
        Menu {
            ForEach(Mark.allCases.filter { allowRest || $0 != .rest }, id: \.self) { value in Button(value.rawValue) { onChange(value) } }
        } label: {
            Image(systemName: mark == .done ? "checkmark.circle.fill" : mark == .missed ? "xmark.circle" : mark == .rest ? "moon.circle" : "circle")
                .font(.title2).foregroundStyle(mark == .done ? Color.mint : Color.secondary).frame(width: 44, height: 44)
        }.accessibilityLabel("Статус: \(mark.rawValue). Изменить")
    }
}
struct RootView: View {
    var body: some View {
        TabView {
            Tab("Сегодня", systemImage: "sun.max") { NavigationStack { TodayView() } }
            Tab("Цели", systemImage: "scope") { NavigationStack { GoalsView() } }
            Tab("Календарь", systemImage: "calendar") { NavigationStack { CalendarView() } }
            Tab("Прогресс", systemImage: "chart.xyaxis.line") { NavigationStack { ProgressScreen() } }
            Tab("Опора", systemImage: "sparkles") { NavigationStack { GuideView() } }
        }
    }
}
