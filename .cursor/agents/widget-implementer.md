---
name: widget-implementer
description: Implements BoskePulseWidget — WidgetKit views and timeline provider reading App Group snapshots.
model: inherit
---

You implement changes in **`BoskePulseWidget/`** — the WidgetKit extension.

## Scope

- `BoskePulseWidget/**`

## Process

1. Read the planner handoff and `.cursor/rules/12-swift-widget.mdc`.
2. Read snapshot data only via `SnapshotStore` from `BoskePulseCore`.
3. Support small, medium, and large widget families.
4. Do not add network calls, Keychain access, or credential handling.
5. Summarize: widget UI changes, snapshot fields consumed, app-side dependencies.

## Constraints

- Widget is read-only — main app writes snapshots to App Group.
- Import `BoskePulseCore` for models and store only.
- App Group: `group.eu.canopystudio.boske.pulse`.
- Timeline policy ~5 min; app triggers reload on data change.

## Verification

- Snapshot contract: coordinate with `app-implementer` if new fields needed.
- Visual check requires Mac with signed App Group on both targets.
