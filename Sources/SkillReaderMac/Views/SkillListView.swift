import SwiftUI

struct SkillListView: View {
    @Environment(SkillStore.self) private var store
    @Binding var selectedEntry: SkillEntry?
    @State private var selectedID: UUID? = nil
    @State private var sortOrder = [KeyPathComparator(\SkillEntry.name)]

    var body: some View {
        Table(store.filtered, selection: $selectedID, sortOrder: $sortOrder) {
            TableColumn("Name") { entry in
                HStack(spacing: 6) {
                    LinkIndicator(entry: entry)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(entry.name).fontWeight(.medium)
                        Text(entry.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .width(min: 150, ideal: 200)

            TableColumn("Type") { entry in
                TypeBadge(type: entry.entryType)
            }
            .width(50)

            TableColumn("Tools") { entry in
                ToolsBadgeRow(tools: entry.tools)
            }
            .width(min: 60, ideal: 80)

            TableColumn("Scope") { entry in
                HStack(spacing: 4) {
                    Image(systemName: entry.scopeIcon)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(entry.scope)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .width(80)
        }
        .onChange(of: selectedID) { _, id in
            selectedEntry = store.filtered.first { $0.id == id }
            if let entry = selectedEntry { store.markViewed(entry) }
        }
        .contextMenu(forSelectionType: SkillEntry.ID.self) { ids in
            if let id = ids.first, let entry = store.filtered.first(where: { $0.id == id }) {
                ContextMenuItems(entry: entry)
            }
        }
        .navigationSplitViewColumnWidth(min: 300, ideal: 380)
    }
}

/// Shows a small icon indicating whether the skill dir is a symlink, hardlink, or plain dir.
struct LinkIndicator: View {
    let entry: SkillEntry

    var body: some View {
        Group {
            if entry.isHardlinked {
                Image(systemName: "link")
                    .help("Hardlinked across \(entry.tools.joined(separator: ", "))")
                    .foregroundStyle(Color.accentColor.opacity(0.8))
            } else if entry.isSymlink {
                Image(systemName: "arrow.turn.up.right")
                    .help("Symlink")
                    .foregroundStyle(Color.secondary)
            } else {
                Color.clear
            }
        }
        .font(.caption2)
        .frame(width: 12)
    }
}

struct TypeBadge: View {
    let type: EntryType
    var body: some View {
        Text(type == .skill ? "skill" : "rule")
            .font(.caption2)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(type == .skill ? Color.accentColor.opacity(0.15) : Color.orange.opacity(0.15))
            .foregroundStyle(type == .skill ? Color.accentColor : Color.orange)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

struct ToolsBadgeRow: View {
    let tools: [String]
    let iconMap: [String: String] = [
        "claude": "C", "windsurf": "W", "kiro": "K", "codex": "X",
        "cursor": "U", "opencode": "O", "cline": "L", "zed": "Z",
        "amp": "A", "copilot": "G", "amazonq": "Q", "aider": "D",
    ]
    var body: some View {
        HStack(spacing: 3) {
            ForEach(tools, id: \.self) { tool in
                Text(iconMap[tool] ?? String(tool.prefix(1).uppercased()))
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .frame(width: 16, height: 16)
                    .background(Color.secondary.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            }
        }
    }
}

struct ContextMenuItems: View {
    @Environment(SkillStore.self) private var store
    let entry: SkillEntry
    @State private var showDeleteAlert = false

    var body: some View {
        Button("Reveal in Finder") {
            NSWorkspace.shared.activateFileViewerSelecting([entry.primaryPath])
        }
        if let url = entry.contentURL {
            Button("Open in Editor") {
                NSWorkspace.shared.open(url)
            }
        }
        Divider()
        Button("Delete…", role: .destructive) {
            showDeleteAlert = true
        }
        .alert("Delete \"\(entry.name)\"?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                try? store.delete(entry, from: entry.tools)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(entry.isHardlinked
                 ? "This will remove it from: \(entry.tools.joined(separator: ", "))"
                 : "This will permanently remove the skill files.")
        }
    }
}
