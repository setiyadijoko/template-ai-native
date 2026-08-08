# Prompts

**Status:** Skeleton — wire to your model endpoint.

Production prompts live in [registry.yaml](registry.yaml) and are reviewed like code (see [../docs/ai/prompt-management.md](../docs/ai/prompt-management.md)).

## Required fields per prompt

id, name, purpose, version, owner, prompt reference, system prompt reference,
expected input, output schema, model compatibility, safety constraints,
evaluation dataset, changelog, deprecation status.

## Layout

- `system/` — system prompts
- `tasks/` — task prompts
- `evaluators/` — prompts used by the evaluation framework (LLM-as-judge)
- `versions/` — immutable versioned snapshots
- `schemas/` — JSON schemas for structured outputs

The example registry entries are wired to prompt files under `system/` and
`tasks/`. Their referenced schemas and golden fixtures are intentionally small
and safe to replace; they demonstrate the contract, not a production prompt.

A material prompt change must trigger the relevant AI evaluations (see [../evals/](../evals/)).
