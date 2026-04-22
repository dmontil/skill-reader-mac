import Foundation

enum SkillInstallMode: String {
    case copy
    case hardlink
}

enum SkillScanner {

    // MARK: - Public

    static func scan(cwd: URL? = nil) -> [SkillEntry] {
        let cwd = cwd ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        var identityMap: [UInt64: [(tool: String, scope: String, project: String?, dir: URL)]] = [:]
        var entries: [SkillEntry] = []

        // --- Global SKILL.md-based paths ---
        for (tool, base) in globalSkillPaths() {
            guard isDirectory(base) else { continue }
            iterateDirs(in: base) { skillDir in
                let skillMd = skillDir.appendingPathComponent("SKILL.md")
                guard FileManager.default.fileExists(atPath: skillMd.path) else { return }
                let inode = self.inode(of: skillMd)
                identityMap[inode, default: []].append((tool, "global", nil, skillDir))
            }
        }

        // --- Project SKILL.md-based paths ---
        for (tool, rel) in projectSkillPaths {
            let base = cwd.appendingPathComponent(rel)
            guard isDirectory(base) else { continue }
            iterateDirs(in: base) { skillDir in
                let skillMd = skillDir.appendingPathComponent("SKILL.md")
                guard FileManager.default.fileExists(atPath: skillMd.path) else { return }
                let inode = self.inode(of: skillMd)
                identityMap[inode, default: []].append((tool, "project", cwd.lastPathComponent, skillDir))
            }
        }

        // Build skill entries
        for (inodeVal, occurrences) in identityMap {
            if let entry = buildSkillEntry(inode: inodeVal, occurrences: occurrences) {
                entries.append(entry)
            }
        }

        // --- Rule files (project-level, single files) ---
        for (tool, patterns) in projectRulePatterns {
            for pattern in patterns {
                let matches = glob(pattern: pattern, in: cwd)
                for fileURL in matches {
                    if let entry = buildRuleEntry(tool: tool, file: fileURL, project: cwd.lastPathComponent) {
                        entries.append(entry)
                    }
                }
            }
        }

        return entries.sorted { $0.name.lowercased() < $1.name.lowercased() }
    }

    // MARK: - Path tables

    static func globalSkillPaths() -> [(String, URL)] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let xdgConfig: URL = {
            if let v = ProcessInfo.processInfo.environment["XDG_CONFIG_HOME"] {
                return URL(fileURLWithPath: v)
            }
            return home.appendingPathComponent(".config")
        }()

        let paths: [(String, URL)] = [
            ("claude",   home.appendingPathComponent(".claude/skills")),
            ("windsurf", home.appendingPathComponent(".codeium/windsurf/skills")),
            ("kiro",     home.appendingPathComponent(".kiro/skills")),
            ("codex",    home.appendingPathComponent(".codex/skills")),
            ("cursor",   home.appendingPathComponent(".cursor/rules")),
            ("opencode", xdgConfig.appendingPathComponent("opencode/skills")),
        ]

