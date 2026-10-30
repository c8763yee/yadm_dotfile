---
name: harness-verify
description: Risk-scaled verification of changed code and configuration. Use after substantive changes to run relevant checks and report actual evidence; not for ordinary conversation.
---

# Verify changed behavior

1. Identify the requested behavior, changed files (including untracked files),
   observable dependencies, and any project verification contract. Use the
   original task and source, not another agent's assertion, as evidence.
2. Reuse the existing risk decision: FAST, STANDARD, or CRITICAL. This Skill
   does **not** independently launch an adversarial agent. For an unchanged
   design, do not repeat a completed review.
3. Read the smallest applicable verification entry point and execute it.
   For `yadm_dotfile`: `bash ~/.config/yadm/verify/run.sh --level quick`
   for FAST; `--level standard` for STANDARD. Use `--level critical`
   when comprehensive verification is requested; its manual QEMU gate reports
   NOT RUN rather than inventing a pass. For unrelated repos, run that repo's
   declared targeted checks rather than imposing yadm commands.
4. Review final diff, staged changes, and new files. A passing script only
   covers its asserted scope. A skipped or unavailable check is NOT RUN.
5. Return a compact result containing commands executed, exit status,
   PASS / FAIL / NOT RUN, affected behavior and unverified risks.

Never rewrite tests, disable checks, or reduce test coverage merely to obtain
a green result. Failures should be diagnosed, not silently downgraded.
No general claim of independent verification unless independently executed.
