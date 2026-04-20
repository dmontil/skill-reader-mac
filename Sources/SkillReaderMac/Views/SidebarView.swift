import SwiftUI

struct SidebarView: View {
    @Environment(SkillStore.self) private var store

    var body: some View {
        @Bindable var store = store

        VStack(spacing: 0) {
            HStack {
                Button {
                    NotificationCenter.default.post(name: .openAddSkillSheet, object: nil)
                } label: {
                    Label("New Skill", systemImage: "plus.circle.fill")
                        .fontWeight(.semibold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 10)

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

                Section("View") {
                    Toggle("Compact rows", isOn: $store.isCompactMode)
                    Toggle("Show description", isOn: $store.showDescriptionInList)
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
        }
        .background(Color.white.opacity(0.015))
        .environment(\.defaultMinListRowHeight, 30)
        .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
    }
}
