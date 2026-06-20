# Boske Pulse — Agent Brief

*Operator tooling for Hetzner + Coolify monitoring. Not a customer product.*

Read `MANIFEST.md` for the full charter. This file is the cross-tool spine for Cursor and other coding agents.

## Stack

| Layer | Path | Role |
|-------|------|------|
| Core engine | `BoskePulseCore/` | Swift Package — models, API clients, `PulseEngine`, tests |
| Menu bar app | `BoskePulse/` | SwiftUI + AppKit shell, Keychain, dashboard UI |
| Widget | `BoskePulseWidget/` | WidgetKit extension reading App Group snapshot |
| Config | `Config/` | JSON topology (example committed; local override gitignored) |
| Build | `project.yml`, `Makefile`, `scripts/` | XcodeGen, setup, icon rendering |

**Platform:** macOS 14+, Swift 5.9, SwiftUI, WidgetKit, no external SPM deps.

## Commands

```bash
make test      # swift test in BoskePulseCore (works on Linux cloud agents)
make setup     # macOS only — copy config, xcodegen, sync Application Support
make generate  # xcodegen only
make build     # macOS + Xcode — unsigned Debug build
make icons     # regenerate AppIcon + PulseLogo assets
```

Cloud agents can validate logic with `make test`. Full UI builds require a Mac with Xcode.

## Architecture

- **`PulseEngine`** (actor) orchestrates Coolify, Hetzner, public health, and private probes.
- **`AppModel`** polls the engine, writes `ProductionSnapshot` via `SnapshotStore` to App Group.
- **Widget** reads the same snapshot JSON from App Group.
- **Credentials** live in Keychain only — never in JSON or git.

## Guardrails (non-negotiable)

1. Do **not** commit `Config/boske-production.json`, API tokens, or `.env` secrets.
2. Do **not** add production hostnames, private IPs, or API keys to committed files.
3. Keep `Config/boske-production.example.json` generic with placeholder topology.
4. Prefer `BoskePulseCore` + unit tests for business logic; keep UI thin.
5. Match existing Swift conventions: actors for async engine code, protocols for test doubles.

## Work tracking

Active plan: `docs/work/active/2026-06-17-boske-pulse/`

## Agent stack

| Role | File | Scope |
|------|------|-------|
| Planner | `.cursor/agents/planner.md` | Break tasks into module-scoped steps |
| Core implementer | `.cursor/agents/core-implementer.md` | `BoskePulseCore/**` |
| App implementer | `.cursor/agents/app-implementer.md` | `BoskePulse/**` |
| Widget implementer | `.cursor/agents/widget-implementer.md` | `BoskePulseWidget/**` |
| Verifier | `.cursor/agents/verifier.md` | Tests + guardrail checks |

Rules in `.cursor/rules/` auto-attach by path. Skills in `.cursor/skills/` cover repeatable workflows.
