import SwiftUI

private let detailToolInitials: [String: String] = [
    "claude": "C", "windsurf": "W", "kiro": "K", "codex": "X",
    "cursor": "U", "opencode": "O", "cline": "L", "zed": "Z",
    "amp": "A", "copilot": "G", "amazonq": "Q", "aider": "D",
]

struct DetailView: View {
    @Environment(SkillStore.self) private var store
    let entry: SkillEntry
    @State private var showDeleteAlert = false
    @State private var showDeleteError = false
    @State private var deleteErrorMessage = ""
    @State private var content: String = ""
    @State private var isLoadingContent = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    header
                    metadataLine
                    Divider().overlay(Color.white.opacity(0.1))
                    contentBlock
                }
                .padding(16)
            }
            bottomBar
        }
        .background(Color.white.opacity(0.02))
        .navigationSplitViewColumnWidth(min: 360, ideal: 460)
        .task(id: entry.id) { await loadContent() }
        .alert("Delete \"\(entry.name)\"?", isPresented: $showDeleteAlert) {
            Button("Move to Trash", role: .destructive) {
                do {
                    try store.delete(entry, from: entry.tools)
                } catch {
                    deleteErrorMessage = error.localizedDescription
                    showDeleteError = true
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if entry.isHardlinked {
                Text("Moves to Trash from: \(entry.tools.joined(separator: ", "))")
            } else {
                Text("Moves the files to Trash.")
            }
        }
        .alert("Delete failed", isPresented: $showDeleteError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deleteErrorMessage)
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.name)
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(.white.opacity(0.95))
                if !entry.description.isEmpty {
                    Text(entry.description)
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(2)
                }
            }
            Spacer()
            HStack(spacing: 8) {
                tag(entry.entryType == .skill ? "skill" : "rule", color: .blue)
                if entry.isSymlink {
                    tag("Symlink", color: .gray)
                } else if entry.isHardlinked {
                    tag("Hardlinked", color: .indigo)
                }
            }
        }
    }

    private func tag(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.22))
            .foregroundStyle(.white.opacity(0.9))
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var metadataLine: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 16) {
                Label("Tools: \(toolsLabel)", systemImage: "wrench.and.screwdriver")
                Label("Scope: \(entry.scope)", systemImage: "globe")
                Label(String(format: "Size: %.1f KB", entry.sizeKB), systemImage: "folder")
            }
            .font(.callout)
            .foregroundStyle(.white.opacity(0.78))

            HStack(spacing: 16) {
                Label("Modified: \(entry.modificationDate.formatted(date: .long, time: .shortened))", systemImage: "clock")
                    .lineLimit(1)
                Label("Path: \(entry.primaryPath.path(percentEncoded: false))", systemImage: "doc.text")
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .font(.callout)
            .foregroundStyle(.white.opacity(0.68))
        }
    }

    private var toolsLabel: String {
        entry.tools.map { t in
            let icon = detailToolInitials[t] ?? t.uppercased()
            return "\(icon) (\(t.capitalized))"
        }.joined(separator: ", ")
    }

    private var contentBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Content")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.85))

            if isLoadingContent {
                ProgressView().frame(maxWidth: .infinity)
            } else if content.isEmpty {
                Text("No content available")
                    .foregroundStyle(.white.opacity(0.55))
                    .font(.callout)
            } else {
                codeView(content)
            }
        }
    }

    private func codeView(_ source: String) -> some View {
        let lines = source.components(separatedBy: .newlines)
        return VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(lines.enumerated()), id: \.offset) { idx, line in
                HStack(alignment: .top, spacing: 10) {
                    Text("\(idx + 1)")
                        .foregroundStyle(.white.opacity(0.35))
                        .frame(width: 28, alignment: .trailing)
                    Text(line.isEmpty ? " " : line)
                        .foregroundStyle(.white.opacity(0.84))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .font(.system(.body, design: .monospaced))
                .padding(.vertical, 1)
            }
        }
        .textSelection(.enabled)
        .padding(12)
        .background(Color.black.opacity(0.25))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.08), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var bottomBar: some View {
        HStack(spacing: 8) {
            actionPill("Edit in...", hint: "⌘E") {
                if let url = entry.contentURL { NSWorkspace.shared.open(url) }
            }
            actionPill("Reveal in Finder", hint: "⌘R") {
                NSWorkspace.shared.activateFileViewerSelecting([entry.primaryPath])
            }
            actionPill("Copy Path", hint: "⌘C") {
                if let url = entry.contentURL {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(url.path(percentEncoded: false), forType: .string)
                }
            }
            Spacer()
            Button {
                showDeleteAlert = true
            } label: {
                HStack(spacing: 6) {
                    Text("Delete")
                    Text("⌘⌫")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.red.opacity(0.85))
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .overlay(Rectangle().frame(height: 1).foregroundStyle(Color.white.opacity(0.08)), alignment: .top)
    }

    private func actionPill(_ title: String, hint: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                Text(hint)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
            }
        }
        .buttonStyle(.bordered)
    }

    private func loadContent() async {
        guard let url = entry.contentURL else { return }
        isLoadingContent = true
        content = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        isLoadingContent = false
    }
}
