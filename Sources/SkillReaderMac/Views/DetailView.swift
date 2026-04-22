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
    @State private var showAddToProfileSheet = false
    @State private var showMetadataEditor = false

    private var relatedProfiles: [ProfileEntry] {
        store.profilesUsing(entry)
    }

    private var viewCount: Int {
        store.viewCount(for: entry)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    header
                    useCaseStrip
                    metadataLine
                    if hasAssetMetadata {
                        assetMetadata
                    }
                    if !relatedProfiles.isEmpty {
                        relatedProfilesBlock
                    }
                    if viewCount > 0 {
                        insightBlock
                    }
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
        .sheet(isPresented: $showAddToProfileSheet) {
            AddEntryToProfileSheet(entry: entry)
                .environment(store)
        }
        .sheet(isPresented: $showMetadataEditor) {
            EditEntryMetadataSheet(entry: entry)
                .environment(store)
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

    private var useCaseStrip: some View {
        Group {
            if entry.useCaseHints.isEmpty {
                EmptyView()
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Best for")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.85))
                    FlowLayout(entry.useCaseHints, id: \.self) { hint in
                        tag(hint, color: .teal)
                    }
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

    private var hasAssetMetadata: Bool {
        entry.source != nil || entry.risk != nil || entry.dateAdded != nil
    }

    private var assetMetadata: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Asset metadata")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.85))

            if let source = entry.source, !source.isEmpty {
                metadataPill(label: "Source", value: source)
            }
            if let risk = entry.risk, !risk.isEmpty {
                metadataPill(label: "Risk", value: risk)
            }
            if let dateAdded = entry.dateAdded, !dateAdded.isEmpty {
                metadataPill(label: "Date added", value: dateAdded)
            }
        }
    }

    private func metadataPill(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.55))
                .frame(width: 82, alignment: .leading)
            Text(value)
                .foregroundStyle(.white.opacity(0.82))
                .textSelection(.enabled)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
    }

    private var relatedProfilesBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Used in profiles")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.85))

            ForEach(relatedProfiles) { profile in
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(profile.name)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white.opacity(0.9))
                        Text(profile.description.isEmpty ? profile.assetSummary : profile.description)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.65))
                            .lineLimit(2)
                    }
                    Spacer()
                    Text(profile.targetsDisplay)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private var insightBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Signals")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.85))

            HStack(spacing: 10) {
                tag("\(viewCount)x viewed", color: .orange)
                if relatedProfiles.isEmpty {
                    tag("Not yet used in a profile", color: .gray)
                }
            }
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
            actionPill("Add to Profile", hint: "") {
                showAddToProfileSheet = true
            }
            actionPill("Edit Metadata", hint: "") {
                showMetadataEditor = true
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

private struct FlowLayout<Data: RandomAccessCollection, ID: Hashable, Content: View>: View {
    let data: Data
    let id: KeyPath<Data.Element, ID>
    let content: (Data.Element) -> Content

    init(_ data: Data, id: KeyPath<Data.Element, ID>, @ViewBuilder content: @escaping (Data.Element) -> Content) {
        self.data = data
        self.id = id
        self.content = content
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(data), id: id) { element in
                    content(element)
                }
            }
            Spacer()
        }
    }
}

private struct AddEntryToProfileSheet: View {
    @Environment(SkillStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let entry: SkillEntry

    @State private var selectedProfileName: String = ""
    @State private var errorMessage = ""
    @State private var showError = false

    private var assetKind: ProfileAssetKind {
        entry.entryType == .skill ? .skill : .rule
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Add to Profile")
                .font(.title3)
                .fontWeight(.semibold)

            Form {
                Section("Asset") {
                    Text(entry.name)
                    Text("\(assetKind.rawValue.capitalized) · \(entry.assetID)")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                }

                Section("Profile") {
                    if store.profiles.isEmpty {
                        Text("Create a profile first, then come back here to attach this asset.")
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Profile", selection: $selectedProfileName) {
                            ForEach(store.profiles) { profile in
                                Text(profile.name).tag(profile.name)
                            }
                        }
                    }
                }
            }

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                Button("Add") {
                    save()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(selectedProfileName.isEmpty)
            }
        }
        .padding(16)
        .frame(minWidth: 520, minHeight: 260)
        .onAppear {
            selectedProfileName = store.profiles.first?.name ?? ""
        }
        .alert("Could not update profile", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private func save() {
        do {
            _ = try store.addAssetToProfile(name: selectedProfileName, kind: assetKind, assetID: entry.assetID)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

private struct EditEntryMetadataSheet: View {
    @Environment(SkillStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let entry: SkillEntry

    @State private var description: String
    @State private var source: String
    @State private var risk: String
    @State private var dateAdded: String
    @State private var errorMessage = ""
    @State private var showError = false

    init(entry: SkillEntry) {
        self.entry = entry
        _description = State(initialValue: entry.description)
        _source = State(initialValue: entry.source ?? "")
        _risk = State(initialValue: entry.risk ?? "")
        _dateAdded = State(initialValue: entry.dateAdded ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Edit Metadata")
                .font(.title3)
                .fontWeight(.semibold)

            Form {
                Section("Asset") {
                    Text(entry.name)
                    Text("\(entry.entryType == .skill ? "Skill" : "Rule") · \(entry.assetID)")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                }

                Section("Frontmatter") {
                    TextField("Description", text: $description)
                    TextField("Source", text: $source)
                    TextField("Risk", text: $risk)
                    TextField("Date added (YYYY-MM-DD)", text: $dateAdded)
                }
            }

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                Button("Save") {
                    save()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .frame(minWidth: 560, minHeight: 360)
        .alert("Could not update metadata", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private func save() {
        do {
            try store.updateMetadata(
                for: entry,
                description: description,
                source: source.isEmpty ? nil : source,
                risk: risk.isEmpty ? nil : risk,
                dateAdded: dateAdded.isEmpty ? nil : dateAdded
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}
