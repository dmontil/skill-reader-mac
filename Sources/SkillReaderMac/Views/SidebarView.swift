import SwiftUI

struct SidebarView: View {
    @Environment(SkillStore.self) private var store

    var body: some View {
        @Bindable var store = store

        List(selection: Binding(
            get: { store.filterTool },
            set: { store.filterTool = $0 }
        )) {
            // All
            Section {
                Label("All Skills & Rules", systemImage: "tray.2.fill")
                    .tag(String?.none)
            }

            // Type filter
            Section("Type") {
                Button {
                    store.filterType = store.filterType == .skill ? nil : .skill
                } label: {
                    HStack {
                        Label("Skills", systemImage: "sparkles")
                        Spacer()
                        if store.filterType == .skill {
                            Image(systemName: "checkmark").foregroundStyle(Color.accentColor)
                        }
                        Text("\(store.totalSkills)").foregroundStyle(.secondary).font(.caption)
                    }
                }
                .buttonStyle(.plain)

                Button {
                    store.filterType = store.filterType == .rule ? nil : .rule
                } label: {
                    HStack {
                        Label("Rules", systemImage: "doc.text")
                        Spacer()
                        if store.filterType == .rule {
                            Image(systemName: "checkmark").foregroundStyle(Color.accentColor)
                        }
                        Text("\(store.totalRules)").foregroundStyle(.secondary).font(.caption)
                    }
                }
                .buttonStyle(.plain)
            }

            // Tools
            Section("Tools") {
                ForEach(allTools, id: \.id) { tool in
                    let count = store.countsByTool[tool.id] ?? 0
                    if count > 0 {
                        HStack {
                            Label(tool.displayName, systemImage: tool.icon)
                            Spacer()
                            Text("\(count)")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                        .tag(Optional(tool.id))
                    }
                }
            }

            // Scope
            Section("Scope") {
                Button {
                    store.filterScope = store.filterScope == "global" ? nil : "global"
                } label: {
                    HStack {
                        Label("Global", systemImage: "globe")
                        Spacer()
                        if store.filterScope == "global" {
                            Image(systemName: "checkmark").foregroundStyle(Color.accentColor)
                        }
                    }
                }
                .buttonStyle(.plain)

                Button {
                    store.filterScope = store.filterScope == "project" ? nil : "project"
                } label: {
                    HStack {
                        Label("Project", systemImage: "folder")
                        Spacer()
                        if store.filterScope == "project" {
                            Image(systemName: "checkmark").foregroundStyle(Color.accentColor)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
    }
}
