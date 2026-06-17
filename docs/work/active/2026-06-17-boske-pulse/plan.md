# Plan: Boske Pulse v1

**Rule:** operator tooling only; not shipped in Boske desktop/website bundles.

---

## Phase P0 — Buildable on Mac (app) **← current**

- [x] Repo scaffold + `BoskePulseCore` with health rollup tests
- [x] `Config/boske-production.example.json` topology
- [x] `project.yml` + `make setup`
- [x] `PulseEngine` — public health, Coolify, Hetzner, private probes, alerts
- [x] Menu bar UI + Settings (Keychain) + WidgetKit extension
- [x] `swift test` green (ConfigLoader path fix)
- [x] `xcodegen generate` + **first successful `xcodebuild`**
- [ ] Code signing + App Group `group.eu.canopystudio.boske.pulse` on both targets
- [ ] Run on Mac — menu bar icon, first live public-health sync

**Quality gate:** `make test` passes; app launches; public endpoints show status without credentials.

---

## Phase P1 — Tailscale mesh (ops)

> Tracked in boske monorepo infra work. Pulse depends on this for Coolify + private probes.

### 1.1 Install on all Hetzner VMs

```bash
curl -fsSL https://tailscale.com/install.sh | sh
tailscale up --advertise-tags=tag:your-ops
```

### 1.2 Subnet routing on `example-website`

```bash
tailscale up --advertise-routes=10.99.0.0/16 --accept-routes
```

Approve `10.99.0.0/16` in Tailscale admin.

### 1.3 Mac

- Tailscale installed; same tailnet
- ACL: Mac → `tag:your-ops` ports 443, 5433, 8000

**Quality gate:** From Mac: `nc -zv 10.99.0.2 5433` succeeds; Coolify API on tailnet URL.

---

## Phase P2 — Coolify migration (ops)

| Server | Compose source (boske repo) |
|--------|----------------------------|
| `example-search-01` | `infra/docker/searxng/docker-compose.yml` |
| `example-llm-01` | `infra/docker/llm-proxy/` |

**Quality gate:** All four servers in Coolify API; smoke script passes.

---

## Phase P3 — Menu bar v1 (app)

### Data sources

| Source | Poll | Tailscale |
|--------|------|-----------|
| Public health URLs | 30s | No |
| Coolify API | 60s | Yes |
| Hetzner metrics | 120s | No |

### Health rules (smoke parity)

| Check | Green | Red |
|-------|-------|-----|
| `https://example.dev/` | HTTP 200 | else |
| `https://llm.example.dev/healthz` | body contains `"ok":true` | else |
| `https://search.example.dev/` | HTTP 200 | else |
| Coolify server | `is_reachable` | false |
| Critical containers | running + healthy | down |

### Remaining app work

- [x] Staggered polling intervals per source (10s tick; health 30s / Coolify 60s / Hetzner 120s)
- [x] Per-server Hetzner + Coolify links from config `links` block
- [x] Menu bar icon reflects `overall` + Tailscale state (wired — verify visually)
- [x] Error states when credentials missing (operator hints banner)

**Files:** `BoskePulseCore/Sources/**`, `BoskePulse/**`

---

## Phase P4 — Desktop widget (app)

- [x] App Group identifier in entitlements
- [x] `SnapshotStore` write from `AppModel`
- [x] WidgetKit reads snapshot
- [ ] Verify App Group container after signing
- [ ] Widget updates within 1 min of menu bar change

---

## Phase P5 — Alerts (app)

- [x] `AlertDebouncer` unit tests
- [x] macOS notification on alert + Telegram when configured
- [ ] Notification categories: `PRODUCTION_DOWN`, `SERVER_DEGRADED`, `DEPLOY_FAILED`
- [ ] Mute 1h action
- [ ] Telegram ack → suppress 30 min

**Quality gate:** Simulated failure → Mac + Telegram within 6 min; no flap spam &lt;2 min.

---

## Phase P6 — Private probes (app)

- [x] TCP probe via `PrivateNetworkProber`
- [x] Skipped state when Tailscale offline
- [ ] Licensing PG row visible in menu bar UI
- [ ] Degraded badge when Tailscale down (public checks only)

---

## Definition of done (v1)

- [ ] All four servers in Coolify; boske smoke script PASS
- [ ] Mac menu bar shows live status; Coolify/Hetzner/SSH links work
- [ ] Widget shows topology snapshot
- [ ] Telegram + macOS alert on sustained red
- [ ] Tokens only in Keychain
- [ ] Example config scrubbed before any public release

---

## Related (boske monorepo)

- `infra/HETZNER.md` — topology source of truth
- `tools/scripts/smoke/cloud-ai-prod-smoke.sh` — health parity reference
- `docs/work/active/2026-06-17-infra-reorg-and-scaling/` — Tailscale + Coolify ops
