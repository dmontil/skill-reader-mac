import SwiftUI

struct AddProfileAssetSheet: View {
    @Environment(SkillStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let profile: ProfileEntry

    @State private var kind: ProfileAssetKind = .skill
    @State private var assetID = ""
    @State private var errorMessage = ""
    @State private var showError = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Add Asset to \(profile.name)")
                .font(.title3)
                .fontWeight(.semibold)

            Form {
                Section("Asset") {
                    Picker("Kind", selection: $kind) {
                        ForEach(ProfileAssetKind.allCases) { item in
                            Text(item.rawValue.capitalized).tag(item)
                        }
                    }
                    TextField("Asset ID", text: $assetID)
                    Text("Assets must already exist in the shared library under \(ProfileManager.libraryRoot().path(percentEncoded: false)).")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                }
            }

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                Button("Add Asset") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(assetID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(16)
        .frame(minWidth: 560, minHeight: 250)
        .alert("Could not add asset", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private func save() {
        do {
            _ = try store.addAssetToProfile(name: profile.name, kind: kind, assetID: assetID)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}
