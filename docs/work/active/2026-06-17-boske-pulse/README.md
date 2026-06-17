# Boske Pulse — Mac ops HUD for Hetzner production

**Status:** **in progress — execute [`plan.md`](./plan.md)**  
**Repo:** `boske-ai/boske-pulse` · disk: `~/src/boske-pulse`

Cross-repo infra context (Tailscale, Coolify migration) stays in [`boske`](https://github.com/boske-ai/boske) under `docs/work/active/2026-06-17-infra-reorg-and-scaling/` and `infra/HETZNER.md`.

---

## What this is

**Boske Pulse** is a Boske **operator tool**: Mac menu bar app + desktop widget for live production health across Hetzner boxes — Coolify containers, Hetzner metrics, Tailscale private probes, macOS + Telegram alerts.

Not a Boske customer feature. Not a Canopy Studio consumer app.  
Not **Boske Labs** (in-product agent packs in `apps/backend/config/labs/`).

---

## Locked decisions (2026-06-17)

| # | Decision |
|---|----------|
| 1 | Menu bar **and** WidgetKit desktop widget |
| 2 | Onboard `example-search-01` + `example-llm-01` into **Coolify** (one API for all containers) |
| 3 | **Tailscale** mesh — Mac reaches `10.99.0.0/16` and Coolify API without public exposure |
| 4 | **macOS notifications** + **Telegram** on sustained degradation (5 min debounce) |
| 5 | Standalone Swift repo under `boske-ai`; OSS later under **Boske Community** |

---

## Architecture

```
Mac (Boske Pulse)
  ├─ public health     → example.dev, llm.example.dev/healthz, search.example.dev
  ├─ Coolify API       → via Tailscale (example-website)
  ├─ Hetzner Cloud API → VM metrics (read-only token)
  ├─ private probes    → 10.99.0.2:5433 via Tailscale subnet route
  └─ alerts            → UserNotifications + Telegram bot

Coolify (after migration)
  ├─ example-website     website, app API
  ├─ example-data-01     Postgres + data stack
  ├─ example-search-01   searxng compose
  └─ example-llm-01      llm-proxy compose
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
| P6 | Private PG probe when Tailscale up | app | partial |

Detail: [`plan.md`](./plan.md) · daily: [`checklist.md`](./checklist.md)

---

## Security

- API tokens in **Keychain** only (Coolify bearer, Hetzner read-only, Telegram bot).
- Pulse is **read-only** — no deploy/restart from v1.
- Never surface Coolify env vars or `MISTRAL_API_KEY`.
- Coolify dashboard optionally **Tailscale-only**.
