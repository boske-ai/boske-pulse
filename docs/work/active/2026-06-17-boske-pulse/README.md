# Boske Pulse — Mac ops HUD for Hetzner + Coolify

**Status:** **in progress — execute [`plan.md`](./plan.md)**  
**Repo:** `boske-ai/boske-pulse`

---

## What this is

**Boske Pulse** is an **operator tool**: Mac menu bar app + desktop widget for live production health across Hetzner hosts — Coolify containers, Hetzner metrics, Tailscale private probes, macOS + Telegram alerts.

Not a Boske customer feature. Not a Canopy Studio consumer app.

---

## Locked decisions (2026-06-17)

| # | Decision |
|---|----------|
| 1 | Menu bar **and** WidgetKit desktop widget |
| 2 | Onboard application hosts into **Coolify** (one API for container status) |
| 3 | **Tailscale** mesh — Mac reaches private CIDR and Coolify API without public exposure |
| 4 | **macOS notifications** + **Telegram** on sustained degradation (5 min debounce) |
| 5 | Standalone Swift repo under `boske-ai`; MIT under **Boske Community** |

---

## Architecture

```
Mac (Boske Pulse)
  ├─ public health     → URLs from boske-production.json
  ├─ Coolify API       → via Tailscale
  ├─ Hetzner Cloud API → VM metrics (read-only token)
  ├─ private probes    → TCP checks on private IPs via Tailscale subnet route
  └─ alerts            → UserNotifications + Telegram bot

Coolify (typical layout)
  ├─ website host      marketing / static sites
  ├─ data host         databases + internal services
  ├─ search host       search stack compose
  └─ llm host          inference proxy compose
```

---

## Phases (summary)

| Phase | Scope | Owner | Status |
|-------|-------|-------|--------|
| P0 | Scaffold + core tests + first Mac build | app | **active** |
| P1 | Tailscale on all boxes + subnet route | ops | pending |
| P2 | Coolify migration (search + LLM) | ops | pending |
| P3 | Menu bar v1 — live health rollup | app | partial (engine wired) |
| P4 | WidgetKit + App Group snapshot sync | app | partial (widget reads snapshot) |
| P5 | Alerts — debounce, Telegram, macOS categories | app | partial |
| P6 | Private DB probe when Tailscale up | app | partial |

Detail: [`plan.md`](./plan.md) · daily: [`checklist.md`](./checklist.md)

---

## Security

- API tokens in **Keychain** only (Coolify bearer, Hetzner read-only, Telegram bot).
- Pulse is **read-only** — no deploy/restart from v1.
- Never surface Coolify env vars or third-party API keys.
- Coolify dashboard optionally **Tailscale-only**.
