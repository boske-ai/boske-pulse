# Setup

See **[LOCAL.md](./LOCAL.md)** for build and run on Mac.

## Repository

| Item | Value |
|------|-------|
| **GitHub** | [boske-ai/boske-pulse](https://github.com/boske-ai/boske-pulse) (private) |
| **Disk path** | `~/src/boske-pulse` |
| **Category** | Boske operator tool (not a Canopy Studio consumer app) |

## First-time remote (maintainers)

```bash
cd ~/src/boske-pulse
gh repo create boske-ai/boske-pulse --private --source=. --remote=origin --push
```

## Open-source checklist (later)

Before making the repo public under **Boske Community**:

- [ ] Replace real IPs/hostnames in `Config/boske-production.example.json` with placeholders
- [ ] Confirm no secrets in git history
- [ ] Add `LICENSE` (MIT)
- [ ] Document on `example.dev` / Boske Community docs
