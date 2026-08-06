# Prompts

**Status:** Skeleton — wire to your model endpoint.

Production prompts live in [registry.yaml](registry.yaml) and are reviewed like code (see [../docs/ai/prompt-management.md](../docs/ai/prompt-management.md)).

## Required fields per prompt

id, name, purpose, version, owner, expected input, output schema, model compatibility, safety constraints, evaluation dataset, changelog, deprecation status.

## Layout

- `system/` — system prompts
- `tasks/` — task prompts
- `evaluators/` — prompts used by the evaluation framework (LLM-as-judge)
- `versions/` — immutable versioned snapshots
- `schemas/` — JSON schemas for structured outputs

A material prompt change must trigger the relevant AI evaluations (see [../evals/](../evals/)).
