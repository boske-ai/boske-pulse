# Local setup (Mac)

## One command

```bash
cd ~/src/boske-pulse
make setup
open BoskePulse.xcodeproj
```

`make setup` copies `Config/boske-production.json` from the example if missing, runs `xcodegen`, and bundles config into the app.

## Clone (new machine)

```bash
cd ~/src
git clone git@github.com:boske-ai/boske-pulse.git
cd boske-pulse
```

## Prerequisites

```bash
xcode-select --install          # if needed
brew install xcodegen tailscale
```

## Build + run

```bash
make setup                      # config + xcodegen
open BoskePulse.xcodeproj
```

In Xcode:

1. Run `make setup` first — regenerates the Xcode project.
2. Open `BoskePulse.xcodeproj` → select **BoskePulse** target → **Signing & Capabilities**:
   - ✅ Automatically manage signing
   - Team: **your Apple Developer team**
3. Repeat for **BoskePulseWidget** target (widget extensions need their own profile).
4. Ensure **App Groups** shows `group.eu.canopystudio.boske.pulse` on **both** targets. Xcode creates it on first successful sign if missing.
5. **Run** (⌘R) — menu bar icon top-right (no Dock icon)

If Xcode says the Mac isn't registered: **Product → Run** once; Xcode registers the device automatically. Or Xcode → Settings → Accounts → your Apple ID → **Download Manual Profiles**.

```bash
make test                       # swift test in BoskePulseCore
```

## Credentials

**Boske Pulse → Settings** (⌘,):

| Field | Value |
|-------|--------|
| Coolify base URL | Tailscale URL, e.g. `http://100.x.x.x:8000` |
| Coolify API token | Coolify → Keys / API |
| Hetzner token | Read-only Cloud API token |
| Telegram | Bot token + chat ID (optional) |

**Save to Keychain** — tokens never touch disk as plaintext.

## What you need to provide

Boske Pulse does **not** use `.env` files or a Qlify API. Integrations are **Coolify** (self-hosted PaaS), **Hetzner Cloud**, **Tailscale**, and optional **Telegram**.

| # | What | Where to get it | Required for |
|---|------|-----------------|--------------|
| 1 | **Coolify base URL** | Tailscale IP of your Coolify host, e.g. `http://100.x.x.x:8000` | Container status |
| 2 | **Coolify API token** | Coolify dashboard → **Keys / API** → create token | Container status |
| 3 | **Hetzner read-only token** | [Hetzner Cloud Console](https://console.hetzner.cloud/) → Security → API tokens (read-only) | CPU/RAM metrics |
| 4 | **Tailscale on Mac** | Same tailnet as production VMs | Coolify API + private probes (`10.99.0.2:5433`) |
| 5 | **Telegram bot token** (optional) | [@BotFather](https://t.me/BotFather) | Phone alerts |
| 6 | **Telegram chat ID** (optional) | Message your bot, then `https://api.telegram.org/bot<token>/getUpdates` | Phone alerts |

**Works without any tokens:** public health checks (`example.dev`, `app.example.dev`, `search.example.dev`, `llm.example.dev`).

**Ops prerequisites** (outside this repo — tracked in the boske monorepo):

- Tailscale on all 4 Hetzner VMs + subnet route `10.99.0.0/16` approved
- Search + LLM servers migrated into Coolify (so all 4 appear in the Coolify API)

Use **Settings → Test Coolify / Test Hetzner** after saving credentials to verify connectivity before relying on the menu bar sync.

## Desktop widget

After first successful sync:

1. Right-click desktop → **Edit Widgets**
2. Add **Boske Pulse** (small / medium / large)

## Local dev order

| Step | What |
|------|------|
| A | `make setup && make test` |
| B | Run app — public health (example.dev, llm, search) |
| C | Settings → Coolify + Hetzner tokens |
| D | Tailscale on Mac + servers |
| E | Coolify migration (search + LLM) — see boske infra plans |
| F | Telegram alerts |

## Troubleshooting

| Issue | Fix |
|-------|-----|
| Red config error in menu | Run `make setup` from repo root |
| No menu bar icon | It's menu-bar-only (`LSUIElement`); check top-right |
| Widget empty | Run app once; verify App Group signing on both targets |
| Tailscale offline | `tailscale status` — install CLI via Tailscale app |
| Coolify 401 | Regenerate API token; use tailnet URL |
