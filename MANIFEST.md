# Boske Pulse — Tool Manifest

*For AI agents and developers.*

**Brand house:** Boske (operator tooling) · **Repository:** [github.com/boske-ai/boske-pulse](https://github.com/boske-ai/boske-pulse)

---

## Purpose

**Boske Pulse** is a macOS menu bar app + desktop widget for **operators** who run production workloads on Hetzner and Coolify. It surfaces server health, container status, VM metrics, and private-network probes — with macOS and Telegram alerts.

It is **not** a Boske customer feature and **not** a Canopy Studio consumer app.

---

## Trust moment

Operators need a fast, local view of production without opening five browser tabs. Tokens (Coolify, Hetzner, Telegram) must stay off disk; topology config may include internal IPs but must not embed secrets.

---

## What we build (and refuse)

| We build | We refuse |
|----------|-----------|
| Menu bar + widget health rollup | Shipping as part of a customer product SKU |
| Keychain-backed API credentials | Plaintext tokens in config or repo |
| Tailscale-aware private probes | Real production topology in committed examples |
| Swift Package core with unit tests | Coupling to any specific monorepo build |

---

## Data & privacy

| Aspect | Boske Pulse posture |
|--------|---------------------|
| **Audience** | Operators / infra maintainers |
| **Credentials** | Keychain only (Coolify, Hetzner, Telegram) |
| **Topology** | `Config/boske-production.json` (local, gitignored) |
| **Network** | Outbound to Hetzner API, Coolify API, public health URLs, Tailscale private IPs |
| **Bundle ID** | `eu.canopystudio.boske.pulse` |
| **Stack** | Swift / SwiftUI / WidgetKit / XcodeGen |
| **License** | MIT under **Boske Community** |

---

## Repo layout

| Location | Role |
|----------|------|
| `github.com/boske-ai/boske-pulse` | Canonical git remote |
| `docs/work/active/2026-06-17-boske-pulse/` | App phases, checklist |
| `Config/boske-production.example.json` | Committed schema template (placeholder topology) |

---

## Agent guardrails

- Do **not** commit `Config/boske-production.json` or API tokens.
- Do **not** add production hostnames, private IPs, or API keys to committed files.
- Keep `boske-production.example.json` generic so any operator can fork and adapt it.

---

## Configuration

1. Copy `Config/boske-production.example.json` → `Config/boske-production.json`.
2. Edit `serverOverlays` for your Coolify/Hetzner hostnames, health URLs, and private probes.
3. Store API tokens in Keychain via the app Settings UI.
