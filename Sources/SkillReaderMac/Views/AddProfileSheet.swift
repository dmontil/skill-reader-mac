import SwiftUI

private enum ProfileTemplate: String, CaseIterable, Identifiable {
    case blank
    case codeReview
    case shipping
    case research

    var id: String { rawValue }

    var title: String {
        switch self {
        case .blank: "Blank"
        case .codeReview: "Code Review"
        case .shipping: "Shipping"
        case .research: "Research"
        }
    }

    var suggestedName: String {
        switch self {
        case .blank: ""
        case .codeReview: "code-review"
        case .shipping: "ship-ready"
        case .research: "research-brief"
        }
    }

    var suggestedDescription: String {
        switch self {
        case .blank:
            return ""
        case .codeReview:
            return "Review code for bugs, regressions, and missing tests before merging."
        case .shipping:
            return "Prepare a project for implementation and final verification with reusable guardrails."
        case .research:
            return "Investigate a topic, synthesize sources, and produce an actionable brief."
        }
    }

    var guidance: String {
        switch self {
        case .blank:
            return "Start from scratch when you already know which assets should go together."
        case .codeReview:
            return "Good first profile if you want a repeatable audit workflow across projects."
        case .shipping:
            return "Useful when you want implementation, validation, and instruction materialization in one bundle."
        case .research:
            return "Helpful for evidence-backed work where source quality and synthesis matter."
        }
    }
}

struct AddProfileSheet: View {
    @Environment(SkillStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var description = ""
    @State private var template: ProfileTemplate = .blank
    @State private var selectedRecommendedAssetIDs: Set<String> = []
    @State private var errorMessage = ""
    @State private var showError = false

    private var recommendedAssets: [LibraryAssetEntry] {
        store.recommendedAssets(for: effectiveName, description: effectiveDescription)
    }

    private var effectiveName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var effectiveDescription: String {
        description.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("New Profile")
                .font(.title3)
                .fontWeight(.semibold)

            Form {
                Section("Profile") {
                    TextField("Name", text: $name)
                    TextField("Description", text: $description)
                    Picker("Template", selection: $template) {
                        ForEach(ProfileTemplate.allCases) { template in
                            Text(template.title).tag(template)
                        }
                    }
                    .onChange(of: template) { _, newTemplate in
                        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            name = newTemplate.suggestedName
                        }
                        if description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            description = newTemplate.suggestedDescription
                        }
                        refreshRecommendedSelections()
                    }
                }

                Section("Defaults") {
                    Text("Profiles are created with project-mode targets for Codex, Claude, Cursor, Windsurf, and OpenCode.")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                    Text(template.guidance)
                        .foregroundStyle(.secondary)
                        .font(.callout)
                }

                Section("Suggested next step") {
                    Text("After creating it, add 2-3 assets and use the preview flow to inspect exactly what will be written into a project.")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                }

                if !recommendedAssets.isEmpty {
                    Section("Recommended assets") {
                        Text("Based on the profile name and description, these library assets look like a reasonable starting point.")
                            .foregroundStyle(.secondary)
                            .font(.callout)
                        ForEach(recommendedAssets) { asset in
                            Toggle(isOn: Binding(
                                get: { selectedRecommendedAssetIDs.contains(asset.id) },
                                set: { isOn in
                                    if isOn {
                                        selectedRecommendedAssetIDs.insert(asset.id)
                                    } else {
                                        selectedRecommendedAssetIDs.remove(asset.id)
                                    }
                                }
                            )) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(asset.title)
                                    Text("\(asset.kind.rawValue.capitalized) · \(asset.assetID)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    if !asset.detail.isEmpty {
                                        Text(asset.detail)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                Button("Create Profile") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(16)
        .frame(minWidth: 520, minHeight: 260)
        .alert("Could not create profile", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            refreshRecommendedSelections()
        }
        .onChange(of: name) { _, _ in
            refreshRecommendedSelections()
        }
        .onChange(of: description) { _, _ in
            refreshRecommendedSelections()
        }
    }

    private func save() {
        do {
            let created = try store.createProfile(name: name, description: description)
            let selectedAssets = recommendedAssets.filter { selectedRecommendedAssetIDs.contains($0.id) }
            for asset in selectedAssets {
                _ = try store.addAssetToProfile(name: created.name, kind: asset.kind, assetID: asset.assetID)
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func refreshRecommendedSelections() {
        let ids = Set(recommendedAssets.map(\.id))
        if selectedRecommendedAssetIDs.isEmpty {
            selectedRecommendedAssetIDs = ids
        } else {
            selectedRecommendedAssetIDs = selectedRecommendedAssetIDs.intersection(ids)
        }
    }
}
