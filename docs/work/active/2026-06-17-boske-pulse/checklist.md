# Boske Pulse — active checklist

*Update as items complete. See [plan.md](./plan.md) for phase detail.*

## Today — P0 make it run

- [x] `make test` — all BoskePulseCore tests pass
- [x] `make setup` — xcodegen generates `BoskePulse.xcodeproj`
- [x] `xcodebuild` — BoskePulse scheme builds (Debug, unsigned)
- [ ] Xcode signing — set your Apple Developer team + App Group on app + widget targets
- [ ] Launch app — menu bar icon appears; public health syncs without tokens
- [ ] Settings — save Coolify/Hetzner tokens to Keychain (when Tailscale ready)

## Ops blockers (P1–P2)

- [ ] Tailscale on all 4 Hetzner VMs
- [ ] Subnet route `10.99.0.0/16` approved
- [ ] Coolify API reachable from Mac via tailnet
- [ ] Search + LLM migrated into Coolify

## App polish (P3–P6)

- [x] Staggered poll intervals (health 30s / Coolify 60s / Hetzner 120s)
- [x] Private probe row in menu for `example-data-01` PG
- [x] Notification categories + mute action
- [ ] Widget verified with signed App Group
- [ ] End-to-end alert test (sustained red → Mac + Telegram)

## Before OSS (later)

- [ ] Scrub real IPs from `Config/boske-production.example.json`
- [ ] Add MIT `LICENSE`
- [ ] Document under Boske Community on `example.dev`
