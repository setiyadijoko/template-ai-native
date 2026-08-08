#!/usr/bin/env sh
# Provider-neutral evaluation runner contract.
# This stub validates the fixture contract and never calls a model provider.
set -eu

HERE="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
ROOT="$(CDPATH= cd -- "$HERE/.." && pwd)"
CONFIG="$ROOT/evals/config/eval-default.yaml"
MODE="run"

usage() {
  printf '%s\n' 'usage: evals/run-evals.sh [--check] [--config PATH]'
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --check) MODE="check"; shift ;;
    --config)
      [ "$#" -ge 2 ] || { usage >&2; exit 64; }
      CONFIG="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 64 ;;
  esac
done

[ -f "$CONFIG" ] || { printf 'eval config not found: %s\n' "$CONFIG" >&2; exit 1; }
[ -f "$ROOT/evals/golden/sentiment-golden.jsonl" ]
[ -f "$ROOT/evals/golden/summarizer-golden.jsonl" ]
[ -f "$ROOT/evals/golden/extractor-golden.jsonl" ]
grep -Eq '^version: 1$' "$CONFIG"
grep -Eq '^provider: none$' "$CONFIG"

python3 - "$ROOT" <<'PY'
import json
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
for path in sorted((root / "evals/golden").glob("*.jsonl")):
    for line_no, line in enumerate(path.read_text().splitlines(), 1):
        record = json.loads(line)
        required = {"id", "input", "expected_output"}
        missing = required - record.keys()
        if missing:
            raise SystemExit(f"{path}:{line_no}: missing {sorted(missing)}")
PY

if [ "$MODE" = "check" ]; then
  printf '%s\n' "Evaluation contract valid: $CONFIG"
  printf '%s\n' 'Provider-neutral check complete; no model provider was called.'
else
  printf '%s\n' 'AI evaluation runner is a provider-neutral stub.'
  printf '%s\n' 'No model provider was called. Consumer must implement adapter-backed evaluation.'
fi
