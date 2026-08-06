# Design Spec — Phase 4: AI-native capability

**Status:** Approved
**Date:** 2026-08-06
**Owner:** Project owner (@setiyadijoko)
**Builds on:** Phase 1 (`cd785fd`) + Phase 2 (`0bb1677`) + Phase 3 (`99fd405`) + scorecard fix (`b238d68`)

---

## 1. Goal

Add the AI-native capability layer to `template-ai-native`: two AI workflows (`ai-evaluation.yml` skeleton advisory→promotable, `open-code-review.yml` advisory secret-gated), a light expansion of the prompt registry (a 3rd example exercising structured-output schema validation), an evals threshold/strategy note, and cross-cutting docs. The template makes **no real model calls** — both workflows skip cleanly when the consumer has not wired a model endpoint/secret.

## 2. Key decisions

| # | Decision | Choice | Rationale |
|---|---|---|---|
| 1 | AI eval scope | Skeleton workflows + light registry expansion | Locked from the original master spec (skeleton-only, advisory→blocking). |
| 2 | OpenCodeReview | Secret-gated activation | Workflow runs but the OCR step is guarded by `if: secrets.OCR_LLM_AUTH_TOKEN != ''`; absent secret → clean skip. Consumer adds secrets to activate. |
| 3 | PR trigger | `pull_request` (NOT `pull_request_target`) | Spec §15.6 / AGENTS.md prohibit `pull_request_target`. We accept that forked PRs won't receive OCR review (no secrets exposed) — safer. TD-0008 records the trade-off. |
| 4 | Real model calls | None in template | Both workflows document where the consumer wires the endpoint; no secrets burned on a public template. |
| 5 | Action SHAs | Resolve via `gh api` at implementation time | Phase-1/2/3 lesson. |

## 3. Workflow inventory

| Workflow | Trigger | Purpose | Status |
|---|---|---|---|
| `ai-evaluation.yml` | PR (`prompts/**`, `evals/**`, `src/**`) + `workflow_dispatch` | Run the AI evaluation framework (regression + safety) | Advisory — skips when `secrets.AI_EVAL_API_KEY == ''` |
| `open-code-review.yml` | PR (`src/**`, `.github/workflows/open-code-review.yml`) + `workflow_dispatch` | Post AI code-review comments (Alibaba OpenCodeReview) | Advisory — skips when `secrets.OCR_LLM_AUTH_TOKEN == ''` |

## 4. File structure

```text
.github/workflows/
├── ai-evaluation.yml        # NEW
└── open-code-review.yml     # NEW

prompts/
├── registry.yaml            # MODIFY — add 3rd example entry
└── schemas/
    ├── extractor-input.json   # NEW
    └── extractor-output.json  # NEW

evals/
└── README.md                # MODIFY — add threshold table + "where the framework plugs in"

docs/ai/evaluation-strategy.md  # MODIFY — Phase-4 phasing note
docs/plans/technical-debt.md    # MODIFY — TD-0007, TD-0008
AGENTS.md                       # MODIFY — cross-ref Phase-4 workflows
CHANGELOG.md                    # MODIFY
```

## 5. Workflow designs

### 5.1 `ai-evaluation.yml`
- `permissions: contents: read`.
- `concurrency: ${{ github.workflow }}-${{ github.ref }}, cancel-in-progress: true`.
- `timeout-minutes: 15`.
- Steps:
  1. checkout (SHA-pinned).
  2. `Skip (no AI_EVAL_API_KEY)`: `if: ${{ secrets.AI_EVAL_API_KEY == '' }}`, runs `echo "AI-eval skipped — set AI_EVAL_API_KEY to activate."`.
  3. `Run AI evaluations`: `if: ${{ secrets.AI_EVAL_API_KEY != '' }}`, runs the documented skeleton command (e.g. `echo "AI eval runner not configured — implement evals/run-evals.sh (uses AI_EVAL_API_KEY) to activate real evaluations."`) with a clear comment that the consumer adds `evals/run-evals.sh`. Never calls a model in the template.

