# Codex Review — Opt-In

**Extension**: Codex Review

**Platform Requirement**: Claude Code with Codex plugin installed (`/codex:setup` must complete successfully)

## Opt-In Prompt

The following question is automatically included in the Requirements Analysis clarifying questions when this extension is loaded:

```markdown
## Question: Codex Review Extension
Should Codex-powered reviews be performed at design and code generation stages?

A) Full — review both design artifacts and generated code (recommended for production-grade applications or when independent validation is desired)
B) Code-only — review generated code only, skip design reviews (suitable when design decisions are already well-established)
C) No — skip all Codex reviews (suitable when Codex is unavailable or not needed)
X) Other (please describe after [Answer]: tag below)

[Answer]: 
```

## Enforcement Mode Recording

After the user responds, record the enforcement mode in `aidlc-docs/aidlc-state.md` under `## Extension Configuration`:

| Extension | Enabled | Mode | Decided At |
|---|---|---|---|
| Codex Review | Yes/No | Full/Code-only/N/A | Requirements Analysis |
