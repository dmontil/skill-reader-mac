import Foundation

struct Frontmatter {
    var name: String?
    var description: String?
    var source: String?
    var risk: String?
    var dateAdded: String?
    var body: String = ""
}

enum FrontmatterParser {
    /// Parse a SKILL.md file. Frontmatter is delimited by `---` lines.
    static func parse(_ text: String) -> Frontmatter {
        var fm = Frontmatter()
        let lines = text.components(separatedBy: "\n")
        guard lines.first?.trimmingCharacters(in: .whitespaces) == "---" else {
            fm.body = text
            return fm
        }

        var inFrontmatter = true
        var fmLines: [String] = []
        var bodyLines: [String] = []

        for line in lines.dropFirst() {
            if inFrontmatter {
                if line.trimmingCharacters(in: .whitespaces) == "---" {
                    inFrontmatter = false
                } else {
                    fmLines.append(line)
                }
            } else {
                bodyLines.append(line)
            }
        }

        fm.body = bodyLines.joined(separator: "\n").trimmingCharacters(in: .newlines)
        parseFrontmatterLines(fmLines, into: &fm)
        return fm
    }

    private static func parseFrontmatterLines(_ lines: [String], into fm: inout Frontmatter) {
        var currentKey: String?
        var currentValue: String = ""

        func flush() {
            guard let key = currentKey else { return }
            let value = currentValue.trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            switch key {
            case "name":        fm.name = value
            case "description": fm.description = value
            case "source":      fm.source = value
            case "risk":        fm.risk = value
            case "date_added":  fm.dateAdded = value
            default: break
            }
            currentKey = nil
            currentValue = ""
        }

        for line in lines {
            if let colonIdx = line.firstIndex(of: ":") {
                let key = String(line[..<colonIdx]).trimmingCharacters(in: .whitespaces).lowercased()
                let val = String(line[line.index(after: colonIdx)...]).trimmingCharacters(in: .whitespaces)
                flush()
                currentKey = key
                currentValue = val
            } else if line.hasPrefix("  ") || line.hasPrefix("\t") {
                // Continuation line for multi-line values
                currentValue += " " + line.trimmingCharacters(in: .whitespaces)
            }
        }
        flush()
    }
}
