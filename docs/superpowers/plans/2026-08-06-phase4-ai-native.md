# Phase 4 — AI-native capability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the AI-native capability layer: two secret-gated skeleton workflows (`ai-evaluation.yml`, `open-code-review.yml`), a 3rd prompt registry entry with structured-output schemas, an evals threshold/strategy note, and cross-cutting docs — no real model calls in the template.

**Architecture:** Both workflows guard their active step with `if: secrets.<NAME> != ''`; the template has no secrets, so they skip cleanly (green PR). OpenCodeReview uses `pull_request` (not `pull_request_target`) per the spec's security rule. The registry's 3rd entry demonstrates structured-output validation (spec §7.3).

**Tech Stack:** GitHub Actions (YAML), JSON Schema (draft 2020-12), Alibaba `open-code-review` Action, Markdown.

**Reference spec:** `docs/superpowers/specs/2026-08-06-phase4-ai-native-design.md` (authoritative).

## Global Constraints

- **No real model calls** in the template; both workflows skip cleanly when secrets are absent.
- **No `pull_request_target`** (spec §15.6 / AGENTS.md). OCR uses `pull_request`; forked PRs skip OCR review (TD-0008).
- **Secret-gating pattern:** active step `if: secrets.<NAME> != ''`; skip step `if: secrets.<NAME> == ''`.
- **Workflow security:** `permissions: contents: read` default; `pull-requests: write` only for OCR (posts comments); SHA-pin every `uses:` via `gh api`.
- **Schemas** must be valid JSON Schema draft 2020-12 and parse as JSON.
- Build on branch `phase-4-ai-native` (created; spec at `5ad3e64`). Base = `main` (`b238d68`). No direct push to `main`.

## File Structure

| Task | Cohesion | Key files |
|---|---|---|
| 1 | AI workflows (secret-gated skeleton) | `.github/workflows/ai-evaluation.yml`, `.github/workflows/open-code-review.yml` |
| 2 | Registry expansion + schemas | `prompts/registry.yaml`, `prompts/schemas/extractor-input.json`, `prompts/schemas/extractor-output.json` |
| 3 | evals/README threshold table + docs cross-ref | `evals/README.md`, `docs/ai/evaluation-strategy.md`, `AGENTS.md`, `docs/plans/technical-debt.md`, `CHANGELOG.md` |
| 4 | Verify + push + PR | (no new files; verification + PR) |

---

## Task 1: AI workflows (secret-gated skeleton)

**Files:**
- Create: `.github/workflows/ai-evaluation.yml`
- Create: `.github/workflows/open-code-review.yml`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: two workflows triggered on PR; both skip cleanly without secrets.

**Critical:** resolve the OpenCodeReview Action SHA via `gh api` before writing:
```sh
repo="alibaba/open-code-review"; tag="v1.0.0"   # discover latest stable tag at impl time
t=$(gh api "repos/$repo/git/refs/tags/$tag" --jq '.object.sha')
ty=$(gh api "repos/$repo/git/refs/tags/$tag" --jq '.object.type')
if [ "$ty" = "tag" ]; then gh api "repos/$repo/git/tags/$t" --jq '.object.sha'; else echo "$t"; fi
```
Verify with `gh api repos/<repo>/git/commits/<sha>` (HTTP 200).

- [ ] **Step 1: Discover & resolve the OpenCodeReview SHA.**
```sh
gh api "repos/alibaba/open-code-review/tags" --jq '.[].name' | grep -E '^v[0-9]' | head -3
# pick the latest stable; then resolve commit SHA; record "<repo>@<sha> # <tag>"
```

- [ ] **Step 2: Create `.github/workflows/ai-evaluation.yml`:**
```yaml
name: ai-evaluation

# AI evaluation skeleton (advisory). Skips cleanly when AI_EVAL_API_KEY is
# absent — the template makes no real model calls. Consumer adds the secret
# and an evals/run-evals.sh runner to activate.
on:
  pull_request:
    paths:
      - "prompts/**"
      - "evals/**"
      - "src/**"
      - ".github/workflows/ai-evaluation.yml"
  workflow_dispatch:

permissions:
  contents: read

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  ai-evaluation:
    name: AI evaluation (advisory skeleton)
    runs-on: ubuntu-latest
    timeout-minutes: 15
    steps:
      - name: Checkout
        uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1

      - name: Skip (no AI_EVAL_API_KEY)
        if: ${{ secrets.AI_EVAL_API_KEY == '' }}
        run: echo "AI-eval skipped — set the AI_EVAL_API_KEY secret and add evals/run-evals.sh to activate."

      - name: Run AI evaluations
        if: ${{ secrets.AI_EVAL_API_KEY != '' }}
        run: |
          echo "AI eval runner not configured — implement evals/run-evals.sh (uses AI_EVAL_API_KEY) to run real evaluations."
          # Consumer: replace the line above with: sh evals/run-evals.sh
```

