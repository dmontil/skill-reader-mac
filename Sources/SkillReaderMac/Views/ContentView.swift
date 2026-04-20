import SwiftUI

struct ContentView: View {
    @Environment(SkillStore.self) private var store
    @State private var selectedEntry: SkillEntry?
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @State private var showAddSheet = false

    var body: some View {
        @Bindable var store = store

        ZStack {
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

            VStack(spacing: 10) {
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField("Search skills...", text: $store.searchText)
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
                        Button {
                            showAddSheet = true
                        } label: {
                            Image(systemName: "plus")
                        }
                        .help("New Skill")

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
                .padding(.horizontal, 18)
                .padding(.top, 8)

                NavigationSplitView(columnVisibility: $columnVisibility) {
                    SidebarView()
                } content: {
                    SkillListView(selectedEntry: $selectedEntry)
                } detail: {
                    if let entry = selectedEntry {
                        DetailView(entry: entry)
                    } else {
                        EmptyDetailView()
                    }
                }
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
        .onReceive(NotificationCenter.default.publisher(for: .openAddSkillSheet)) { _ in
            showAddSheet = true
        }
        .animation(.easeInOut(duration: 0.2), value: store.toastMessage != nil)
        .navigationTitle("Skill Reader")
        .toolbarTitleDisplayMode(.inline)
    }
}

struct EmptyDetailView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "book.closed")
                .font(.system(size: 48))
                .foregroundStyle(Color.white.opacity(0.35))
            Text("Select a skill to inspect it")
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
