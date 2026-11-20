# Adversarial Engineering Review

## Goal

Find falsifiable logic errors in a proposed engineering design **before implementation**.

## When to review

Follow the risk classification in `AGENTS.md`:
- Delegate a pre-implementation review for `CRITICAL` changes and nontrivial `STANDARD` changes involving ownership, object lifetimes, mutable state transitions, concurrency, or public API/ABI compatibility.
- Skip review for `FAST` (trivial, mechanical, or editorial) changes unless explicitly requested.

## Main agent: prepare and delegate

Before editing implementation files, write a concise design brief separating facts from assumptions:
1. **Scope & Current Behavior:** Original requirements, non-goals, and inspected files/call paths.
2. **State & Invariants:** Data structures, ownership, who mutates state, and compatibility constraints.
3. **Validation:** The smallest useful regression or verification test.

Invoke the platform's `logic-adversary` subagent with the original requirements, repository context, and design brief without presenting your confidence as evidence. Wait for findings before implementing. If `logic-adversary` is unavailable, perform a clearly labelled *Self-review* following the Reviewer section below.

## Reviewer: falsify, do not implement

Independently derive invariants from the original requirements and source code; do not treat the main agent's explanation as evidence or modify files. Check in order:
1. **Ownership & Invariants:** Object identity, aliases, lifetimes, preconditions, and state transitions.
2. **Failure Path & Compatibility:** Minimal valid counterexample (input, call path, or interleaving) and user-visible API/ABI impact.
3. **Complexity:** Unnecessary branches, duplicated state, or speculative fallbacks.

### Reviewer output format

Report **at most three** significant findings ordered by severity (or state: **No evidenced correctness issue found**):
- **Status & Severity:** `VERIFIED | HYPOTHESIS | NEEDS_EVIDENCE` / `BLOCKER | MAJOR | MINOR`
- **Broken assumption & Counterexample:** Precise claim and minimal valid failure scenario with file/symbol evidence.
- **Impact & Verification:** Observable consequence and smallest check that settles the claim.
- **Unverified gaps & Risk opinion (optional):** Material areas not inspected, plus an advisory warning if the change exhibits `CRITICAL` risk characteristics.

## Main agent: adjudicate and converge

For each finding explicitly choose:
- **ACCEPT:** Evidence establishes a real violation; fix the faulty assumption.
- **REJECT:** Evidence refutes it or it is outside scope; explain why.
- **UNRESOLVED:** Verify a material risk before relying on that assumption.

Default limit: **one initial review and one targeted re-review after a material revision**. Stop when no evidenced blocker remains and invariants have verification.
