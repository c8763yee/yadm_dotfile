# Evidence-based failure records

Use `failure-to-eval` only after a *reproducible* and reusable failure. A
record should contain: ID, status (VERIFIED / HYPOTHESIS / NOT RUN), original
requirement, affected path or symbol, minimal reproduction, observed result,
expected invariant, regression command, and the fix that makes the check pass.

Prefer adding a test under `tests/`. This directory holds the rationale
behind any project-specific regression; it does not replace executable tests
or duplicate Pensieve's project knowledge.

## Known gaps (not PASS, not yet closed by this Harness)

- **YADM-GAP-001:** `tests/run-qemu-matrix.sh` currently records QEMU
  process exit separately but the case runner returns success without
  guest-assertion evidence. Needed: guest-side checks and a failure-sensitive
  case verdict tied to a tested revision. Status: **NOT RUN / OPEN**.
- **YADM-GAP-002:** Non-Arch Niri/Hyprland profile handling may skip the
  desktop installation rather than fail early, unlike the NEGATIVE contract
  in `docs/QEMU_TESTING.md`. Needed: an isolated negative-case regression
  and earlier profile validation. Status: **NOT RUN / OPEN**.

These are documented gaps, not regression tests that have passed. Do not
reinterpret the markers in the QEMU matrix as actual observed outcomes.
