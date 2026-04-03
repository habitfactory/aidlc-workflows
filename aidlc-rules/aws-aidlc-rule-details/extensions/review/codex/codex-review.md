# Codex Review Rules

## Overview

These rules integrate OpenAI Codex as an independent reviewer within the AI-DLC workflow. Codex reviews provide a second-model perspective on design decisions and generated code, catching blind spots that a single model might miss.

**Platform Requirement**: This extension requires Claude Code with the Codex plugin installed. If the plugin is not available, all REVIEW rules are automatically N/A (not a blocking finding). The model MUST verify plugin availability by checking if `/codex:setup` has been run successfully before attempting any review.

**Enforcement**: Codex review findings are **advisory by default** — they are presented to the user for judgment but do NOT block stage progression. The user always decides whether to act on review findings.

### Advisory Review Finding Behavior

An **advisory review finding** means:
1. The finding MUST be listed in the stage completion message under a "Codex Review Findings" section with the REVIEW rule ID
2. The stage MUST still present the "Continue to Next Stage" option — reviews do not block progression
3. Each finding MUST include the Codex review summary and any specific concerns raised
4. The finding MUST be logged in `aidlc-docs/audit.md` with the REVIEW rule ID, summary, and stage context

If a REVIEW rule is not applicable to the current project or stage context, mark it as **N/A** in the compliance summary — no review is triggered.

### Plugin Availability Check

Before triggering any review, verify the Codex plugin is available:
1. Check if `/codex:review` is a recognized command
2. If the command is not available, mark all REVIEW rules as **N/A** with reason "Codex plugin not installed"
3. Log the skip in `aidlc-docs/audit.md`

---

## Rule REVIEW-01: Application Design Review

**Applies to**: Application Design stage (Inception phase) — Part 2 (Generation), after design artifacts are produced

**Mode**: Full only

**Rule**: After generating application design artifacts (`components.md`, `services.md`, `component-dependency.md`), trigger a Codex adversarial review to challenge design decisions before presenting the stage completion message to the user.

**Procedure**:
1. Ensure design artifacts are saved to `aidlc-docs/inception/application-design/`
2. Execute: `/codex:adversarial-review`
3. Wait for review completion (use `/codex:status` if running in background)
4. Retrieve results with `/codex:result` if needed
5. Include review findings in the stage completion message under "Codex Review Findings"

**Review Focus Areas**:
- Component boundaries and separation of concerns
- Service layer abstraction appropriateness
- Dependency direction and circular dependency risks
- Missing components or over-engineering
- Alternative architectural approaches worth considering

**Verification**:
- Codex adversarial review was executed after design generation
- Review findings are included in the stage completion message
- Review findings are logged in `aidlc-docs/audit.md`

---

## Rule REVIEW-02: Functional Design Review

**Applies to**: Functional Design stage (Construction phase) — Part 2 (Generation), after design artifacts are produced

**Mode**: Full only

**Rule**: After generating functional design artifacts (`business-logic-model.md`, `business-rules.md`, `domain-entities.md`), trigger a Codex adversarial review to challenge business logic design decisions.

**Procedure**:
1. Ensure functional design artifacts are saved to `aidlc-docs/construction/{unit}/functional-design/`
2. Execute: `/codex:adversarial-review`
3. Wait for review completion
4. Include review findings in the stage completion message under "Codex Review Findings"

**Review Focus Areas**:
- Business rule completeness and edge cases
- Domain entity relationship correctness
- Missing validation or constraint logic
- Potential conflicts between business rules
- Data model normalization concerns

**Verification**:
- Codex adversarial review was executed after functional design generation
- Review findings are included in the stage completion message
- Review findings are logged in `aidlc-docs/audit.md`

---

## Rule REVIEW-03: Code Generation Review

**Applies to**: Code Generation stage (Construction phase) — Part 2 (Generation), after code is generated for a unit

**Mode**: Full and Code-only

**Rule**: After completing code generation for a unit, trigger a Codex standard review on all generated and modified code before presenting the stage completion message.

**Procedure**:
1. Ensure all generated code is saved (not just staged in memory)
2. Execute: `/codex:review`
3. Wait for review completion
4. Include review findings in the stage completion message under "Codex Review Findings"

**Review Focus Areas**:
- Code quality and adherence to language idioms
- Security vulnerabilities (injection, XSS, SSRF, etc.)
- Error handling completeness
- Performance anti-patterns
- Test coverage gaps
- Consistency with design artifacts

**Verification**:
- Codex review was executed after code generation
- Review findings are included in the stage completion message
- Review findings are logged in `aidlc-docs/audit.md`

---

## Rule REVIEW-04: Test Code Review

**Applies to**: Build and Test stage (Construction phase), after test instructions and any additional test code are generated

**Mode**: Full and Code-only

**Rule**: After generating test instructions and test code, trigger a Codex review focused on test quality and coverage.

**Procedure**:
1. Ensure test code and instructions are saved
2. Execute: `/codex:review`
3. Wait for review completion
4. Include review findings in the stage completion message under "Codex Review Findings"

**Review Focus Areas**:
- Test coverage of critical paths and edge cases
- Test isolation and independence
- Assertion quality (meaningful assertions vs. trivial checks)
- Missing negative test cases
- Test data management and cleanup
- Flaky test patterns (timing, ordering, shared state)

**Verification**:
- Codex review was executed after test code generation
- Review findings are included in the stage completion message
- Review findings are logged in `aidlc-docs/audit.md`

---

## Enforcement Integration

These rules are cross-cutting constraints that apply to the following AI-DLC stages:

| Stage | Applicable Rules | Mode | Review Type |
|---|---|---|---|
| Application Design | REVIEW-01 | Full | `/codex:adversarial-review` |
| Functional Design | REVIEW-02 | Full | `/codex:adversarial-review` |
| Code Generation | REVIEW-03 | Full, Code-only | `/codex:review` |
| Build and Test | REVIEW-04 | Full, Code-only | `/codex:review` |

At each applicable stage:
1. Check the Codex Review enforcement mode in `aidlc-docs/aidlc-state.md` under `## Extension Configuration`
2. If the mode does not include the current rule (e.g., Code-only mode skips REVIEW-01 and REVIEW-02), mark the rule as N/A
3. Verify Codex plugin availability before attempting any review
4. Execute the specified review command after artifact generation, before presenting the stage completion message
5. Include a "Codex Review Findings" section in the stage completion summary listing each finding
6. Log all review activities and findings in `aidlc-docs/audit.md`

### Audit Log Format

Each Codex review event should be logged in `aidlc-docs/audit.md` with the following structure:

```markdown
### [ISO 8601 Timestamp] — Codex Review (REVIEW-XX)
- **Stage**: [Stage name]
- **Unit**: [Unit name, if applicable]
- **Review Type**: [adversarial-review / review]
- **Findings Summary**: [Brief summary of key findings]
- **User Decision**: [Acknowledged / Changes requested / Deferred]
```

### Interaction with Other Extensions

Codex reviews are independent of other extensions (Security, PBT, etc.). When multiple extensions are enabled:
- Extension compliance checks (blocking) are evaluated first
- Codex review (advisory) is triggered after compliance checks pass
- This ensures Codex reviews the compliant version of artifacts, not a version with known blocking issues
