# Evaluation Strategy

**Status:** Adapt to your project.

Evaluation taxonomy (see spec §7.4): deterministic assertions, JSON-schema validation, golden-dataset comparison, semantic quality, hallucination, retrieval relevance, groundedness, citation correctness, prompt injection, sensitive-data leakage, unsafe tool use, harmful output, refusal, latency, token usage, cost, fallback behavior, regression. Define thresholds by risk level. The template provides example schemas and golden fixtures plus a provider-neutral config at [../../evals/config/eval-default.yaml](../../evals/config/eval-default.yaml); consumer wires the model endpoint (see [../../evals/](../../evals/)).

## Phase 4 phasing

Phase 4 ships the `ai-evaluation.yml` workflow as an advisory skeleton (secret-gated, no real model calls in the template). The consumer wires `evals/run-evals.sh` + the `AI_EVAL_API_KEY` secret to activate. Thresholds (safety, leakage, regression, latency, cost) are advisory in Phase 4; promote to blocking after measuring precision and false-positive rate (TD-0007).
