import AppKit
import SwiftUI

struct ProfileDetailView: View {
    @Environment(SkillStore.self) private var store
    let profile: ProfileEntry

    @State private var showAddAssetSheet = false
    @State private var selectedTool = "codex"
    @State private var errorMessage = ""
    @State private var showError = false
    @State private var showDeleteAlert = false
    @State private var preview: ProfileApplicationPreview?
    @State private var multiPreview: MultiProfileApplicationPreview?

    private var targetTools: [String] {
        profile.targets.keys.sorted()
    }

    private var applyCount: Int {
        store.applyCount(for: profile)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(profile.name)
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(.white.opacity(0.95))
                    Text(profile.description.isEmpty ? "No description" : profile.description)
                        .foregroundStyle(.white.opacity(0.7))

                    Divider().overlay(Color.white.opacity(0.1))

                    HStack(spacing: 16) {
                        Label("\(profile.assets.count) assets", systemImage: "shippingbox.fill")
                        Label("\(profile.targets.count) targets", systemImage: "square.stack.3d.up")
                    }
                    .foregroundStyle(.white.opacity(0.75))

                    Text("Targets: \(profile.targetsDisplay)")
                        .foregroundStyle(.white.opacity(0.65))

                    if !profile.assetSummary.isEmpty {
                        Text("Composition: \(profile.assetSummary)")
                            .foregroundStyle(.mint.opacity(0.8))
                    }

                    if applyCount > 0 {
                        HStack(spacing: 16) {
                            Label("\(applyCount) applies", systemImage: "bolt.badge.checkmark")
                            if let lastProject = store.lastAppliedProject(for: profile) {
                                Label("Last project: \(lastProject)", systemImage: "folder.badge.gearshape")
                            }
                        }
                        .font(.callout)
                        .foregroundStyle(.white.opacity(0.68))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Assets")
                            .font(.headline)
                            .foregroundStyle(.white.opacity(0.85))
                        if profile.assets.isEmpty {
                            Text("No assets yet.")
                                .foregroundStyle(.white.opacity(0.55))
                        } else {
                            ForEach(profile.assets) { asset in
                                HStack {
                                    Text(asset.kind.rawValue.capitalized)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.white.opacity(0.12), in: Capsule())
                                    Text(asset.assetID)
                                        .foregroundStyle(.white.opacity(0.82))
                                    Spacer()
                                    Button("Remove") {
                                        removeAsset(asset)
                                    }
                                    .buttonStyle(.borderless)
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Apply")
                            .font(.headline)
                            .foregroundStyle(.white.opacity(0.85))
                        Picker("Tool", selection: $selectedTool) {
                            ForEach(targetTools, id: \.self) { tool in
                                Text(tool.capitalized).tag(tool)
                            }
                        }
                        .pickerStyle(.segmented)
                        Text("Preview the exact files that will be created or updated before writing anything.")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.55))
                        Button("Preview and Apply…") {
                            previewProfileApplication()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(profile.assets.isEmpty || targetTools.isEmpty)

                        if targetTools.count > 1 {
                            Button("Preview and Apply All Targets…") {
                                previewAllTargetsApplication()
                            }
                            .buttonStyle(.bordered)
                            .disabled(profile.assets.isEmpty)
                        }

                        if profile.assets.isEmpty {
                            Text("This profile is still empty. Add a few assets first so the preview becomes meaningful.")
                                .font(.caption)
                                .foregroundStyle(.orange.opacity(0.9))
                        }
                    }
                }
                .padding(16)
            }