### 5.2 `open-code-review.yml`
- `permissions: contents: read, pull-requests: write` (OCR posts review comments).
- `concurrency`, `timeout-minutes: 30`.
- Steps:
  1. checkout.
  2. `OpenCodeReview`: `if: ${{ secrets.OCR_LLM_AUTH_TOKEN != '' }}`, `uses: alibaba/open-code-review@<SHA>` with inputs `llm_url: ${{ secrets.OCR_LLM_URL }}`, `llm_auth_token: ${{ secrets.OCR_LLM_AUTH_TOKEN }}`, `llm_model: ${{ secrets.OCR_LLM_MODEL }}`, `llm_use_anthropic: ${{ secrets.OCR_LLM_USE_ANTHROPIC }}`.
  3. `Skip (no OCR secret)`: `if: ${{ secrets.OCR_LLM_AUTH_TOKEN == '' }}`, runs `echo "OpenCodeReview skipped — set OCR_LLM_* secrets to activate."`.
- **No `pull_request_target`.** Forked PRs skip OCR (no secrets exposed); acceptable per TD-0008.

## 6. Registry expansion

Add `example-structured-extractor` to `prompts/registry.yaml` (alongside the two existing examples) — a prompt whose output is validated against `schemas/extractor-output.json` before trust (demonstrates spec §7.3 structured output). Add `prompts/schemas/extractor-input.json` and `extractor-output.json`.

`extractor-output.json` schema (concrete):
```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "title": "Extractor output",
  "type": "object",
  "additionalProperties": false,
  "required": ["title", "summary", "entities"],
  "properties": {
    "title": { "type": "string", "maxLength": 200 },
    "summary": { "type": "string", "maxLength": 1000 },
    "entities": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["name", "type"],
        "properties": {
          "name": { "type": "string" },
          "type": { "type": "string", "enum": ["person", "org", "date", "location", "other"] }
        }
      }
    }
  }
}
```

## 7. evals/README.md upgrade

Add (to the existing Phase-1 README):
- **Thresholds by risk level** table (critical = 0 blocking findings; safety evals pass; leakage evals pass; latency/cost within budget — promotable from advisory).
- **Where the framework plugs in** section: the consumer adds `evals/run-evals.sh` (or language-appropriate runner) that reads `AI_EVAL_API_KEY` and executes the eval suites. Until then, `ai-evaluation.yml` skips cleanly.

## 8. Documentation updates

- `AGENTS.md` (AI model and prompt rules): cross-ref the two Phase-4 workflows and the secret-gating pattern.
- `docs/ai/evaluation-strategy.md`: add a "Phase 4 phasing" note (skeleton advisory; promote to blocking after precision is measured).
- `docs/plans/technical-debt.md`:
  - TD-0007: promote `ai-evaluation.yml` to blocking after measuring precision/false-positive rate; document the consumer's `evals/run-evals.sh` contract.
  - TD-0008: OpenCodeReview uses `pull_request` (not `pull_request_target`) per the spec's security rule; forked PRs skip OCR review. Revisit if org-level trusted-fork review is required.
- `CHANGELOG.md`: `### Added` Phase-4 entry.

## 9. Out of scope

- Real model calls or a working eval harness (skeleton only).
- A language-specific eval runner (consumer-owned; stack-agnostic template).
- Cost/latency benchmark automation (TD-0002 lineage).
- Delivery pipeline / deploy / production readiness (Phases 5–6).

## 10. Assumptions

1. Template has no model secrets → both workflows skip cleanly (green PR).
2. Consumers add secrets (`AI_EVAL_API_KEY`, `OCR_LLM_*`) to activate.
3. `alibaba/open-code-review` Action works on private repos when secrets are provided (it posts comments via the PR API; no GHAS dependency for the review-posting path).
4. The `pull_request` (non-target) trigger means OCR review does not run on forked PRs (acceptable; security rule §15.6 takes precedence).

## 11. Acceptance criteria

Phase 4 is complete when:
- `ai-evaluation.yml` and `open-code-review.yml` exist, SHA-pinned, least-privilege, with timeouts + concurrency.
- On the empty template (no secrets): both workflows trigger (when their path filters match) and the skip step runs green.
- `prompts/registry.yaml` has 3 example entries; `extractor-output.json` + `extractor-input.json` exist and validate.
- `evals/README.md`, `docs/ai/evaluation-strategy.md`, `AGENTS.md`, `docs/plans/technical-debt.md`, `CHANGELOG.md` updated.
- All Phase-1/2/3 checks remain green.
- PR opened on a feature branch, all checks pass, owner merges to `main`.