        // macOS only: resolve first existing candidate for Windsurf/Cursor
        // (same logic as Python models.py candidate list)
        return paths
    }

    static let projectSkillPaths: [(String, String)] = [
        ("claude",   ".claude/skills"),
        ("windsurf", ".windsurf/skills"),
        ("kiro",     ".kiro/skills"),
        ("codex",    ".codex/skills"),
        ("cursor",   ".cursor/rules"),
        ("opencode", ".opencode/skills"),
    ]

    static let projectRulePatterns: [(String, [String])] = [
        ("cline",   [".clinerules", ".clinerules/*.md"]),
        ("zed",     [".rules"]),
        ("amp",     ["AGENTS.md"]),
        ("copilot", [".github/copilot-instructions.md", ".github/instructions/*.instructions.md"]),
        ("amazonq", [".amazonq/rules/*.md"]),
        ("aider",   ["CONVENTIONS.md"]),
    ]

    static var installableSkillTools: [String] {
        projectSkillPaths.map(\.0)
    }

    static func plannedDestinations(
        name: String,
        tools: [String],
        scope: String,
        cwd: URL? = nil
    ) throws -> [URL] {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return [] }
        let current = cwd ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let uniqueTools = OrderedSet(tools).elements
        return try uniqueTools.map { try destinationDir(tool: $0, scope: scope, cwd: current, skillName: cleanName) }
    }

    // MARK: - Install

    static func installSkill(
        name: String,
        tools: [String],
        scope: String,
        cwd: URL? = nil,
        description: String,
        content: String,
        source: String? = nil,
        risk: String? = nil,
        dateAdded: String? = nil,
        overwrite: Bool = false,
        mode: SkillInstallMode = .hardlink
    ) throws -> [URL] {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else {
            throw NSError(domain: "SkillReader", code: 1, userInfo: [NSLocalizedDescriptionKey: "Skill name cannot be empty."])
        }
        guard scope == "global" || scope == "project" else {
            throw NSError(domain: "SkillReader", code: 2, userInfo: [NSLocalizedDescriptionKey: "Scope must be global or project."])
        }
        guard !tools.isEmpty else {
            throw NSError(domain: "SkillReader", code: 3, userInfo: [NSLocalizedDescriptionKey: "Select at least one tool."])
        }

        let uniqueTools = OrderedSet(tools).elements
        let unsupported = uniqueTools.filter { !installableSkillTools.contains($0) }
        guard unsupported.isEmpty else {
            throw NSError(
                domain: "SkillReader",
                code: 4,
                userInfo: [NSLocalizedDescriptionKey: "Unsupported tool(s): \(unsupported.joined(separator: ", "))"]
            )
        }

        let current = cwd ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let destinations = try uniqueTools.map { try destinationDir(tool: $0, scope: scope, cwd: current, skillName: cleanName) }

        for dest in destinations {
            if FileManager.default.fileExists(atPath: dest.path) {
                if overwrite {
                    try FileManager.default.removeItem(at: dest)
                } else {
                    throw NSError(
                        domain: "SkillReader",
                        code: 5,
                        userInfo: [NSLocalizedDescriptionKey: "Destination already exists: \(dest.path(percentEncoded: false))"]
                    )
                }
            }
        }

        for dest in destinations {
            try FileManager.default.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
        }

        // Write source directory in a temporary location, then copy/hardlink into tool destinations.
        let tempRoot = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("skill-reader-\(UUID().uuidString)")
        let sourceDir = tempRoot.appendingPathComponent(cleanName, isDirectory: true)
        try FileManager.default.createDirectory(at: sourceDir, withIntermediateDirectories: true)
        let skillMD = sourceDir.appendingPathComponent("SKILL.md")
        try renderSkillMD(
            name: cleanName,
            description: description,
            content: content,
            source: source,
            risk: risk,
            dateAdded: dateAdded
        ).write(to: skillMD, atomically: true, encoding: .utf8)

        defer { try? FileManager.default.removeItem(at: tempRoot) }

        var created: [URL] = []
        for (idx, dest) in destinations.enumerated() {
            if idx == 0 || mode == .copy {
                try copyDirectory(from: sourceDir, to: dest)
            } else {
                do {
                    try hardlinkDirectory(from: sourceDir, to: dest)
                } catch {
                    try copyDirectory(from: sourceDir, to: dest)
                }
            }
            created.append(dest)
        }
        return created
    }

    static func updateMetadata(
        for entry: SkillEntry,
        description: String,
        source: String?,
        risk: String?,
        dateAdded: String?
    ) throws {
        guard let contentURL = entry.contentURL else {
            throw NSError(domain: "SkillReader", code: 8, userInfo: [NSLocalizedDescriptionKey: "No editable content found for this asset."])
        }

        let original = try String(contentsOf: contentURL, encoding: .utf8)
        let parsed = FrontmatterParser.parse(original)
        let updated = renderDocumentWithFrontmatter(
            name: entry.name,
            description: description,
            source: source,
            risk: risk,
            dateAdded: dateAdded,
            body: parsed.body.isEmpty ? original.trimmingCharacters(in: .whitespacesAndNewlines) : parsed.body
        )
        try updated.write(to: contentURL, atomically: true, encoding: .utf8)
    }

    // MARK: - Entry builders

    private static func buildSkillEntry(
        inode: UInt64,
        occurrences: [(tool: String, scope: String, project: String?, dir: URL)]
    ) -> SkillEntry? {
        guard let first = occurrences.first else { return nil }
        let skillMd = first.dir.appendingPathComponent("SKILL.md")
        guard let text = try? String(contentsOf: skillMd, encoding: .utf8) else { return nil }

        let fm = FrontmatterParser.parse(text)
        let attrs = (try? FileManager.default.attributesOfItem(atPath: skillMd.path)) ?? [:]
        let mtime = attrs[.modificationDate] as? Date ?? .distantPast
        let size = (attrs[.size] as? Int ?? 0)

        let tools = OrderedSet(occurrences.map(\.tool)).elements
        let paths = occurrences.map(\.dir)
        let scopes = OrderedSet(occurrences.map(\.scope)).elements
        let scope = scopes.count == 1 ? scopes[0] : "global+project"
        let project = occurrences.first(where: { $0.project != nil })?.project

        let symlink = (try? first.dir.resourceValues(forKeys: [.isSymbolicLinkKey]))?.isSymbolicLink ?? false

        return SkillEntry(
            name: fm.name ?? first.dir.lastPathComponent,
            tools: tools,
            scope: scope,
            project: project,
            paths: paths,
            description: fm.description ?? "",
            inode: inode,
            isHardlinked: tools.count > 1,
            isSymlink: symlink,
            sizeKB: Double(size) / 1024,
            entryType: .skill,
            modificationDate: mtime,
            source: fm.source,
            risk: fm.risk,
            dateAdded: fm.dateAdded
        )
    }

    private static func buildRuleEntry(tool: String, file: URL, project: String) -> SkillEntry? {
        guard let text = try? String(contentsOf: file, encoding: .utf8) else { return nil }
        let fm = FrontmatterParser.parse(text)
        let attrs = (try? FileManager.default.attributesOfItem(atPath: file.path)) ?? [:]
        let mtime = attrs[.modificationDate] as? Date ?? .distantPast
        let size = (attrs[.size] as? Int ?? 0)
        let rawName = file.deletingPathExtension().lastPathComponent.trimmingCharacters(in: CharacterSet(charactersIn: "."))
        let name = fm.name ?? rawName

        let description: String
        if let d = fm.description, !d.isEmpty {
            description = d
        } else {
            description = fm.body.components(separatedBy: "\n")
                .first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty &&
                                !$0.hasPrefix("#") && !$0.hasPrefix("---") }) ?? ""
        }

        let symlink = (try? file.resourceValues(forKeys: [.isSymbolicLinkKey]))?.isSymbolicLink ?? false

        return SkillEntry(
            name: name,
            tools: [tool],
            scope: "project",
            project: project,
            paths: [file],
            description: description,
            inode: self.inode(of: file),
            isHardlinked: false,
            isSymlink: symlink,
            sizeKB: Double(size) / 1024,
            entryType: .rule,
            modificationDate: mtime
        )
    }

    // MARK: - Helpers

    static func inode(of url: URL) -> UInt64 {
        // Use FileManager to avoid Swift's stat() / Darwin.stat naming ambiguity.
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        return (attrs?[.systemFileNumber] as? NSNumber)?.uint64Value ?? 0
    }

    private static func isDirectory(_ url: URL) -> Bool {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
    }

    private static func iterateDirs(in base: URL, action: (URL) -> Void) {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: base, includingPropertiesForKeys: nil, options: .skipsHiddenFiles
        ) else { return }
        for url in contents.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            // Use fileExists(isDirectory:) so symlinks to directories are followed
            guard isDirectory(url) else { continue }
            action(url)
        }
    }

    private static func glob(pattern: String, in base: URL) -> [URL] {
        let parts = pattern.components(separatedBy: "/")
        return expand(parts: parts, from: base)
    }

    private static func expand(parts: [String], from base: URL) -> [URL] {
        guard let first = parts.first else { return [base] }
        // Reject path traversal and absolute components
        guard !first.contains(".."), !first.hasPrefix("/") else { return [] }
        let rest = Array(parts.dropFirst())

        if first.contains("*") {
            // Wildcard: list directory and filter
            guard let contents = try? FileManager.default.contentsOfDirectory(
                at: base, includingPropertiesForKeys: nil, options: []
            ) else { return [] }
            let pattern = first
            return contents.filter { matches(name: $0.lastPathComponent, pattern: pattern) }
                           .flatMap { expand(parts: rest, from: $0) }
        } else {
            let next = base.appendingPathComponent(first)
            if rest.isEmpty {
                return FileManager.default.fileExists(atPath: next.path) ? [next] : []
            }
            return expand(parts: rest, from: next)
        }
    }

    private static func matches(name: String, pattern: String) -> Bool {
        // Simple * wildcard matching
        let regexPattern = "^" + NSRegularExpression.escapedPattern(for: pattern)
            .replacingOccurrences(of: "\\*", with: ".*") + "$"
        return (try? NSRegularExpression(pattern: regexPattern).firstMatch(
            in: name, range: NSRange(name.startIndex..., in: name)
        )) != nil
    }

    private static func destinationDir(tool: String, scope: String, cwd: URL, skillName: String) throws -> URL {
        let base: URL
        if scope == "global" {
            guard let entry = globalSkillPaths().first(where: { $0.0 == tool }) else {
                throw NSError(domain: "SkillReader", code: 6, userInfo: [NSLocalizedDescriptionKey: "Unknown tool: \(tool)"])
            }
            base = entry.1
        } else {
            guard let rel = projectSkillPaths.first(where: { $0.0 == tool })?.1 else {
                throw NSError(domain: "SkillReader", code: 7, userInfo: [NSLocalizedDescriptionKey: "Unknown tool: \(tool)"])
            }
            base = cwd.appendingPathComponent(rel)
        }
        return base.appendingPathComponent(skillName, isDirectory: true)
    }

    private static func copyDirectory(from src: URL, to dst: URL) throws {
        try FileManager.default.copyItem(at: src, to: dst)
    }

    private static func hardlinkDirectory(from src: URL, to dst: URL) throws {
        try FileManager.default.createDirectory(at: dst, withIntermediateDirectories: true)
        let contents = try FileManager.default.contentsOfDirectory(at: src, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
        for item in contents {
            let values = try item.resourceValues(forKeys: [.isDirectoryKey])
            let target = dst.appendingPathComponent(item.lastPathComponent)
            if values.isDirectory == true {
                try hardlinkDirectory(from: item, to: target)
            } else {
                do {
                    try FileManager.default.linkItem(at: item, to: target)
                } catch {
                    try FileManager.default.copyItem(at: item, to: target)
                }
            }
        }
    }

    private static func yamlLine(key: String, value: String?) -> String? {
        guard let value else { return nil }
        let cleaned = value.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }
        let escaped = cleaned
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\(key): \"\(escaped)\""
    }

    private static func renderSkillMD(
        name: String,
        description: String,
        content: String,
        source: String?,
        risk: String?,
        dateAdded: String?
    ) -> String {
        let templateBody = """
        ## Purpose
        Explain what this skill does and the outcome it should produce.

        ## When To Use
        - Trigger phrase 1
        - Trigger phrase 2

        ## Inputs
        - Input A
        - Input B

        ## Steps
        1. Step one.
        2. Step two.
        3. Step three.

        ## Output
        Describe the expected output format and quality bar.
        """

        var lines: [String] = ["---"]
        lines.append(yamlLine(key: "name", value: name) ?? "name: \"unnamed-skill\"")
        lines.append(yamlLine(key: "description", value: description) ?? "description: \"\"")
        if let line = yamlLine(key: "source", value: source) { lines.append(line) }
        if let line = yamlLine(key: "risk", value: risk) { lines.append(line) }
        if let line = yamlLine(key: "date_added", value: dateAdded) { lines.append(line) }
        lines.append("---")
        lines.append("")
        lines.append("# \(name)")
        lines.append("")
        let body = content.trimmingCharacters(in: .whitespacesAndNewlines)
        lines.append(body.isEmpty ? templateBody : body)
        lines.append("")
        return lines.joined(separator: "\n")
    }

    private static func renderDocumentWithFrontmatter(
        name: String,
        description: String,
        source: String?,
        risk: String?,
        dateAdded: String?,
        body: String
    ) -> String {
        var lines: [String] = ["---"]
        lines.append(yamlLine(key: "name", value: name) ?? "name: \"unnamed-skill\"")
        lines.append(yamlLine(key: "description", value: description) ?? "description: \"\"")
        if let line = yamlLine(key: "source", value: source) { lines.append(line) }
        if let line = yamlLine(key: "risk", value: risk) { lines.append(line) }
        if let line = yamlLine(key: "date_added", value: dateAdded) { lines.append(line) }
        lines.append("---")
        lines.append("")
        lines.append(body.trimmingCharacters(in: .whitespacesAndNewlines))
        lines.append("")
        return lines.joined(separator: "\n")
    }
}

// MARK: - OrderedSet helper (no extra dependency)

private struct OrderedSet<T: Hashable> {
    private(set) var elements: [T] = []
    private var seen: Set<T> = []

    init<S: Sequence>(_ sequence: S) where S.Element == T {
        for el in sequence { insert(el) }
    }

    mutating func insert(_ element: T) {
        if seen.insert(element).inserted { elements.append(element) }
    }

    func map<U>(_ transform: (T) -> U) -> [U] { elements.map(transform) }
}
