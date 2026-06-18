# Boske Pulse

macOS menu bar application and desktop widget for monitoring Boske production on Hetzner and Coolify.

**Operator tooling** — not part of the Boske customer product or the Canopy Studio consumer app line.  
Repository: [github.com/boske-ai/boske-pulse](https://github.com/boske-ai/boske-pulse)

## Overview

Boske Pulse provides a local view of server health, container status, VM metrics, and private-network reachability. API credentials are stored in the macOS Keychain only.

Without configured tokens, the app runs public HTTP smoke checks defined in your config (the committed example uses placeholder URLs such as `example.dev`). Configure Coolify and Hetzner tokens in Settings to enable container status and host metrics.

## Capabilities

- Menu bar status item with health-colored icon and server tile popover
- Auto-discovery of hosts from Coolify and Hetzner APIs, merged with local config overlays
- Health checks: public HTTP probes, Coolify container status, optional Hetzner CPU/RAM/disk/network metrics
- Private probes over Tailscale (e.g. licensing PostgreSQL)
- Expandable server tiles with endpoints, domains, and containers; one-click copy for IP, SSH, and URLs
- Compact pinned panel and full dashboard window
- Settings for Coolify, Hetzner, and Telegram credentials (Keychain-backed)
- WidgetKit extension (small, medium, large) after first data sync
- Debounced macOS notifications and optional Telegram alerts

## Requirements

- macOS 14+ (Sonoma)
- Xcode 15+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) — `brew install xcodegen`
- Tailscale on the Mac (required for Coolify API access and private probes)

## Getting started

See [LOCAL.md](./LOCAL.md) for signing, credentials, and troubleshooting.

```bash
git clone git@github.com:boske-ai/boske-pulse.git
cd boske-pulse
make setup
open BoskePulse.xcodeproj
```

In Xcode, assign your Apple Developer team to both **BoskePulse** and **BoskePulseWidget**, then build and run (⌘R). The application is menu-bar-only and does not appear in the Dock.

```bash
make test    # BoskePulseCore unit tests
make build   # unsigned Debug build (renders icons)
```

To install a local build:

```bash
cp -R ~/Library/Developer/Xcode/DerivedData/BoskePulse-*/Build/Products/Debug/Boske\ Pulse.app /Applications/
```

Run `make build` first. The DerivedData path varies by machine.

## Repository layout

```
boske-pulse/
├── BoskePulseCore/          # Swift Package — engine, API clients, discovery, tests
├── BoskePulse/              # Menu bar app (SwiftUI) + Assets.xcassets
├── BoskePulseWidget/        # WidgetKit extension
├── Config/                  # Topology example (local boske-production.json is gitignored)
├── scripts/                 # setup.sh, render-brand-icons.swift
├── project.yml              # XcodeGen
├── LOCAL.md                 # Mac setup guide
├── MANIFEST.md              # Operator-tool charter for agents/developers
└── README.md
```

## Configuration

| File | Purpose |
|------|---------|
| `Config/boske-production.example.json` | Committed template — overlays, probes, polling |
| `Config/boske-production.json` | Gitignored — local topology |
| `~/Library/Application Support/Boske Pulse/boske-production.json` | Runtime config (synced by `make setup`) |

Secrets do not belong in config or git. Store Coolify, Hetzner, and Telegram tokens in Keychain via Settings.

Discovery populates servers from the Coolify and Hetzner APIs. Use `serverOverlays` in config to add roles, health URLs, manual compose stacks, and private probes.

## Development

```bash
make test      # swift test — core logic, no Xcode UI required
make icons     # regenerate AppIcon + PulseLogo from scripts/render-brand-icons.swift
make generate  # xcodegen only
```

## Brand and distribution

| Aspect | Value |
|--------|-------|
| Brand house | Boske (operator tooling) |
| GitHub | [boske-ai/boske-pulse](https://github.com/boske-ai/boske-pulse) (public) |
| Bundle ID | `eu.canopystudio.boske.pulse` |
| Audience | Operators running Boske on Hetzner + Coolify |

## Work tracking

Active plan and checklist: `docs/work/active/2026-06-17-boske-pulse/`

Cross-repo infrastructure (Tailscale subnet routes, Coolify migration) is tracked in the [boske](https://github.com/boske-ai/boske) monorepo.

## License

[MIT License](./LICENSE) — Boske Community.
