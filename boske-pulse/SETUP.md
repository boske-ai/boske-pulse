See **[LOCAL.md](./LOCAL.md)** for the full Mac setup guide.

During initial scaffolding, `boske-pulse` lives inside the `boske` monorepo at `boske-pulse/`. Extract to a sibling repo before long-term development:

```bash
cd ~/apps/canopystudio/apps
cp -R boske/boske-pulse ./boske-pulse
cd boske-pulse
git init -b main && git add . && git commit -m "initial boske pulse"
gh repo create boske-ai/boske-pulse --private --source=. --push
```
