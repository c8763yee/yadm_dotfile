# Adversarial Engineering Review

## Goal

Find falsifiable logic errors in a proposed engineering design **before implementation**.
This is adversarial verification, not GAN training or an instruction to disagree.

## When to review

The main agent SHOULD delegate a pre-implementation review for nontrivial changes to:
- Data structures, algorithms, ownership, or object lifetimes.
- Mutable state, state transitions, concurrency, or synchronization.
- Public APIs, ABIs, backwards compatibility, or userspace behavior.
- System architecture or changes whose correctness depends on an uncertain assumption.

Skip independent review for trivial, mechanical, or editorial changes unless explicitly requested.
A review must be proportional to the real risk.

## Main agent: prepare and delegate

Before editing implementation files, write a concise design brief:
1. Original requirements, non-goals, and current observable behavior.
2. Relevant source files and real call paths (identify what was actually inspected).
3. Data structures, their owners, and who may mutate each state.
4. Invariants, proposed state transitions, and lifecycle requirements.
5. Proposed change, assumptions, and compatibility constraints.
6. The smallest useful validation or regression tests.

Mark facts and assumptions separately.

Invoke the platform's `logic-adversary` subagent with the **original requirements**,
relevant repository context, and design brief. The reviewer should independently
derive the invariants before assessing the proposal. Do not present the main agent's
confidence or rationale as established evidence.

Wait for reviewer findings before implementing the proposed change.
If a subagent is unavailable, do a clearly labelled *self-review* instead;
never claim an independent review occurred.

## Reviewer: falsify, do not implement

The reviewer's responsibility is finding the **smallest concrete counterexample**
to an important assumption, not generating replacement code.

Review in this order:
1. **Data and ownership:** object identity, aliases, lifetime, mutable state, and ownership.
2. **Invariants:** preconditions, postconditions, state transitions, dynamic vs. fixed properties.
3. **Failure path:** minimal valid input, call path, or concurrent interleaving.
4. **Compatibility:** user-visible behavior, API/ABI, and dependencies.
5. **Complexity:** unnecessary branches, duplicated state, fallbacks, or abstraction.

Rules:
- Independently inspect available code/specifications; do not trust another agent's conclusions.
- A hypothetical failure is not a verified bug.
- Cite relevant paths/symbols and precisely distinguish code inspected from reasoning alone.
- Do not invent source locations, tests, execution results, or platform behavior.
- Do not edit files. Do not expand the task to unrelated stylistic improvements.
- Report **at most three** significant findings, ordered by severity.
- If no defensible defect is found, say: **No evidenced correctness issue found.**

### Reviewer result format

For each finding:
- **Status:** VERIFIED | HYPOTHESIS | NEEDS_EVIDENCE
- **Severity:** BLOCKER | MAJOR | MINOR
- **Broken assumption:** one precise claim
- **Evidence:** invariant, file/symbol, trace, or reproducible proof
- **Counterexample:** minimal valid failure scenario
- **Impact:** actual observable consequence
- **Verification:** smallest test or check that settles the claim

Always state material areas that were not verified.
VERIFIED requires concrete evidence, not just plausibility.

## Main agent: adjudicate and converge

For each significant finding explicitly choose:
- **ACCEPT:** evidence establishes a real violation; fix the faulty assumption.
- **REJECT:** evidence refutes it or it is outside the requested scope; explain why.
- **UNRESOLVED:** verify a material risk before relying on that assumption.

Never accept objections merely because they sound adversarial.
Keep responsibility for implementation and tests with the main agent.
Preserve existing behavior outside the requested scope.

Default limit: **one initial review and one targeted re-review after a material revision**.
Stop when no evidenced blocker remains, invariants have appropriate verification,
and remaining uncertainty is explicit. Do not loop over imaginary edge cases.
