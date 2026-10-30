# yadm_dotfile engineering contract

This contract belongs to the **dotfile repository only**, despite yadm using
`$HOME` as its Git worktree. It is not a User-scope engineering rule for
unrelated repositories.

## Ownership and behavior

- yadm tracks the **final $HOME target paths**. Bootstrap provisions external
  packages, users, services and integrations; it must not reintroduce generic
  config copy/symlink deployment.
- Preserve user files, existing local settings and yadm alternate classes.
  Do not silently overwrite foreign links or force a checkout during migration.
- HyDE-synchronized targets belong to HyDE, preserved extension points belong
  to yadm. Do not permit both to manage the same path.
- Bootstrap stages must propagate errors and may not report a skipped,
  unsupported desktop profile as a verified successful installation.
- Pensieve installs in User scope and only initializes a standalone project
  when the main agent follows the explicit global rule. Bootstrap and
  subagents must not initialize any project.
- Do not claim QEMU integration PASS solely because the QEMU process exited
  successfully. Tie results to guest-side assertions and tested source commit.
- All generated runtime state, credentials and machine-local settings must
  stay outside the tracked dotfiles.

## Verification and risk selection

`bash ~/.config/yadm/verify/run.sh --level quick` checks repository-level
syntax and diff hygiene. `--level standard` also runs the isolated
Pensieve / Antigravity / Harness scope tests. `--level critical` runs
those checks but returns NOT RUN (exit 2) for the manual QEMU integration
gate; choose the relevant case from `docs/QEMU_TESTING.md` explicitly.

FAST: editorial and mechanical changes, no observable behavior change.
STANDARD: scripts and ordinary settings changes.
CRITICAL: bootstrap ownership, alternate selection, data loss, security,
state transitions, verification scripts, or changes to this contract.
A one-line edit can be critical. Only invoke the existing
`logic-adversary` for the current pre-implementation risk; do not double
launch it at verification time.
