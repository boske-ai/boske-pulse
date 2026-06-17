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