- [ ] **Step 3: Create `.github/workflows/open-code-review.yml`:**
```yaml
name: open-code-review

# Alibaba OpenCodeReview (advisory, secret-gated). Uses `pull_request` (NOT
# pull_request_target) per the template's security rule (§15.6). Forked PRs
# skip OCR review. Consumer adds OCR_LLM_* secrets to activate.
on:
  pull_request:
    paths:
      - "src/**"
      - ".github/workflows/open-code-review.yml"
  workflow_dispatch:

permissions:
  contents: read
  pull-requests: write   # OCR posts review comments

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  open-code-review:
    name: OpenCodeReview (advisory)
    runs-on: ubuntu-latest
    timeout-minutes: 30
    steps:
      - name: Checkout
        uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1

      - name: OpenCodeReview
        if: ${{ secrets.OCR_LLM_AUTH_TOKEN != '' }}
        uses: alibaba/open-code-review@<SHA> # <tag>
        with:
          llm_url: ${{ secrets.OCR_LLM_URL }}
          llm_auth_token: ${{ secrets.OCR_LLM_AUTH_TOKEN }}
          llm_model: ${{ secrets.OCR_LLM_MODEL }}
          llm_use_anthropic: ${{ secrets.OCR_LLM_USE_ANTHROPIC }}

      - name: Skip (no OCR secret)
        if: ${{ secrets.OCR_LLM_AUTH_TOKEN == '' }}
        run: echo "OpenCodeReview skipped — set OCR_LLM_* secrets to activate."
```

- [ ] **Step 4: Verify** — YAML validity; the OCR SHA resolves via `gh api`. (Locally, `gh api repos/alibaba/open-code-review/git/commits/<sha>` returns 200.)

- [ ] **Step 5: Commit**
```sh
git add .github/workflows/ai-evaluation.yml .github/workflows/open-code-review.yml
git commit -m "ci: add AI evaluation skeleton and OpenCodeReview (secret-gated, advisory)"
```

---

## Task 2: Registry expansion + structured-output schemas

**Files:**
- Modify: `prompts/registry.yaml`
- Create: `prompts/schemas/extractor-input.json`
- Create: `prompts/schemas/extractor-output.json`

**Interfaces:**
- Consumes: the existing registry structure (2 entries from Phase 1).
- Produces: a 3rd entry `example-structured-extractor` + 2 valid JSON Schemas.

- [ ] **Step 1: Create `prompts/schemas/extractor-input.json`:**
```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://template-ai-native/prompts/schemas/extractor-input.json",
  "title": "Extractor input",
  "type": "object",
  "additionalProperties": false,
  "required": ["document"],
  "properties": {
    "document": {
      "type": "string",
      "description": "A document of up to ~4000 tokens to extract fields from."
    }
  }
}
```

- [ ] **Step 2: Create `prompts/schemas/extractor-output.json`:**
```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://template-ai-native/prompts/schemas/extractor-output.json",
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
        "additionalProperties": false,
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

- [ ] **Step 3: Append the 3rd entry to `prompts/registry.yaml`.** Under the `prompts:` list, after the existing `example-summarizer` entry, add:
```yaml
  - id: example-structured-extractor
    name: Example Structured Extractor
    purpose: >-
      EXAMPLE. Extract structured fields (title, summary, entities) from a
      document and validate the output against a JSON schema before trust.
      Replace with a real prompt before use.
    version: 0.1.0
    owner: "@setiyadijoko"
    input:
      schema_ref: schemas/extractor-input.json
      description: A document of up to ~4000 tokens.
    output:
      schema_ref: schemas/extractor-output.json
      description: "Object: { title, summary, entities[] } — validated before trust (§7.3)."
    model_compatibility:
      - gpt-4o-mini
      - claude-3-5-sonnet
    safety_constraints:
      - "Refuse if the document contains disallowed content."
      - "Do not include PII in the response."
    evaluation_dataset: evals/golden/extractor-golden.jsonl
    changelog:
      - version: 0.1.0
        date: 2026-08-06
        change: "Initial example entry demonstrating structured-output validation."
    deprecation_status: active
