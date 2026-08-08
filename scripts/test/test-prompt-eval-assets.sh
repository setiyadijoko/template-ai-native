#!/usr/bin/env sh
# Contract checks for prompt examples, evaluation fixtures, and guidance.
set -eu

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
# shellcheck source=scripts/test/lib.sh
. "$HERE/lib.sh"

assert_file() {
  label="$1"; file="$2"
  if [ -f "$file" ]; then PASS=$((PASS+1)); else
    FAIL=$((FAIL+1)); printf 'FAIL %s\n     missing file: %s\n' "$label" "$file" >&2
  fi
}

assert_contains() {
  label="$1"; file="$2"; pattern="$3"
  if grep -Eq -- "$pattern" "$file"; then PASS=$((PASS+1)); else
    FAIL=$((FAIL+1)); printf 'FAIL %s\n     missing pattern: %s\n' "$label" "$pattern" >&2
  fi
}

for file in \
  "$ROOT/prompts/system/base-safety.md" \
  "$ROOT/prompts/tasks/sentiment-classifier.md" \
  "$ROOT/prompts/tasks/summarizer.md" \
  "$ROOT/prompts/tasks/structured-extractor.md" \
  "$ROOT/prompts/schemas/sentiment-input.json" \
  "$ROOT/prompts/schemas/summarizer-input.json" \
  "$ROOT/prompts/schemas/summarizer-output.json" \
  "$ROOT/evals/golden/sentiment-golden.jsonl" \
  "$ROOT/evals/golden/summarizer-golden.jsonl" \
  "$ROOT/evals/golden/extractor-golden.jsonl" \
  "$ROOT/evals/config/eval-default.yaml" \
  "$ROOT/evals/run-evals.sh" \
  "$ROOT/docs/development/version-pinning.md" \
  "$ROOT/docs/operations/branch-protection.md"; do
  assert_file "required evaluation or guidance asset" "$file"
done

assert_contains "eval config has version" "$ROOT/evals/config/eval-default.yaml" '^version: 1$'
assert_contains "eval config uses provider-neutral stub" "$ROOT/evals/config/eval-default.yaml" '^provider: none$'
assert_contains "eval config defines thresholds" "$ROOT/evals/config/eval-default.yaml" '^thresholds:'
assert_contains "runner documents provider-neutral behavior" "$ROOT/evals/run-evals.sh" 'provider-neutral'
assert_contains "runner has check mode" "$ROOT/evals/run-evals.sh" '--check'
assert_contains "AI evaluation workflow invokes runner contract" "$ROOT/.github/workflows/ai-evaluation.yml" 'sh evals/run-evals.sh --check'
assert_contains "registry references all golden fixtures" "$ROOT/prompts/registry.yaml" 'evals/golden/(sentiment|summarizer|extractor)-golden\.jsonl'
assert_contains "PostHog is optional" "$ROOT/docs/operations/observability.md" 'PostHog is an optional'
assert_contains "Python caching guidance exists" "$ROOT/docs/development/version-pinning.md" 'cache: pip'
assert_contains ".NET caching guidance exists" "$ROOT/docs/development/version-pinning.md" 'NuGet'

if python3 - "$ROOT" <<'PY'
import json
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
failures = []
for path in sorted((root / "prompts/schemas").glob("*.json")):
    try:
        json.loads(path.read_text())
    except Exception as exc:
        failures.append(f"invalid JSON schema {path}: {exc}")
for path in sorted((root / "evals/golden").glob("*.jsonl")):
    for line_no, line in enumerate(path.read_text().splitlines(), 1):
        try:
            json.loads(line)
        except Exception as exc:
            failures.append(f"invalid JSONL {path}:{line_no}: {exc}")
if failures:
    print("\n".join(failures), file=sys.stderr)
    sys.exit(1)
PY
then PASS=$((PASS+1)); else
  FAIL=$((FAIL+1)); printf 'FAIL JSON and JSONL fixtures parse\n' >&2
fi

if [ -x "$ROOT/evals/run-evals.sh" ]; then PASS=$((PASS+1)); else
  FAIL=$((FAIL+1)); printf 'FAIL eval runner is executable\n' >&2
fi

report
