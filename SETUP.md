# Setup

See **[LOCAL.md](./LOCAL.md)** for build and run on Mac.

## Repository

| Item | Value |
|------|-------|
| **GitHub** | [boske-ai/boske-pulse](https://github.com/boske-ai/boske-pulse) (public) |
| **Category** | Operator tooling for Hetzner + Coolify monitoring |

## First-time clone

```bash
git clone git@github.com:boske-ai/boske-pulse.git
cd boske-pulse
make setup
```

Copy `Config/boske-production.example.json` to `Config/boske-production.json` (or run `make setup`, which does this automatically) and edit server overlays for your infrastructure.

## Release checklist

- [x] Replace real IPs/hostnames in `Config/boske-production.example.json` with placeholders
- [x] Add MIT `LICENSE`
- [ ] Confirm no secrets in git history (run `gitleaks detect` before tagging releases)
- [ ] Document under Boske Community
