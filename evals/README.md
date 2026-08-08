# Evaluations

**Status:** Skeleton — wire to your model endpoint via secrets.

The evaluation framework (see [../docs/ai/evaluation-strategy.md](../docs/ai/evaluation-strategy.md)) covers: deterministic assertions, JSON-schema validation, golden-dataset comparison, semantic quality, hallucination, retrieval relevance, groundedness, citation correctness, prompt injection, sensitive-data leakage, unsafe tool use, harmful output, refusal, latency, token usage, cost, fallback behavior, regression.

## Layout

- `config/` — eval configuration (thresholds by risk level)
- `datasets/` — input datasets
- `golden/` — golden expected outputs
- `adversarial/` — prompt-injection / leakage / unsafe-tool cases
- `regression/` — regression cases (compare against a recorded baseline)
- `safety/` — safety cases
- `performance/` — latency / throughput cases
- `cost/` — token/cost cases
- `reports/` — generated eval reports (gitignored artifacts may live elsewhere)

## Rules

- Most CI tests use deterministic stubs; real-model calls run only in controlled workflows with spending limits, timeout, caching, and secret protection.
- Define thresholds by risk level; do not release automatically if critical AI thresholds regress.

## Thresholds by risk level (Phase 4: advisory)

| Category | Threshold | Phase 4 policy |
|---|---|---|
| Safety (injection, harmful output) | 0 failures | Advisory — promote to blocking once precision is measured |
| Sensitive-data leakage | 0 failures | Advisory |
| Regression (golden/groun/eval) | no regressions vs baseline | Advisory |
| Latency | within budget | Advisory |
| Cost | within budget | Advisory |

## Where the framework plugs in

The template includes [`run-evals.sh`](run-evals.sh) as a provider-neutral contract
stub. `--check` validates the local fixture contract and never calls a model
provider. A consumer replaces or extends it with an adapter-backed runner that
reads `AI_EVAL_API_KEY` only in a controlled workflow. Until then, the
`ai-evaluation.yml` workflow skips cleanly with a clear message. Promote
thresholds to blocking in a later phase (TD-0007).
