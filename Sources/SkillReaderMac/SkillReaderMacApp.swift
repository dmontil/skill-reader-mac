import SwiftUI

@main
struct SkillReaderMacApp: App {
    @State private var store = SkillStore()

    var body: some Scene {
        WindowGroup("Skill Reader", id: "main") {
            ContentView()
                .environment(store)
                .frame(minWidth: 900, minHeight: 600)
        }
        .windowStyle(.titleBar)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Refresh Skills") {
                    store.scan()
                }
                .keyboardShortcut("r", modifiers: .command)
            }
        }

        MenuBarExtra {
            MenuBarView()
                .environment(store)
        } label: {
            Label("Skill Reader", systemImage: "book.closed.fill")
        }
        .menuBarExtraStyle(.window)
    }
}
