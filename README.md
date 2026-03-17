# MoleMac

A native macOS app wrapping [Mole](https://github.com/tw93/Mole) — the Mac system maintenance CLI — in a beautiful SwiftUI interface.

![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue) ![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange) ![Xcode 15+](https://img.shields.io/badge/Xcode-15%2B-blue)

## Features

| Section | What it does |
|---|---|
| **Dashboard** | Live overview — CPU, memory, disk, battery, temperature, top processes |
| **Status** | Full live metrics with gauges, disk breakdown, network I/O, thermal |
| **Clean** | Run `mo clean` with optional dry-run preview |
| **Analyze** | Run `mo analyze --json` to see disk usage |
| **Uninstall** | Remove apps and their hidden remnants |
| **Optimize** | Rebuild databases, clear DNS cache, refresh launch services |
| **Purge** | Remove `node_modules`, build artifacts, dev junk |

## Requirements

- macOS 13.0 (Ventura) or later
- Xcode 15 or later
- [Mole CLI](https://github.com/tw93/Mole) installed

## Install Mole

```bash
curl -fsSL https://raw.githubusercontent.com/tw93/Mole/main/install.sh | sh
```

Verify: `mo --version`

## Build & Run

1. Clone this repo
2. Open `MoleMac.xcodeproj` in Xcode
3. Select **My Mac** as the run destination
4. Press **⌘R** to build and run

## How it works

MoleMac shells out to the `mo` CLI binary (searched in `$PATH`, `/usr/local/bin/mo`, `/opt/homebrew/bin/mo`).

- **Dashboard & Status** — calls `mo status --json` every 2–4 seconds and renders the parsed JSON as native SwiftUI views
- **Clean / Uninstall / Optimize / Purge** — runs the relevant `mo` subcommand and streams its output into a terminal-style text view
- **Dry Run toggle** — appends `--dry-run` so you can preview changes before committing

## Project structure

```
MoleMac/
├── MoleMacApp.swift       — @main entry point
├── ContentView.swift      — NavigationSplitView sidebar
├── DashboardView.swift    — Metric cards overview
├── StatusView.swift       — Live gauges & process table
├── CommandView.swift      — Generic command runner (clean/uninstall/…)
├── MoleRunner.swift       — Process execution + ANSI stripping
├── StatusModels.swift     — Codable structs for `mo status --json`
└── Assets.xcassets/       — App icon (add your own)
```

## Notes

- The app runs **without sandbox** so it can launch `mo` as a subprocess and access system paths
- All destructive operations (clean, uninstall, purge) default to **dry-run** mode for safety
- ANSI escape sequences from the CLI output are stripped automatically
