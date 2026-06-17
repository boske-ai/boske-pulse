# Boske Pulse

Mac menu bar app + desktop widget for monitoring Boske production on Hetzner.

**Operator tooling only** — not part of the Boske customer product.  
Sibling repo to [`boske`](https://github.com/boske-ai/boske) under `src/`.

## Features (target)

- Live production health across 4 Hetzner servers
- Coolify container status (after search + LLM migration)
- Hetzner VM metrics (CPU/RAM)
- Tailscale-backed private probes (Postgres on `10.99.0.2:5433`)
- macOS notifications + Telegram alerts to phone
- Quick links: Coolify, Hetzner console, SSH

## Requirements

- macOS 14+ (Sonoma)
- Xcode 15+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)
- Tailscale on Mac and production servers (see plan in boske monorepo)

## Quick start

See **[LOCAL.md](./LOCAL.md)** for the full Mac handoff.

```bash
cd src/boske-pulse
cp Config/boske-production.example.json Config/boske-production.json
xcodegen generate
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
└── README.md
```

## Configuration

Non-secret topology lives in `Config/boske-production.json` (see `.example`).  
Secrets (Coolify token, Hetzner token, Telegram bot token) → **Keychain only**.

## Development

```bash
cd BoskePulseCore
swift test
```

Core logic is testable without Xcode UI targets.

## Work tracking

Plan and ops checklists live in the boske monorepo:

`docs/work/active/2026-06-17-boske-pulse/`

## License

Same operator/internal use as Boske — not distributed to end users in v1.