```

- [ ] **Step 4: Verify** — both schemas parse as JSON; registry parses as YAML and has 3 prompts.
```sh
/tmp/yamlcheck/bin/python - <<'PY'
import json, yaml
json.load(open('prompts/schemas/extractor-input.json')); print('input.json OK')
json.load(open('prompts/schemas/extractor-output.json')); print('output.json OK')
d = yaml.safe_load(open('prompts/registry.yaml'))
print('registry OK, prompts:', len(d['prompts']))
assert any(p['id'] == 'example-structured-extractor' for p in d['prompts'])
print('3rd entry present')
PY
```

- [ ] **Step 5: Commit**
```sh
git add prompts/registry.yaml prompts/schemas/extractor-input.json prompts/schemas/extractor-output.json
git commit -m "feat(prompts): add example-structured-extractor with JSON-schema output validation"
```

---

## Task 3: evals/README threshold table + docs cross-ref

**Files:**
- Modify: `evals/README.md`
- Modify: `docs/ai/evaluation-strategy.md`
- Modify: `AGENTS.md`
- Modify: `docs/plans/technical-debt.md`
- Modify: `CHANGELOG.md`

- [ ] **Step 1: Extend `evals/README.md`.** After the existing "## Rules" section, add:
```markdown
## Thresholds by risk level (Phase 4: advisory)

| Category | Threshold | Phase 4 policy |
|---|---|---|
| Safety (injection, harmful output) | 0 failures | Advisory — promote to blocking once precision is measured |
| Sensitive-data leakage | 0 failures | Advisory |
| Regression (golden/groun/eval) | no regressions vs baseline | Advisory |
| Latency | within budget | Advisory |
| Cost | within budget | Advisory |

## Where the framework plugs in

The consumer adds `evals/run-evals.sh` (or a language-appropriate runner) that reads the `AI_EVAL_API_KEY` secret and executes the eval suites against the model endpoint. Until then, the `ai-evaluation.yml` workflow skips cleanly with a clear message. Promote thresholds to blocking in a later phase (TD-0007).
```

- [ ] **Step 2: Update `docs/ai/evaluation-strategy.md`.** Append a "## Phase 4 phasing" section:
```markdown
## Phase 4 phasing

Phase 4 ships the `ai-evaluation.yml` workflow as an advisory skeleton (secret-gated, no real model calls in the template). The consumer wires `evals/run-evals.sh` + the `AI_EVAL_API_KEY` secret to activate. Thresholds (safety, leakage, regression, latency, cost) are advisory in Phase 4; promote to blocking after measuring precision and false-positive rate (TD-0007).
```

- [ ] **Step 3: Update `AGENTS.md`** — under "AI model and prompt rules", after the existing bullets, add:
```markdown
- **Phase 4 AI workflows:** `ai-evaluation.yml` (skeleton, advisory; skips without `AI_EVAL_API_KEY`) and `open-code-review.yml` (Alibaba OCR, advisory; skips without `OCR_LLM_*` secrets). Both use `pull_request` (not `pull_request_target`) per the security rule. See `docs/ai/evaluation-strategy.md`.
```

- [ ] **Step 4: Update `docs/plans/technical-debt.md`** — append two rows:
```markdown
| TD-0007 | `ai-evaluation.yml` is an advisory skeleton in Phase 4; promote to blocking after measuring precision/false-positive rate. The consumer's `evals/run-evals.sh` contract is documented but not implemented in the template. | `.github/workflows/ai-evaluation.yml`, `evals/README.md` | Open | After ~1 month of advisory runs on a real project, flip the run step to call `evals/run-evals.sh` and enforce thresholds (safety/leakage = 0; regression = no baseline regressions). |
| TD-0008 | OpenCodeReview uses `pull_request` (not `pull_request_target`) per the spec's security rule; forked PRs skip OCR review. | `.github/workflows/open-code-review.yml` | Open | If org-level trusted-fork review is required, revisit with a hardened `pull_request_target` pattern (only trusted paths, no untrusted-data injection). |
```

- [ ] **Step 5: Update `CHANGELOG.md`** — prepend to `### Added`:
```markdown
- Phase 4 AI-native capability: `ai-evaluation.yml` (skeleton, advisory, secret-gated) and `open-code-review.yml` (Alibaba OCR, advisory, secret-gated) — both use `pull_request` (not `pull_request_target`) and skip cleanly without secrets. Plus `example-structured-extractor` prompt with JSON-schema output validation, `evals/README.md` threshold table, and cross-cutting docs.
```

