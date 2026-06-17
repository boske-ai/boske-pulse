# Boske Pulse — Tool Manifest

*For AI agents and developers.*

**Brand house:** Boske (operator tooling) · **Product charter:** [ABOUT_BOSKE.md](../boske/ABOUT_BOSKE.md) · **Studio layout:** [ARCHITECTURE.md](../../docs/ARCHITECTURE.md)

---

## Purpose

**Boske Pulse** is a macOS menu bar app + desktop widget for **operators** who run Boske production on Hetzner and Coolify. It surfaces server health, container status, VM metrics, and private-network probes — with macOS and Telegram alerts.

It is **not** a Boske customer feature and **not** a Canopy Studio consumer app (unlike Carnet, Murmur, etc.).

---

## Trust moment

Operators need a fast, local view of production without opening five browser tabs. Tokens (Coolify, Hetzner, Telegram) must stay off disk; topology config may include internal IPs but must not embed secrets.

---

## What we build (and refuse)

| We build | We refuse |
|----------|-----------|
| Menu bar + widget health rollup | Shipping as part of the Boske DMG or customer SKU |
| Keychain-backed API credentials | Plaintext tokens in config or repo |
| Tailscale-aware private probes | Public exposure of internal service details in OSS examples |
| Swift Package core with unit tests | Coupling to the Boske pnpm monorepo build |

---

## Data & privacy

| Aspect | Boske Pulse posture |
|--------|---------------------|
| **Audience** | Operators / infra maintainers only |
| **Credentials** | Keychain only (Coolify, Hetzner, Telegram) |
| **Topology** | `Config/boske-production.json` (local, gitignored) |
| **Network** | Outbound to Hetzner API, Coolify API, public health URLs, Tailscale private IPs |
| **Bundle ID** | `eu.canopystudio.boske.pulse` |
| **Stack** | Swift / SwiftUI / WidgetKit / XcodeGen |
| **License (v1)** | Private, internal operator use |
| **License (planned)** | MIT under **Boske Community** — not Boske Labs (Labs = model R&D) |

---

## Repo & disk layout

| Location | Role |
|----------|------|
| `~/apps/canopystudio/apps/boske-pulse/` | Local disk home (polyrepo sibling to `boske/`) |
| `github.com/boske-ai/boske-pulse` | Canonical git remote |
| `docs/work/active/2026-06-17-boske-pulse/` | This repo — app phases, checklist |
| `apps/boske/docs/work/active/` | Boske monorepo — infra ops (Tailscale, Coolify) |

---

## Agent guardrails

- Do **not** treat this as a Canopy Studio consumer app — no `STUDIO_MANIFEST.md` footer/copy requirements for end users.
- Do **not** move Swift code into `apps/boske/` monorepo unless explicitly requested (different stack).
- Do **not** commit `Config/boske-production.json` or API tokens.
- Before any public release: scrub `boske-production.example.json` of real production IPs.

---

## Open-source path

1. Private `boske-ai/boske-pulse` while topology examples may contain real infra hints.
2. Sanitize example config → add MIT `LICENSE`.
3. Publish under **Boske Community** (plugins, OSS tooling, docs) — not Boske Labs model namespace.
