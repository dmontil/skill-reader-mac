import Foundation

enum BrowserMode: String, CaseIterable, Identifiable {
    case skills
    case profiles

    var id: String { rawValue }
    var title: String {
        switch self {
        case .skills: "Skills"
        case .profiles: "Profiles"
        }
    }
}

enum ProfileAssetKind: String, CaseIterable, Identifiable, Codable {
    case skill
    case rule
    case agents

    var id: String { rawValue }
}

struct ProfileAsset: Identifiable, Hashable, Codable {
    var kind: ProfileAssetKind
    var assetID: String

    var id: String { "\(kind.rawValue):\(assetID)" }
}

struct ProfileTarget: Hashable, Codable {
    var mode: String = "project"
}

struct ProfileEntry: Identifiable, Hashable {
    var name: String
    var description: String
    var assets: [ProfileAsset]
    var targets: [String: ProfileTarget]
    var profileURL: URL

    var id: String { name }
    var targetsDisplay: String {
        let keys = targets.isEmpty ? ["codex", "claude", "cursor", "windsurf", "opencode"] : targets.keys.sorted()
        return keys.joined(separator: ", ")
    }
}
