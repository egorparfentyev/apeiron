import SwiftUI

@main struct VectorApp: App {
    @Environment(\.scenePhase) private var phase
    @State private var store = Store()
    var body: some Scene {
        WindowGroup {
            RootView().environment(store).tint(.mint)
                .onAppear { store.refreshReminders() }
                .onChange(of: phase) { _, phase in if phase == .active { store.refreshReminders() } }
                .environment(\.locale, Locale(identifier: "ru_RU"))
                .alert("Данные", isPresented: Binding(get: { store.error != nil }, set: { if !$0 { store.error = nil } })) {
                    Button("Понятно") { store.error = nil }
                } message: { Text(store.error ?? "") }
        }
    }
}
