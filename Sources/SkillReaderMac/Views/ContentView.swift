import SwiftUI

struct ContentView: View {
    @Environment(SkillStore.self) private var store
    @State private var selectedEntry: SkillEntry?
    @State private var selectedProfile: ProfileEntry?
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @State private var showAddSheet = false
    @State private var showAddProfileSheet = false
    @State private var showHealthSheet = false
    
    private var isSkillsMode: Bool { store.browserMode == .skills }
    private var searchPlaceholder: String { isSkillsMode ? "Search skills..." : "Search profiles..." }
    private var isFirstRunEmpty: Bool { store.entries.isEmpty && store.profiles.isEmpty && !store.isScanning }

    var body: some View {
        @Bindable var store = store

        ZStack {
            backgroundGradient

            VStack(spacing: 10) {
                topBar
                .padding(.horizontal, 18)
                .padding(.top, 8)

                if isFirstRunEmpty {
                    quickStartBanner
                        .padding(.horizontal, 18)
                }

                splitView
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
                .padding(.horizontal, 14)
                .padding(.bottom, 12)
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                if store.isScanning {
                    ProgressView().scaleEffect(0.7)
                } else {
                    Button {
                        store.scan()
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .help("Refresh skills (⌘R)")
                }
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if let msg = store.toastMessage {
                HStack(spacing: 10) {
                    Text(msg)
                        .font(.callout)
                    if let path = store.toastPrimaryPath {
                        Button("Reveal") {
                            NSWorkspace.shared.activateFileViewerSelecting([path])
                        }
                    }
                    if store.canUndoDelete {
                        Button("Undo") {
                            store.restoreLastDeleted()
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(.regularMaterial, in: Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1))
                .padding(16)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddSkillSheet()
                .environment(store)
        }
        .sheet(isPresented: $showAddProfileSheet) {
            AddProfileSheet()
                .environment(store)
        }
        .sheet(isPresented: $showHealthSheet) {
            LibraryHealthSheet()
                .environment(store)
        }
        .onReceive(NotificationCenter.default.publisher(for: .openAddSkillSheet)) { _ in
            showAddSheet = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .openAddProfileSheet)) { _ in
            showAddProfileSheet = true
        }
        .onChange(of: store.entries) { _, newEntries in
            guard let selectedEntry else { return }
            self.selectedEntry = newEntries.first(where: { $0.name == selectedEntry.name })
        }
        .onChange(of: store.profiles) { _, newProfiles in
            guard let selectedProfile else { return }
            self.selectedProfile = newProfiles.first(where: { $0.name == selectedProfile.name })
        }
        .animation(.easeInOut(duration: 0.2), value: store.toastMessage != nil)
        .navigationTitle("Skill Reader")
        .toolbarTitleDisplayMode(.inline)
    }

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.02, green: 0.08, blue: 0.20),
                Color(red: 0.03, green: 0.05, blue: 0.12),
                Color(red: 0.01, green: 0.03, blue: 0.08),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var topBar: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField(searchPlaceholder, text: Binding(
                    get: { store.searchText },
                    set: { store.searchText = $0 }
                ))
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.blue.opacity(0.45), lineWidth: 1)
            )
            .frame(maxWidth: 440)

            Spacer()

            HStack(spacing: 8) {
                Picker("Browser Mode", selection: Binding(
                    get: { store.browserMode },
                    set: { store.browserMode = $0 }
                )) {
                    ForEach(BrowserMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)

                Button(action: openComposer) {
                    Image(systemName: "plus")
                }
                .help(isSkillsMode ? "New Skill" : "New Profile")

                Button {
                    store.restoreLastDeleted()
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                }
                .help("Undo last delete")

                Button {
                    showHealthSheet = true
                } label: {
                    Image(systemName: "stethoscope")
                }
                .help("Library health")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(0.8))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.14), lineWidth: 1))
        }
    }

    private var splitView: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView()
        } content: {
            if isSkillsMode {
                SkillListView(selectedEntry: $selectedEntry)
            } else {
                ProfileListView(selectedProfile: $selectedProfile)
            }
        } detail: {
            if isSkillsMode {
                if let entry = selectedEntry {
                    DetailView(entry: entry)
                } else {
                    EmptyDetailView(
                        mode: .skills,
                        suggestedProfiles: store.suggestedProfiles(),
                        onCreateSkill: { showAddSheet = true },
                        onCreateProfile: { showAddProfileSheet = true }
                    )
                }
            } else {
                if let profile = selectedProfile {
                    ProfileDetailView(profile: profile)
                } else {
                    EmptyDetailView(
                        mode: .profiles,
                        suggestedProfiles: store.suggestedProfiles(),
                        onCreateSkill: { showAddSheet = true },
                        onCreateProfile: { showAddProfileSheet = true }
                    )
                }
            }
        }
    }

    private var quickStartBanner: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Start with one reusable workflow")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.92))
                Text("Create a profile, add a few assets, then preview exactly what will be written into a project before applying it.")
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.68))
            }

            Spacer()

            HStack(spacing: 8) {
                Button("New Profile") {
                    showAddProfileSheet = true
                }
                .buttonStyle(.borderedProminent)

                Button("New Skill") {
                    showAddSheet = true
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    private func openComposer() {
        if isSkillsMode {
            showAddSheet = true
        } else {
            showAddProfileSheet = true
        }
    }
}

private struct LibraryHealthSheet: View {
    @Environment(SkillStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Library Health")
                .font(.title3)
                .fontWeight(.semibold)

            Text("A quick pass over reuse, adoption, and cleanup opportunities in your current library.")
                .foregroundStyle(.secondary)

            Form {
                Section("Summary") {
                    ForEach(store.healthSummary, id: \.label) { item in
                        HStack {
                            Label(item.label, systemImage: item.systemImage)
                            Spacer()
                            Text("\(item.value)")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Profiles to finish") {
                    if store.emptyProfiles.isEmpty {
                        Text("No empty profiles. Nice.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(store.emptyProfiles) { profile in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(profile.name)
                                Text(profile.description.isEmpty ? "No description yet." : profile.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                    }
                }

                Section("Orphaned assets") {
                    if store.orphanedEntries.isEmpty {
                        Text("Every asset is used by at least one profile.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(store.orphanedEntries.prefix(12)) { entry in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.name)
                                Text("\(entry.entryType == .skill ? "Skill" : "Rule") · \(entry.toolsDisplay)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if !entry.description.isEmpty {
                                    Text(entry.description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                            }
                        }
                    }
                }

                Section("High leverage assets") {
                    if store.highLeverageEntries.isEmpty {
                        Text("No standout assets yet. Reuse and viewing history will surface them here.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(store.highLeverageEntries.prefix(12)) { entry in
                            HStack(alignment: .top, spacing: 10) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.name)
                                    Text(entry.description.isEmpty ? entry.toolsDisplay : entry.description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("\(store.profilesUsing(entry).count) profiles")
                                        .font(.caption2)
                                        .foregroundStyle(.mint)
                                    Text("\(store.viewCount(for: entry)) views")
                                        .font(.caption2)
                                        .foregroundStyle(.orange)
                                }
                            }
                        }
                    }
                }
            }

            HStack {
                Spacer()
                Button("Close") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .frame(minWidth: 760, minHeight: 700)
    }
}

struct EmptyDetailView: View {
    enum Mode {
        case skills
        case profiles
    }

    let mode: Mode
    let suggestedProfiles: [ProfileEntry]
    let onCreateSkill: () -> Void
    let onCreateProfile: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: mode == .skills ? "book.closed" : "square.stack.3d.up")
                .font(.system(size: 48))
                .foregroundStyle(Color.white.opacity(0.35))

            VStack(spacing: 6) {
                Text(mode == .skills ? "Select a skill to inspect it" : "Select a profile to inspect it")
                    .foregroundStyle(.white.opacity(0.78))
                Text(mode == .skills
                     ? "Use this area to inspect metadata, content, related profiles, and usage signals."
                     : "Use this area to inspect composition, preview file writes, and apply profiles safely.")
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
            }

            HStack(spacing: 10) {
                Button("New Skill", action: onCreateSkill)
                    .buttonStyle(.bordered)
                Button("New Profile", action: onCreateProfile)
                    .buttonStyle(.borderedProminent)
            }

            if !suggestedProfiles.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Suggested profiles")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.78))
                    ForEach(suggestedProfiles.prefix(3)) { profile in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(profile.name)
                                .foregroundStyle(.white.opacity(0.88))
                            Text(profile.assetSummary.isEmpty ? profile.description : profile.assetSummary)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.55))
                                .lineLimit(2)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
                    }
                }
                .frame(maxWidth: 420)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
