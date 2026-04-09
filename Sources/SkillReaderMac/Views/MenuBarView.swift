import SwiftUI

struct MenuBarView: View {
    @Environment(SkillStore.self) private var store
    @Environment(\.openWindow) private var openWindow
    @State private var search = ""

    private var searchResults: [SkillEntry] {
        guard !search.isEmpty else { return [] }
        let q = search.lowercased()
        return store.entries.filter {
            $0.name.lowercased().contains(q) || $0.description.lowercased().contains(q)
        }.prefix(5).map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Search
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search skills…", text: $search)
                    .textFieldStyle(.plain)
                if !search.isEmpty {
                    Button { search = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            // Search results
            if !searchResults.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    SectionHeader("Results")
                    ForEach(searchResults) { entry in
                        MenuBarSkillRow(entry: entry)
                    }
                }
                Divider()
            }

            // Recently viewed
            if search.isEmpty {
                let recent = store.recentlyViewed
                if !recent.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        SectionHeader("Recently Viewed")
                        ForEach(recent) { entry in
                            MenuBarSkillRow(entry: entry)
                        }
                    }
                    Divider()
                }

                // Recently modified
                let modified = store.recentEntries
                if !modified.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        SectionHeader("Recently Modified")
                        ForEach(modified) { entry in
                            MenuBarSkillRow(entry: entry)
                        }
                    }
                    Divider()
                }
            }

            // Stats
            HStack(spacing: 12) {
                Label("\(store.totalSkills) skills", systemImage: "sparkles")
                Label("\(store.totalRules) rules", systemImage: "doc.text")
                Label("\(store.hardlinked) linked", systemImage: "link")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            Divider()

            // Actions
            HStack {
                Button {
                    openWindow(id: "main")
                    NSApp.activate(ignoringOtherApps: true)
                } label: {
                    Label("Open Skill Reader", systemImage: "arrow.up.forward.app")
                }
                .buttonStyle(.plain)

                Spacer()

                Button {
                    store.scan()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.plain)

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(width: 340)
    }

}

private struct MenuBarSkillRow: View {
    let entry: SkillEntry

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: entry.entryType == .skill ? "sparkles" : "doc.text")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 14)

            VStack(alignment: .leading, spacing: 1) {
                Text(entry.name).fontWeight(.medium)
                Text(entry.tools.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(entry.modificationDate, style: .relative)
                .font(.caption2)
                .foregroundStyle(.tertiary)

            Button {
                if let url = entry.contentURL {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                Image(systemName: "arrow.up.right.square")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Open in editor")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}

private struct SectionHeader: View {
    let title: String
    init(_ title: String) { self.title = title }
    var body: some View {
        Text(title)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 2)
    }
}
