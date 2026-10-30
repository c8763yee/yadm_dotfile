---
name: failure-to-eval
description: Convert an evidenced, reusable AI or engineering failure into a minimal regression check. Use only after a material reproducible failure, not on routine test failures.
---

# Failure -> durable regression evidence

Precondition: a real failure, a reproducer or trustworthy trace, and a reason
its recurrence matters. A speculative issue is not a captured failure.

1. Identify the failing invariant, affected project and actual evidence.
   Distinguish VERIFIED from HYPOTHESIS and NOT RUN.
2. Check for an existing equivalent test or Pensieve decision/maxim. If it
   exists, improve it instead of creating a duplicate.
3. Route by enforcement: prefer executable tests/static checks for mechanically
   detectable failures; a project contract for project-specific invariants;
   Pensieve decision/knowledge for reusable reasoning; a Skill only for a
   genuine repeatable multi-step procedure. Do not create a Skill per bug.
4. Add the smallest fixture that fails before the fix and passes afterward
   when feasible. Preserve reproduction commands, expected/actual results
   and risk scope. In this yadm repo, refer to
   `~/.config/yadm/agent/evals/README.md` for the record convention.
5. Validate the new check; if it cannot run, label NOT RUN and do not claim
   the regression is covered.

Do not launch a new agent, record unverified speculation as a rule, expand
scope to unrelated files, or automatically promote project rules to User scope.
