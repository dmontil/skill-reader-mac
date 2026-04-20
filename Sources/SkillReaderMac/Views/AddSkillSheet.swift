import SwiftUI

private enum SkillTemplate: String, CaseIterable, Identifiable {
    case blank
    case research
    case coding
    case review

    var id: String { rawValue }
    var title: String {
        switch self {
        case .blank: "Blank"
        case .research: "Research"
        case .coding: "Coding"
        case .review: "Code Review"
        }
    }

    var body: String {
        switch self {
        case .blank:
            return ""
        case .research:
            return """
            ## Purpose
            Investigate a topic and produce an evidence-backed summary.

            ## Steps
            1. Clarify the question and success criteria.
            2. Gather facts from reliable primary sources.
            3. Synthesize tradeoffs and recommendations.

            ## Output
            Concise summary with sources and clear next step.
            """
        case .coding:
            return """
            ## Purpose
            Implement a change safely in an existing codebase.

            ## Steps
            1. Inspect relevant files before editing.
            2. Apply minimal focused changes.
            3. Run build/tests and report outcomes.

            ## Output
            Changed files, why they changed, and verification results.
            """
        case .review:
            return """
            ## Purpose
            Review code for bugs, regressions, and missing tests.

            ## Steps
            1. Prioritize high-risk logic paths.
            2. Identify issues with clear severity.
            3. Propose concrete fixes and test gaps.

            ## Output
            Findings first, open questions second, summary last.
            """
        }
    }
}

struct AddSkillSheet: View {
    @Environment(SkillStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var description = ""
    @State private var content = ""
    @State private var scope = "global"
    @State private var mode: SkillInstallMode = .hardlink
    @State private var selectedTools: Set<String> = ["codex"]
    @State private var template: SkillTemplate = .blank
    @State private var source = ""
    @State private var risk = ""
    @State private var dateAdded = ""
    @State private var overwrite = false
    @State private var showAdvanced = false

    @State private var errorMessage = ""
    @State private var showError = false

    private var installableTools: [ToolInfo] {
        allTools.filter { SkillScanner.installableSkillTools.contains($0.id) }
    }

    private var plannedDestinations: [URL] {
        (try? SkillScanner.plannedDestinations(
            name: name,
            tools: Array(selectedTools),
            scope: scope
        )) ?? []
    }

    private var nameError: String? {
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Name is required."
        }
        let invalid = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_")).inverted
        if name.rangeOfCharacter(from: invalid) != nil {
            return "Use only letters, numbers, '-' and '_'."
        }
        return nil
    }

    private var destinationConflict: Bool {
        plannedDestinations.contains { FileManager.default.fileExists(atPath: $0.path) }
    }

    private var canSave: Bool {
        nameError == nil && !selectedTools.isEmpty && (!destinationConflict || overwrite)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("New Skill")
                .font(.title3)
                .fontWeight(.semibold)

            Form {
                Section("Quick setup") {
                    TextField("Name (directory)", text: $name)
                    TextField("Description", text: $description)
                    Picker("Template", selection: $template) {
                        ForEach(SkillTemplate.allCases) { tpl in
                            Text(tpl.title).tag(tpl)
                        }
                    }
                    .onChange(of: template) { _, newValue in
                        if content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            content = newValue.body
                        }
                    }
                }

                Section("Install") {
                    Picker("Scope", selection: $scope) {
                        Text("Global").tag("global")
                        Text("Project").tag("project")
                    }
                    .pickerStyle(.segmented)

                    HStack {
                        Button("Common set") {
                            selectedTools = ["codex", "claude", "windsurf"]
                        }
                        Button("Select all") {
                            selectedTools = Set(installableTools.map(\.id))
                        }
                        Button("Clear") {
                            selectedTools.removeAll()
                        }
                    }
                    .buttonStyle(.borderless)

                    ForEach(installableTools, id: \.id) { tool in
                        Toggle(
                            isOn: Binding(
                                get: { selectedTools.contains(tool.id) },
                                set: { isOn in
                                    if isOn { selectedTools.insert(tool.id) } else { selectedTools.remove(tool.id) }
                                }
                            )
                        ) {
                            Label(tool.displayName, systemImage: tool.icon)
                        }
                    }
                }

                Section("Validation") {
                    if let nameError {
                        Label(nameError, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    } else {
                        Label("Name is valid.", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }

                    if selectedTools.isEmpty {
                        Label("Select at least one tool.", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }

                    if plannedDestinations.isEmpty {
                        Text("No destinations yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(plannedDestinations, id: \.path) { path in
                            let exists = FileManager.default.fileExists(atPath: path.path)
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: exists ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                                    .foregroundStyle(exists ? .orange : .green)
                                Text(path.path(percentEncoded: false))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            }
                        }
                        if destinationConflict && !overwrite {
                            Text("Some destinations already exist. Enable overwrite to continue.")
                                .foregroundStyle(.orange)
                        }
                    }
                }

                DisclosureGroup("Advanced options", isExpanded: $showAdvanced) {
                    Picker("Install mode", selection: $mode) {
                        Text("Hardlink").tag(SkillInstallMode.hardlink)
                        Text("Copy").tag(SkillInstallMode.copy)
                    }
                    Toggle("Overwrite existing skill", isOn: $overwrite)
                    TextField("source", text: $source)
                    TextField("risk", text: $risk)
                    TextField("date_added (YYYY-MM-DD)", text: $dateAdded)
                }

                Section("SKILL.md body") {
                    TextEditor(text: $content)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 180)
                }
            }

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                Button("Add Skill") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSave)
            }
        }
        .padding(16)
        .frame(minWidth: 700, minHeight: 760)
        .alert("Could not add skill", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private func save() {
        guard canSave else { return }

        do {
            let created = try store.addSkill(
                name: name,
                tools: Array(selectedTools),
                scope: scope,
                description: description,
                content: content,
                source: source.isEmpty ? nil : source,
                risk: risk.isEmpty ? nil : risk,
                dateAdded: dateAdded.isEmpty ? nil : dateAdded,
                overwrite: overwrite,
                mode: mode
            )
            if let first = created.first {
                store.toastPrimaryPath = first
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}
