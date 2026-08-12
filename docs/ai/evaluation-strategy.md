# Evaluation Strategy

**Status:** Adapt to your project.

Evaluation taxonomy (see spec §7.4): deterministic assertions, JSON-schema validation, golden-dataset comparison, semantic quality, hallucination, retrieval relevance, groundedness, citation correctness, prompt injection, sensitive-data leakage, unsafe tool use, harmful output, refusal, latency, token usage, cost, fallback behavior, regression. Define thresholds by risk level. The template provides example schemas and golden fixtures plus a provider-neutral config at [../../evals/config/eval-default.yaml](../../evals/config/eval-default.yaml); consumer wires the model endpoint (see [../../evals/](../../evals/)).

## Phase 4 phasing

Phase 4 ships two advisory modes in `ai-evaluation.yml`. The reusable deterministic path runs `--check` without credentials or a provider call and can be selected by the profile aggregate. The direct event path remains gated by `AI_EVAL_API_KEY`; the template still makes no real model call until a consumer extends the runner through an approved adapter and data policy. Thresholds (safety, leakage, regression, latency, cost) are advisory in Phase 4; promote them to blocking only after measuring precision and false-positive rate (TD-0007).
