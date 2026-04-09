import Foundation

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

        return SkillEntry(
            name: fm.name ?? first.dir.lastPathComponent,
            tools: tools,
            scope: scope,
            project: project,
            paths: paths,
            description: fm.description ?? "",
            inode: inode,
            isHardlinked: tools.count > 1,
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

        return SkillEntry(
            name: name,
            tools: [tool],
            scope: "project",
            project: project,
            paths: [file],
            description: description,
            inode: self.inode(of: file),
            isHardlinked: false,
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
            at: base, includingPropertiesForKeys: [.isDirectoryKey], options: .skipsHiddenFiles
        ) else { return }
        for url in contents.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            guard (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else { continue }
            action(url)
        }
    }

    private static func glob(pattern: String, in base: URL) -> [URL] {
        let parts = pattern.components(separatedBy: "/")
        return expand(parts: parts, from: base)
    }

    private static func expand(parts: [String], from base: URL) -> [URL] {
        guard let first = parts.first else { return [base] }
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
