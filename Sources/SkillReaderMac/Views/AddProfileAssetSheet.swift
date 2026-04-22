import SwiftUI

struct AddProfileAssetSheet: View {
    @Environment(SkillStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let profile: ProfileEntry

    @State private var kind: ProfileAssetKind = .skill
    @State private var searchText = ""
    @State private var selectedAssetIDs: Set<String> = []
    @State private var errorMessage = ""
    @State private var showError = false

    private var kindTitle: String {
        switch kind {
        case .skill: "Skill"
        case .rule: "Rule"
        case .agents: "Guide"
        }
    }

    private var assets: [LibraryAssetEntry] {
        let all = availableAssets
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if query.isEmpty { return all }
        return all.filter {
            $0.assetID.lowercased().contains(query) ||
            $0.title.lowercased().contains(query) ||
            $0.detail.lowercased().contains(query)
        }
    }

    private var availableAssets: [LibraryAssetEntry] {
        var merged: [String: LibraryAssetEntry] = [:]

        for asset in ProfileManager.loadLibraryAssets(kind: kind) {
            merged[asset.id] = asset
        }

        for entry in detectedEntries {
            let asset = LibraryAssetEntry(
                kind: kind,
                assetID: entry.assetID,
                title: entry.name,
                detail: entry.description,
                sourceURL: entry.primaryPath,
                sourceKind: .detected
            )
            if merged[asset.id] == nil {
                merged[asset.id] = asset
            }
        }

        return merged.values.sorted {
            if $0.sourceKind != $1.sourceKind {
                return $0.sourceKind == .library
            }
            return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }
    }

    private var detectedEntries: [SkillEntry] {
        store.entries.filter { entry in
            switch (kind, entry.entryType) {
            case (.skill, .skill), (.rule, .rule):
                return true
            default:
                return false
            }
        }
    }

    private func isAlreadyAdded(_ asset: LibraryAssetEntry) -> Bool {
        profile.assets.contains { $0.kind == asset.kind && $0.assetID == asset.assetID }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Add \(kindTitle) to \(profile.name)")
                .font(.title3)
                .fontWeight(.semibold)

            Form {
                Section(kindTitle) {
                    Picker("Kind", selection: $kind) {
                        ForEach(ProfileAssetKind.allCases) { item in
                            Text(item.rawValue.capitalized).tag(item)
                        }
                    }
                    .onChange(of: kind) { _, _ in
                        selectedAssetIDs.removeAll()
                        searchText = ""
                    }

                    TextField("Search \(kind.rawValue)s", text: $searchText)

                    Text("You can pick assets already in the shared library, or detected assets from your installed tool directories. Detected assets will be imported into \(ProfileManager.libraryRoot().path(percentEncoded: false)) when added.")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                }

                Section(assets.isEmpty ? "Available \(kindTitle)s" : "Available \(kindTitle)s (\(assets.count))") {
                    if assets.isEmpty {
                        Text("No \(kindTitle.lowercased())s found in the shared library or among detected tool assets for this type.")
                            .foregroundStyle(.secondary)
                    } else {
                        HStack {
                            Button("Select all") {
                                selectedAssetIDs = Set(
                                    assets
                                        .filter { !isAlreadyAdded($0) }
                                        .map(\.assetID)
                                )
                            }
                            .buttonStyle(.borderless)

                            Button("Clear") {
                                selectedAssetIDs.removeAll()
                            }
                            .buttonStyle(.borderless)

                            Spacer()

                            Text("\(selectedAssetIDs.count) selected")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        List(assets, id: \.id) { asset in
                            HStack(alignment: .top, spacing: 10) {
                                Toggle("", isOn: Binding(
                                    get: { selectedAssetIDs.contains(asset.assetID) },
                                    set: { isOn in
                                        if isOn {
                                            selectedAssetIDs.insert(asset.assetID)
                                        } else {
                                            selectedAssetIDs.remove(asset.assetID)
                                        }
                                    }
                                ))
                                .toggleStyle(.checkbox)
                                .labelsHidden()
                                .disabled(isAlreadyAdded(asset))

                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 6) {
                                        Text(asset.title)
                                            .fontWeight(.medium)
                                        Text(asset.sourceKind == .library ? "Library" : "Detected")
                                            .font(.caption2)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background((asset.sourceKind == .library ? Color.mint : Color.orange).opacity(0.18), in: Capsule())
                                    }
                                    Text(asset.assetID)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    if !asset.detail.isEmpty {
                                        Text(asset.detail)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    }
                                }
                                Spacer()
                                if isAlreadyAdded(asset) {
                                    Text("Added")
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.white.opacity(0.12), in: Capsule())
                                } else {
                                    Text(asset.sourceKind == .detected ? "Will import" : "Ready")
                                        .font(.caption)
                                        .foregroundStyle(asset.sourceKind == .detected ? .orange : .mint)
                                }
                            }
                            .padding(.vertical, 2)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                guard !isAlreadyAdded(asset) else { return }
                                if selectedAssetIDs.contains(asset.assetID) {
                                    selectedAssetIDs.remove(asset.assetID)
                                } else {
                                    selectedAssetIDs.insert(asset.assetID)
                                }
                            }
                        }
                        .frame(minHeight: 220, maxHeight: 320)
                    }
                }
            }

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                Button("Add Selected \(kindTitle)\(selectedAssetIDs.count == 1 ? "" : "s")") {
                    saveSelected()
                }
                    .keyboardShortcut(.defaultAction)
                    .disabled(selectedAssetIDs.isEmpty)
            }
        }
        .padding(16)
        .frame(minWidth: 680, idealWidth: 720, minHeight: 420, idealHeight: 500)
        .alert("Could not add \(kindTitle.lowercased())", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private func saveSelected() {
        do {
            for assetID in selectedAssetIDs {
                guard let asset = assets.first(where: { $0.assetID == assetID }) else { continue }

                let finalAssetID: String
                if asset.sourceKind == .detected,
                   let entry = detectedEntries.first(where: { $0.assetID == asset.assetID }) {
                    let imported = try ProfileManager.importEntryToLibrary(entry)
                    finalAssetID = imported.assetID
                } else {
                    finalAssetID = asset.assetID
                }

                _ = try store.addAssetToProfile(name: profile.name, kind: kind, assetID: finalAssetID)
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}
