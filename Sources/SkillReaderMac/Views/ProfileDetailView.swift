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
                            ForEach(profile.targets.keys.sorted(), id: \.self) { tool in
                                Text(tool.capitalized).tag(tool)
                            }
                        }
                        .pickerStyle(.segmented)
                        Button("Choose Project and Apply") {
                            applyProfile()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(16)
            }

            HStack(spacing: 8) {
                Button("Add Asset") { showAddAssetSheet = true }
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
}
