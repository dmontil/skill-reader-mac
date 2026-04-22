import SwiftUI

struct AddProfileSheet: View {
    @Environment(SkillStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var description = ""
    @State private var errorMessage = ""
    @State private var showError = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("New Profile")
                .font(.title3)
                .fontWeight(.semibold)

            Form {
                Section("Profile") {
                    TextField("Name", text: $name)
                    TextField("Description", text: $description)
                }

                Section("Defaults") {
                    Text("Profiles are created with project-mode targets for Codex, Claude, Cursor, Windsurf, and OpenCode.")
                        .foregroundStyle(.secondary)
                        .font(.callout)
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
    }

    private func save() {
        do {
            _ = try store.createProfile(name: name, description: description)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}