- [ ] **Step 6: Local verification**
```sh
make ci            # exit 0
make test-scripts  # passed=43 failed=0
make docs-check    # exit 0
/tmp/yamlcheck/bin/python -c "import yaml,glob; [list(yaml.safe_load_all(open(f))) for f in glob.glob('.github/workflows/*.yml')]; print('YAML OK')"
# registry + schemas parse (Task 2 Step 4 check)
```

- [ ] **Step 7: Commit**
```sh
git add evals/README.md docs/ai/evaluation-strategy.md AGENTS.md docs/plans/technical-debt.md CHANGELOG.md
git commit -m "docs: document Phase-4 AI workflows, eval thresholds, debt entries, changelog"
```

---

## Task 4: Verify + push + open PR

**Files:** none (verification + PR).

- [ ] **Step 1: Final local verification** — `make ci` exit 0; all workflow YAML valid; all SHAs resolve.
```sh
# SHA resolves for ai-evaluation (checkout only) + open-code-review (checkout + ocr)
grep -rhoE 'uses: [a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+@[0-9a-f]{40}' .github/workflows/ai-evaluation.yml .github/workflows/open-code-review.yml | sort -u | while IFS= read -r line; do
  repo=$(echo "$line" | sed -E 's|uses: ([^@]+)@.*|\1|'); sha=$(echo "$line" | sed -E 's|.*@([0-9a-f]{40})|\1|')
  gh api "repos/$repo/git/commits/$sha" >/dev/null 2>&1 && echo "OK   $repo@${sha:0:12}" || echo "FAIL $repo@${sha:0:12}"
done
```

- [ ] **Step 2: Push + open PR**
```sh
git push -u origin phase-4-ai-native
gh pr create --base main --head phase-4-ai-native \
  --title "feat: Phase 4 — AI-native capability (skeleton workflows + registry)" \
  --body "<filled from .github/pull_request_template.md>"
```

- [ ] **Step 3: Verify PR checks** — expect: Phase-1/2/3 checks green; `ai-evaluation.yml` triggers (the PR touches `prompts/**` and `evals/**`) → skip step runs (no `AI_EVAL_API_KEY`) green; `open-code-review.yml` triggers (touches `.github/workflows/open-code-review.yml`) → skip step runs (no `OCR_LLM_AUTH_TOKEN`) green. Report actual results; fix any failure from logs.

- [ ] **Step 4: Hand off** — report PR URL + check status to the owner for merge.

---

## Self-Review (run after writing)

**1. Spec coverage:**
- ai-evaluation.yml (skeleton, secret-gated) → Task 1 ✓
- open-code-review.yml (secret-gated, `pull_request`) → Task 1 ✓
- registry 3rd entry + schemas (§7.3) → Task 2 ✓
- evals/README threshold table + plug-in point → Task 3 ✓
- AGENTS.md / evaluation-strategy / TD-0007-0008 / CHANGELOG → Task 3 ✓
- Verify + PR → Task 4 ✓

**2. Placeholder scan:** the `<SHA> # <tag>` markers in Task 1 are "resolve at implementation time" backed by a concrete resolution step (Step 1). The `# Consumer: replace...` comment in the workflow is documentation, not a plan-failure placeholder. Schemas have complete content. ✓

**3. Consistency:** secret names (`AI_EVAL_API_KEY`, `OCR_LLM_AUTH_TOKEN`/`OCR_LLM_URL`/`OCR_LLM_MODEL`/`OCR_LLM_USE_ANTHROPIC`) match across Task 1 workflows, Task 3 docs, spec §5. Registry entry `schema_ref` paths (`schemas/extractor-input.json`, `schemas/extractor-output.json`) match Task 2 filenames. ✓

No gaps found.
