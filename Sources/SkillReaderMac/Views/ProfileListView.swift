import SwiftUI

struct ProfileListView: View {
    @Environment(SkillStore.self) private var store
    @Binding var selectedProfile: ProfileEntry?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Text("Name")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Assets")
                    .frame(width: 70, alignment: .leading)
                Text("Targets")
                    .frame(width: 110, alignment: .leading)
            }
            .font(.caption)
            .foregroundStyle(.white.opacity(0.65))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider().overlay(Color.white.opacity(0.08))

            if store.filteredProfiles.isEmpty && !store.isScanning {
                VStack(spacing: 10) {
                    Image(systemName: "square.stack.3d.up.slash")
                        .font(.system(size: 28))
                        .foregroundStyle(.white.opacity(0.35))
                    Text(store.profiles.isEmpty ? "No profiles found" : "No profiles match your search")
                        .foregroundStyle(.white.opacity(0.65))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(store.filteredProfiles) { profile in
                            ProfileRow(profile: profile, isSelected: selectedProfile?.id == profile.id)
                                .onTapGesture { selectedProfile = profile }
                        }
                    }
                    .padding(8)
                }
            }
        }
        .background(Color.white.opacity(0.015))
        .navigationSplitViewColumnWidth(min: 300, ideal: 380)
    }
}

private struct ProfileRow: View {
    let profile: ProfileEntry
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(profile.name)
                    .fontWeight(.medium)
                    .foregroundStyle(.white.opacity(0.95))
                Text(profile.description.isEmpty ? "No description" : profile.description)
                    .font(.caption2)
                    .lineLimit(1)
                    .foregroundStyle(.white.opacity(0.45))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text("\(profile.assets.count)")
                .frame(width: 70, alignment: .leading)
                .foregroundStyle(.white.opacity(0.78))

            Text("\(profile.targets.count)")
                .frame(width: 110, alignment: .leading)
                .foregroundStyle(.white.opacity(0.78))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.white.opacity(0.13) : Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.green.opacity(0.45) : Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }
}
