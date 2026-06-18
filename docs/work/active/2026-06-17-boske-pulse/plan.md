# Plan: Boske Pulse v1

**Rule:** operator tooling only; not shipped in customer product bundles.

---

## Phase P0 — Buildable on Mac (app) **← current**

- [x] Repo scaffold + `BoskePulseCore` with health rollup tests
- [x] `Config/boske-production.example.json` topology (placeholder hosts)
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

> Pulse depends on Tailscale for Coolify API access and private probes.

### 1.1 Install on all VMs

```bash
curl -fsSL https://tailscale.com/install.sh | sh
tailscale up --advertise-tags=tag:your-ops
```

### 1.2 Subnet routing on the gateway host

```bash
tailscale up --advertise-routes=10.99.0.0/16 --accept-routes
```

Approve your private CIDR in Tailscale admin.

### 1.3 Mac

- Tailscale installed; same tailnet
- ACL: Mac → `tag:your-ops` ports 443, 5433, 8000 (adjust for your stack)

**Quality gate:** From Mac: private TCP probe succeeds; Coolify API reachable on tailnet URL.

---

## Phase P2 — Coolify migration (ops)

| Server role | Typical compose source |
|-------------|------------------------|
| Search host | Your search stack `docker-compose.yml` |
| LLM host | Your inference proxy compose |

**Quality gate:** All target hosts appear in Coolify API; smoke checks pass.

---

## Phase P3 — Menu bar v1 (app)

### Data sources

| Source | Poll | Tailscale |
|--------|------|-----------|
| Public health URLs | 30s | No |
| Coolify API | 60s | Yes |
| Hetzner metrics | 120s | No |

### Health rules

| Check | Green | Red |
|-------|-------|-----|
| Configured public URLs | HTTP 200 (or configured accept list) | else |
| LLM health endpoint | body contains expected substring | else |
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
- [x] Notification categories: `PRODUCTION_DOWN`, `SERVER_DEGRADED`, `DEPLOY_FAILED`
- [x] Mute 1h action
- [ ] Telegram ack → suppress 30 min

**Quality gate:** Simulated failure → Mac + Telegram within 6 min; no flap spam &lt;2 min.

---

## Phase P6 — Private probes (app)

- [x] TCP probe via `PrivateNetworkProber`
- [x] Skipped state when Tailscale offline
- [x] Private probe rows visible in menu bar UI
- [x] Degraded badge when Tailscale down (public checks only)

---

## Definition of done (v1)

- [ ] All target hosts in Coolify; smoke checks PASS
- [ ] Mac menu bar shows live status; Coolify/Hetzner/SSH links work
- [ ] Widget shows topology snapshot
- [ ] Telegram + macOS alert on sustained red
- [ ] Tokens only in Keychain
- [x] Example config uses placeholder topology only
