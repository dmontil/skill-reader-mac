import SwiftUI

struct DetailView: View {
    @Environment(SkillStore.self) private var store
    let entry: SkillEntry
    @State private var showDeleteAlert = false
    @State private var content: String = ""
    @State private var isLoadingContent = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                header
                Divider().padding(.vertical, 12)
                // Metadata grid
                metadataGrid
                Divider().padding(.vertical, 12)
                // Action buttons
                actionBar
                Divider().padding(.vertical, 12)
                // File content
                fileContent
            }
            .padding(20)
        }
        .navigationSplitViewColumnWidth(min: 360, ideal: 460)
        .task(id: entry.id) { await loadContent() }
        .alert("Delete \"\(entry.name)\"?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                try? store.delete(entry, from: entry.tools)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if entry.isHardlinked {
                Text("Removes from: \(entry.tools.joined(separator: ", "))")
            } else {
                Text("This action cannot be undone.")
            }
        }
    }

    // MARK: - Subviews

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    TypeBadge(type: entry.entryType)
                    if entry.isHardlinked {
                        Label("Hardlinked", systemImage: "link")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Text(entry.name)
                    .font(.title2)
                    .fontWeight(.semibold)
                if !entry.description.isEmpty {
                    Text(entry.description)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer()
        }
    }

    private var metadataGrid: some View {
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 16, verticalSpacing: 8) {
            GridRow {
                MetaLabel("Tools")
                ToolsBadgeRow(tools: entry.tools)
                    .gridColumnAlignment(.leading)
            }
            GridRow {
                MetaLabel("Scope")
                HStack(spacing: 4) {
                    Image(systemName: entry.scopeIcon).foregroundStyle(.secondary)
                    Text(entry.scope)
                }
            }
            if let project = entry.project {
                GridRow {
                    MetaLabel("Project")
                    Text(project)
                }
            }
            GridRow {
                MetaLabel("Size")
                Text(String(format: "%.1f KB", entry.sizeKB))
            }
            GridRow {
                MetaLabel("Modified")
                Text(entry.modificationDate.formatted(date: .abbreviated, time: .shortened))
                    .foregroundStyle(.secondary)
            }
            if let source = entry.source {
                GridRow { MetaLabel("Source"); Text(source) }
            }
            if let risk = entry.risk {
                GridRow { MetaLabel("Risk"); Text(risk) }
            }
            GridRow {
                MetaLabel("Path\(entry.paths.count > 1 ? "s" : "")")
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(zip(entry.tools, entry.paths)), id: \.0) { tool, path in
                        Button {
                            NSWorkspace.shared.activateFileViewerSelecting([path])
                        } label: {
                            Text(path.path(percentEncoded: false))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        .buttonStyle(.plain)
                        .help("Reveal in Finder")
                    }
                }
            }
        }
    }

    private var actionBar: some View {
        HStack(spacing: 10) {
            if let url = entry.contentURL {
                Button {
                    NSWorkspace.shared.open(url)
                } label: {
                    Label("Edit in…", systemImage: "pencil")
                }
                .help("Open in your default .md editor")
            }

            Button {
                NSWorkspace.shared.activateFileViewerSelecting([entry.primaryPath])
            } label: {
                Label("Reveal in Finder", systemImage: "folder")
            }

            if let url = entry.contentURL {
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(url.path(percentEncoded: false), forType: .string)
                } label: {
                    Label("Copy Path", systemImage: "doc.on.clipboard")
                }
            }

            Spacer()

            Button(role: .destructive) {
                showDeleteAlert = true
            } label: {
                Label("Delete", systemImage: "trash")
                    .foregroundStyle(.red)
            }
        }
        .buttonStyle(.bordered)
    }

    private var fileContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Content")
                    .font(.headline)
                Spacer()
                Text(entry.contentURL?.lastPathComponent ?? "")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            if isLoadingContent {
                ProgressView().frame(maxWidth: .infinity)
            } else if content.isEmpty {
                Text("No content available")
                    .foregroundStyle(.tertiary)
                    .font(.callout)
            } else {
                Text(content)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color(nsColor: .textBackgroundColor).opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    // MARK: - Load content

    private func loadContent() async {
        guard let url = entry.contentURL else { return }
        isLoadingContent = true
        content = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        isLoadingContent = false
    }
}

private struct MetaLabel: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(.secondary)
            .frame(width: 70, alignment: .trailing)
    }
}
