# Boske Pulse

Mac menu bar app + desktop widget for monitoring Boske production on Hetzner.

**Boske operator tool** — not part of the Boske customer product and not a Canopy Studio consumer app.  
Standalone repo in the [boske-ai](https://github.com/boske-ai) org; disk home is `canopystudio/apps/boske-pulse` (sibling to `boske/`).

## Features (target)

- Live production health across Hetzner servers
- Coolify container status
- Hetzner VM metrics (CPU/RAM)
- Tailscale-backed private probes (licensing PG, internal services)
- macOS notifications + Telegram alerts
- Quick links: Coolify, Hetzner console, SSH

## Requirements

- macOS 14+ (Sonoma)
- Xcode 15+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)
- Tailscale on Mac and production servers

## Quick start

See **[LOCAL.md](./LOCAL.md)** for the full Mac setup guide.

```bash
cd ~/apps/canopystudio/apps/boske-pulse
make setup
open BoskePulse.xcodeproj
```

## Project structure

```
boske-pulse/
├── BoskePulseCore/          # Swift Package — models, engine, API clients, tests
├── BoskePulse/              # Menu bar app (SwiftUI)
├── BoskePulseWidget/        # WidgetKit extension
├── Config/                  # Non-secret topology (gitignored: boske-production.json)
├── project.yml              # XcodeGen
├── MANIFEST.md              # Operator-tool charter for agents/developers
└── README.md
```

## Configuration

Non-secret topology lives in `Config/boske-production.json` (copy from `.example`).  
Secrets (Coolify token, Hetzner token, Telegram bot token) → **Keychain only**.

## Development

```bash
make test    # swift test in BoskePulseCore
```

Core logic is testable without Xcode UI targets.

## Brand & distribution

| Aspect | Value |
|--------|-------|
| **Brand house** | Boske (operator tooling) |
| **GitHub** | `boske-ai/boske-pulse` (private v1; open-source candidate under **Boske Community**) |
| **Bundle ID** | `eu.canopystudio.boske.pulse` |
| **Audience** | Operators running Boske on Hetzner + Coolify |

## Work tracking

Ops plans and infra checklists live in the [boske](https://github.com/boske-ai/boske) monorepo under `docs/work/active/`.

## License

Internal operator use in v1. Planned open-source release (MIT) after scrubbing example topology — see [MANIFEST.md](./MANIFEST.md).
