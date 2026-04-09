import SwiftUI

struct ContentView: View {
    @Environment(SkillStore.self) private var store
    @State private var selectedEntry: SkillEntry?
    @State private var columnVisibility = NavigationSplitViewVisibility.all

    var body: some View {
        @Bindable var store = store

        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView()
        } content: {
            SkillListView(selectedEntry: $selectedEntry)
        } detail: {
            if let entry = selectedEntry {
                DetailView(entry: entry)
            } else {
                EmptyDetailView()
            }
        }
        .searchable(text: $store.searchText, placement: .toolbar, prompt: "Search skills…")
        .toolbar {
            ToolbarItem(placement: .navigation) {
                if store.isScanning {
                    ProgressView().scaleEffect(0.7)
                } else {
                    Button {
                        store.scan()
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .help("Refresh skills (⌘R)")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                StatsBar()
            }
        }
        .navigationTitle("Skill Reader")
    }
}

struct EmptyDetailView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "book.closed")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("Select a skill to inspect it")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct StatsBar: View {
    @Environment(SkillStore.self) private var store

    var body: some View {
        HStack(spacing: 8) {
            Label("\(store.totalSkills) skills", systemImage: "sparkles")
            Label("\(store.totalRules) rules", systemImage: "doc.text")
            if store.hardlinked > 0 {
                Label("\(store.hardlinked) linked", systemImage: "link")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}
