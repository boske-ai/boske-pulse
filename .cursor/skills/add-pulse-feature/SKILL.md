---
name: add-pulse-feature
description: End-to-end workflow for adding a Boske Pulse feature across core, app, and widget modules.
---

# Add Pulse Feature

Structured workflow for multi-module Boske Pulse features.

## 1. Plan

Use the **planner** subagent (`.cursor/agents/planner.md`):

- Read `docs/work/active/2026-06-17-boske-pulse/plan.md` for phase context.
- Identify affected modules and files.
- Confirm guardrails (no secrets in git).

## 2. Implement (in order)

1. **Core** (`core-implementer`) — models, engine logic, API clients, unit tests.
2. **App** (`app-implementer`) — UI wiring, AppModel, Keychain if needed.
3. **Widget** (`widget-implementer`) — only if new snapshot fields need display.

Run `make test` after core changes.

## 3. Verify

Use the **verifier** subagent:

- Tests green
- Guardrails clean
- Module boundaries respected

## 4. Config changes

If the feature needs new config fields:

- Update `Models.swift` + `ConfigLoader`
- Update `Config/boske-production.example.json` with placeholders only
- Add `ConfigLoaderTests` coverage

## Common patterns

| Feature type | Primary module |
|--------------|----------------|
| New health check | Core (`HealthProber`, `PulseEngine`) |
| New API source | Core (client + discovery) |
| Dashboard tile | App (views) + possibly Core (snapshot fields) |
| Widget display | Widget + App (snapshot write) |
| Alert rule | Core (`AlertDebouncer`, `TelegramNotifier`) |
