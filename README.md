# Skill Reader for macOS

Native macOS workspace for building, composing, previewing, and applying reusable AI agent workflows.

> **Two interfaces available:**
> - **macOS app (this repo)** — native SwiftUI app with menu bar extra, no Python required
> - **[Skill Reader CLI + TUI](https://github.com/dmontil/skill-reader)** — cross-platform command-line tool (macOS, Linux, Windows)

## Features

- **Three-column layout** — sidebar filters, skills table, detail panel
- **Profiles as reusable playbooks** — combine skills, rules, and guides into a repeatable workflow
- **Preview before apply** — inspect generated paths and managed files before materializing a profile
- **Apply to one target or all targets** — deploy the same profile to Codex, Claude, Cursor, Windsurf, and OpenCode
- **Asset recommendations** — get suggested library assets while creating a profile
- **Inline metadata editing** — update description, source, risk, and `date_added` without leaving the app
- **Library health checks** — spot orphaned assets, empty profiles, never-viewed items, and high-leverage assets
- **Menu bar companion** — always-accessible, shows recently viewed and recently modified skills, quick search
- **Recent skills tracking** — by modification date and by in-app viewing history
- **Open in editor** — one click opens the SKILL.md in your default .md app (Typora, iA Writer, VS Code…)
- **Reveal in Finder** — jump to any skill directory instantly
- **Delete with confirmation** — handles hardlinked skills across tools safely
- **Add skills from the app** — create and install new skills to one or more tools
- **13 tools supported** — Claude, Windsurf, Kiro, Codex, Cursor, Open Code, Cline, Zed, Amp, GitHub Copilot, Amazon Q, Aider
- **Skills and rules** — SKILL.md-based skills and single-file rules (.clinerules, AGENTS.md, etc.)

## Requirements

- macOS 14 (Sonoma) or later

## Install

### Option A — Download DMG (no Xcode needed)

1. Download **[Skill Reader.dmg](https://github.com/dmontil/skill-reader-mac/releases/latest)** from the latest release
2. Open it and drag **Skill Reader** → **Applications**

> First launch: if macOS shows a security warning, right-click the app → **Open**.
> The app is ad-hoc signed but not notarized.

### Option B — Build from source (Xcode required)

```bash
git clone https://github.com/dmontil/skill-reader-mac
cd skill-reader-mac
bash build-dmg.sh        # produces dist/Skill Reader.dmg
open "dist/Skill Reader.dmg"
```

Or install directly to `~/Applications`:

```bash
bash install.sh
```

To build the same drag-and-drop installer flow locally:

```bash
make dmg
open "dist/Skill Reader.dmg"
```

To generate a standalone `.app` bundle without the DMG:

```bash
make app
open "dist/Skill Reader.app"
```

## Coexists with the CLI

This app uses the same profile storage, library layout, and project materialization format as the `skill-reader` CLI:

- `~/.skill-reader/profiles/<name>/profile.yaml`
- `~/.skill-reader/library/skills/<id>/...`
- `~/.skill-reader/library/rules/<id>.*`
- `~/.skill-reader/library/agents/<id>.md`
- `.skill-reader/applied-profiles/<tool>--<profile>.json`

Use the CLI for scripting and automation; use the app for browsing, composition, preview, and library maintenance.

## Scope and parity

Core profile behavior is intentionally aligned with the CLI:

- same profile storage and shared library layout
- same supported profile targets
- same project materialization format and manifest location

The app goes further on UX: recommendations, previews, multi-target apply, metadata editing, and library health views.

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
