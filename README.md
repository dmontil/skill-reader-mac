# Skill Reader for macOS

Native macOS app to manage AI agent skills — companion to the [skill-reader CLI](https://github.com/dmontil/skill-reader).

## Features

- **Three-column layout** — sidebar filters, skills table, detail panel
- **Menu bar companion** — always-accessible, shows recently viewed and recently modified skills, quick search
- **Recent skills tracking** — by modification date and by in-app viewing history
- **Open in editor** — one click opens the SKILL.md in your default .md app (Typora, iA Writer, VS Code…)
- **Reveal in Finder** — jump to any skill directory instantly
- **Delete with confirmation** — handles hardlinked skills across tools safely
- **13 tools supported** — Claude, Windsurf, Kiro, Codex, Cursor, Open Code, Cline, Zed, Amp, GitHub Copilot, Amazon Q, Aider
- **Skills and rules** — SKILL.md-based skills and single-file rules (.clinerules, AGENTS.md, etc.)

## Requirements

- macOS 14 (Sonoma) or later
- Xcode 15+

## Setup

1. Clone the repo
2. Open `Package.swift` in Xcode
3. Select the `SkillReaderMac` scheme
4. Run (⌘R)

```bash
git clone https://github.com/dmontil/skill-reader-mac
cd skill-reader-mac
open Package.swift
```

## Coexists with the CLI

This app reads the same skill directories as the `skill-reader` CLI — they share no state and don't conflict. Use the CLI for scripting and agent integration, the app for browsing and editing.

## Architecture

```
Sources/SkillReaderMac/
├── SkillReaderMacApp.swift     # @main — WindowGroup + MenuBarExtra
├── Models/
│   ├── SkillEntry.swift        # Data model + tool metadata
│   └── SkillStore.swift        # @Observable state, scan, filter, recent
├── Scanner/
│   ├── SkillScanner.swift      # FileManager walk + inode hardlink detection
│   └── FrontmatterParser.swift # YAML frontmatter parser (no dependencies)
└── Views/
    ├── ContentView.swift        # NavigationSplitView root + toolbar
    ├── SidebarView.swift        # Tool/scope/type filters
    ├── SkillListView.swift      # Table with context menu
    ├── DetailView.swift         # Metadata + actions + file content
    └── MenuBarView.swift        # Menu bar popover
```

No third-party dependencies.
