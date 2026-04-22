import Foundation

enum LibraryAssetSourceKind: String, Hashable {
    case library
    case detected
}

struct LibraryAssetEntry: Identifiable, Hashable {
    var kind: ProfileAssetKind
    var assetID: String
    var title: String
    var detail: String
    var sourceURL: URL
    var sourceKind: LibraryAssetSourceKind = .library

    var id: String { "\(kind.rawValue):\(assetID)" }
}
