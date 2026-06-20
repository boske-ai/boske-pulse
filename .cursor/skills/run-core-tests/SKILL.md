---
name: run-core-tests
description: Run BoskePulseCore unit tests and report results. Use after core or config schema changes.
---

# Run Core Tests

Execute the Boske Pulse core test suite and report pass/fail.

## Steps

1. From repo root, run:

```bash
make test
```

Equivalent: `cd BoskePulseCore && swift test`

2. If tests fail, read the failure output and identify the offending test file.
3. Report:
   - Total tests run
   - Pass/fail count
   - Failing test names and error messages
   - Suggested fix location (file + test name)

## Notes

- Works on Linux cloud agents (no Xcode required).
- For UI or widget verification, note that macOS + Xcode is required separately.
