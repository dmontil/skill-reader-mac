import SwiftUI

struct ContentView: View {
    @Environment(SkillStore.self) private var store
    @State private var selectedEntry: SkillEntry?
    @State private var selectedProfile: ProfileEntry?
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @State private var showAddSheet = false
    @State private var showAddProfileSheet = false
    
    private var isSkillsMode: Bool { store.browserMode == .skills }
    private var searchPlaceholder: String { isSkillsMode ? "Search skills..." : "Search profiles..." }

    var body: some View {
        @Bindable var store = store

        ZStack {
            backgroundGradient

            VStack(spacing: 10) {
                topBar
                .padding(.horizontal, 18)
                .padding(.top, 8)

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
                    EmptyDetailView(message: "Select a skill to inspect it")
                }
            } else {
                if let profile = selectedProfile {
                    ProfileDetailView(profile: profile)
                } else {
                    EmptyDetailView(message: "Select a profile to inspect it")
                }
            }
        }
    }

    private func openComposer() {
        if isSkillsMode {
            showAddSheet = true
        } else {
            showAddProfileSheet = true
        }
    }
}

struct EmptyDetailView: View {
    var message: String = "Select a skill to inspect it"

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "book.closed")
                .font(.system(size: 48))
                .foregroundStyle(Color.white.opacity(0.35))
            Text(message)
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
