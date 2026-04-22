import SwiftUI

private let toolInitials: [String: String] = [
    "claude": "C", "windsurf": "W", "kiro": "K", "codex": "X",
    "cursor": "U", "opencode": "O", "cline": "L", "zed": "Z",
    "amp": "A", "copilot": "G", "amazonq": "Q", "aider": "D",
]

struct SkillListView: View {
    @Environment(SkillStore.self) private var store
    @Binding var selectedEntry: SkillEntry?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(Color.white.opacity(0.08))

            if store.filtered.isEmpty && !store.isScanning {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(store.filtered) { entry in
                            SkillRow(
                                entry: entry,
                                isSelected: selectedEntry?.id == entry.id
                            )
                            .onTapGesture {
                                selectedEntry = entry
                                store.markViewed(entry)
                            }
                            .contextMenu {
                                ContextMenuItems(entry: entry)
                            }
                        }
                    }
                    .padding(8)
                }
            }
        }
        .background(Color.white.opacity(0.015))
        .navigationSplitViewColumnWidth(min: 300, ideal: 380)
    }

    private var header: some View {
        HStack(spacing: 0) {
            Text("Name")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Type")
                .frame(width: 70, alignment: .leading)
            Text("Tools")
                .frame(width: 70, alignment: .leading)
        }
        .font(.caption)
        .foregroundStyle(.white.opacity(0.65))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: store.entries.isEmpty ? "tray" : "line.3.horizontal.decrease.circle")
                .font(.system(size: 28))
                .foregroundStyle(.white.opacity(0.35))
            Text(store.entries.isEmpty ? "No skills found" : "No results match your filters")
                .foregroundStyle(.white.opacity(0.65))
                .font(.callout)
            Text(store.entries.isEmpty
                 ? "Create your first skill or scan a project that already contains agent instructions."
                 : "Try searching by tool, scope, risk, source, or the kind of work you want this asset to help with.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.45))
                .font(.caption)
                .frame(maxWidth: 320)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct SkillRow: View {
    @Environment(SkillStore.self) private var store
    let entry: SkillEntry
    let isSelected: Bool

    private var rowFill: Color {
        isSelected ? Color.white.opacity(0.13) : Color.white.opacity(0.04)
    }

    private var rowBorder: Color {
        isSelected ? Color.blue.opacity(0.5) : Color.white.opacity(0.06)
    }

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: entry.entryType == .skill ? "doc.text" : "doc.richtext")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.65))
                VStack(alignment: .leading, spacing: 1) {
                    Text(entry.name)
                        .fontWeight(.medium)
                        .lineLimit(1)
                        .foregroundStyle(.white.opacity(0.95))
                    if !entry.description.isEmpty {
                        Text(entry.description)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.45))
                            .lineLimit(1)
                    }
                    let usageCount = store.profilesUsing(entry).count
                    if usageCount > 0 {
                        Text("Used in \(usageCount) profile\(usageCount == 1 ? "" : "s")")
                            .font(.caption2)
                            .foregroundStyle(.teal.opacity(0.85))
                            .lineLimit(1)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(entry.entryType == .skill ? "Skill" : "Rule")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.75))
                .frame(width: 70, alignment: .leading)

            HStack(spacing: 4) {
                ForEach(entry.tools.prefix(2), id: \.self) { tool in
                    Text(String((toolInitials[tool] ?? tool.uppercased()).prefix(1)))
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .frame(width: 15, height: 15)
                        .background(Color.white.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                }
                if entry.tools.count > 2 {
                    Text("…")
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            .frame(width: 70, alignment: .leading)

            Image(systemName: "ellipsis")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.55))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(rowFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(rowBorder, lineWidth: 1)
                )
        )
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
            Button("Move to Trash", role: .destructive) {
                try? store.delete(entry, from: entry.tools)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(entry.isHardlinked
                 ? "This will move it to Trash from: \(entry.tools.joined(separator: ", "))"
                 : "This will move the skill files to Trash.")
        }
    }
}
