# Boske Pulse

Mac menu bar app + desktop widget for monitoring Boske production on Hetzner and Coolify.

**Boske operator tool** — not part of the Boske customer product and not a Canopy Studio consumer app.  
Public repo: [github.com/boske-ai/boske-pulse](https://github.com/boske-ai/boske-pulse)

## What it does

- **Menu bar dashboard** — pulse icon with health-colored status; popover with server tiles
- **Auto-discovery** — hosts from Coolify + Hetzner, merged with config overlays
- **Health checks** — public HTTP probes, Coolify container status, optional Hetzner CPU/RAM/disk/net
- **Private probes** — Tailscale-backed TCP checks (e.g. Postgres)
- **Foldable detail** — expand tiles for endpoints, domains, containers; copy IP/SSH/URLs on click
- **Compact + full window** — pin a resizable panel or open the full dashboard
- **Settings** — Coolify / Hetzner / Telegram credentials in **Keychain only**
- **Desktop widget** — small / medium / large WidgetKit views after first sync
- **Alerts** — debounced macOS notifications + optional Telegram

Works **without tokens** for public smoke checks only (`example.dev`, `app.example.dev`, etc.). Add Coolify + Hetzner tokens in Settings for containers and metrics.

## Requirements

- macOS 14+ (Sonoma)
- Xcode 15+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) — `brew install xcodegen`
- Tailscale on Mac (for Coolify API + private probes)

## Quick start

See **[LOCAL.md](./LOCAL.md)** for signing, credentials, and troubleshooting.

```bash
git clone git@github.com:boske-ai/boske-pulse.git
cd boske-pulse
make setup          # config + xcodegen + app icons
open BoskePulse.xcodeproj
```

In Xcode: set **your Apple Developer team** on **BoskePulse** and **BoskePulseWidget**, then **Run** (⌘R). The app is menu-bar-only — look top-right for the pulse icon.

```bash
make test           # 58 unit tests in BoskePulseCore
make build          # unsigned Debug build (also renders icons)
```

Install locally:

```bash
cp -R ~/Library/Developer/Xcode/DerivedData/BoskePulse-*/Build/Products/Debug/Boske\ Pulse.app /Applications/
```

(Path varies; run `make build` first.)

## Project structure

```
boske-pulse/
├── BoskePulseCore/          # Swift Package — engine, API clients, discovery, tests
├── BoskePulse/              # Menu bar app (SwiftUI) + Assets.xcassets
├── BoskePulseWidget/        # WidgetKit extension
├── Config/                  # Topology example (local boske-production.json is gitignored)
├── scripts/                 # setup.sh, render-brand-icons.swift
├── project.yml              # XcodeGen
├── LOCAL.md                 # Full Mac setup guide
├── MANIFEST.md              # Operator-tool charter for agents/developers
└── README.md
```

## Configuration

| File | Purpose |
|------|---------|
| `Config/boske-production.example.json` | Committed template — overlays, probes, polling |
| `Config/boske-production.json` | **Gitignored** — your local topology |
| `~/Library/Application Support/Boske Pulse/boske-production.json` | Runtime config (synced by `make setup`) |

**Secrets never go in config or git.** Coolify token, Hetzner token, and Telegram bot token → **Keychain** via Settings.

Discovery fills in servers from Coolify/Hetzner APIs; `serverOverlays` in config add roles, health URLs, manual compose stacks, and private probes.

## Development

```bash
make test      # swift test — no Xcode UI required for core logic
make icons     # regenerate AppIcon + PulseLogo from scripts/render-brand-icons.swift
make generate  # xcodegen only
```

## Brand & distribution

| Aspect | Value |
|--------|-------|
| **Brand house** | Boske (operator tooling) |
| **GitHub** | [boske-ai/boske-pulse](https://github.com/boske-ai/boske-pulse) (public) |
| **Bundle ID** | `eu.canopystudio.boske.pulse` |
| **Audience** | Operators running Boske on Hetzner + Coolify |

## Work tracking

Active plan and checklist: `docs/work/active/2026-06-17-boske-pulse/`

Cross-repo infra (Tailscale subnet routes, Coolify migration) lives in the [boske](https://github.com/boske-ai/boske) monorepo.

## License

[MIT License](./LICENSE) — Boske Community.