            HStack(spacing: 8) {
                Button("Add Skill") { showAddAssetSheet = true }
                    .buttonStyle(.bordered)
                Button("Reveal Profile") {
                    NSWorkspace.shared.activateFileViewerSelecting([profile.profileURL])
                }
                .buttonStyle(.bordered)
                Spacer()
                Button("Delete Profile", role: .destructive) {
                    showDeleteAlert = true
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(12)
            .background(.ultraThinMaterial)
        }
        .sheet(isPresented: $showAddAssetSheet) {
            AddProfileAssetSheet(profile: profile)
                .environment(store)
        }
        .sheet(item: $preview) { preview in
            ProfileApplyPreviewSheet(preview: preview) {
                do {
                    try store.applyProfile(name: profile.name, tool: preview.tool, cwd: preview.cwd)
                    self.preview = nil
                } catch {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
        .sheet(item: $multiPreview) { preview in
            MultiProfileApplyPreviewSheet(preview: preview) {
                do {
                    try store.applyProfile(name: profile.name, tools: preview.tools, cwd: preview.cwd)
                    self.multiPreview = nil
                } catch {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
        .alert("Delete profile '\(profile.name)'?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                do {
                    try store.deleteProfile(name: profile.name)
                } catch {
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Profile error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private func removeAsset(_ asset: ProfileAsset) {
        do {
            _ = try store.removeAssetFromProfile(name: profile.name, kind: asset.kind, assetID: asset.assetID)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func applyProfile() {
        guard !targetTools.isEmpty else { return }
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Apply"
        panel.message = "Choose the project directory where the profile should be materialized."

        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try store.applyProfile(name: profile.name, tool: selectedTool, cwd: url)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func previewProfileApplication() {
        guard !targetTools.isEmpty else { return }
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Preview"
        panel.message = "Choose the project directory to preview the profile materialization."

        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            preview = try ProfileManager.previewApplication(name: profile.name, tool: selectedTool, cwd: url)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func previewAllTargetsApplication() {
        guard !targetTools.isEmpty else { return }
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Preview All"
        panel.message = "Choose the project directory to preview the profile across all targets."

        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let previews = try targetTools.map { tool in
                try ProfileManager.previewApplication(name: profile.name, tool: tool, cwd: url)
            }
            multiPreview = MultiProfileApplicationPreview(profileName: profile.name, cwd: url, previews: previews)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

private struct ProfileApplyPreviewSheet: View {
    @Environment(\.dismiss) private var dismiss

    let preview: ProfileApplicationPreview
    let apply: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Apply Preview")
                .font(.title3)
                .fontWeight(.semibold)

            Text("Profile `\(preview.profileName)` will write \(preview.totalWrites) item(s) for \(preview.tool.capitalized) in \(preview.cwd.lastPathComponent).")
                .foregroundStyle(.secondary)

            Form {
                Section("Assets included (\(preview.assets.count))") {
                    ForEach(preview.assets) { asset in
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(asset.kind.rawValue.capitalized): \(asset.title)")
                                .fontWeight(.medium)
                            Text(asset.assetID)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if !asset.description.isEmpty {
                                Text(asset.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }

                Section("Generated paths (\(preview.generatedPaths.count))") {
                    if preview.generatedPaths.isEmpty {
                        Text("No standalone generated paths for this target.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(preview.generatedPaths, id: \.path) { path in
                            Text(path.path(percentEncoded: false))
                                .font(.caption)
                                .textSelection(.enabled)
                        }
                    }
                }

                Section("Managed files (\(preview.managedFiles.count))") {
                    if preview.managedFiles.isEmpty {
                        Text("No existing instruction files will be updated directly.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(preview.managedFiles, id: \.path) { path in
                            Text(path.path(percentEncoded: false))
                                .font(.caption)
                                .textSelection(.enabled)
                        }
                    }
                }
            }

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                Button("Apply Profile") {
                    apply()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .frame(minWidth: 760, minHeight: 620)
    }
}

private struct MultiProfileApplyPreviewSheet: View {
    @Environment(\.dismiss) private var dismiss

    let preview: MultiProfileApplicationPreview
    let apply: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Apply All Targets")
                .font(.title3)
                .fontWeight(.semibold)

            Text("Profile `\(preview.profileName)` will write \(preview.totalWrites) item(s) across \(preview.previews.count) targets in \(preview.cwd.lastPathComponent).")
                .foregroundStyle(.secondary)

            Form {
                ForEach(preview.previews) { toolPreview in
                    Section(toolPreview.tool.capitalized) {
                        Text("\(toolPreview.assets.count) asset(s)")
                            .foregroundStyle(.secondary)
                        ForEach(toolPreview.generatedPaths, id: \.path) { path in
                            Text(path.path(percentEncoded: false))
                                .font(.caption)
                                .textSelection(.enabled)
                        }
                        ForEach(toolPreview.managedFiles, id: \.path) { path in
                            Text(path.path(percentEncoded: false))
                                .font(.caption)
                                .textSelection(.enabled)
                        }
                    }
                }
            }

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                Button("Apply All Targets") {
                    apply()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .frame(minWidth: 820, minHeight: 660)
    }
}
