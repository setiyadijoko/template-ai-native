SHELL := /bin/sh
STACK := $(shell sh scripts/detect-stack.sh)

.PHONY: setup dev format format-check lint typecheck \
        test test-unit test-contract test-integration test-e2e test-coverage \
        eval eval-regression eval-safety \
        security secret-scan dependency-scan container-scan iac-scan \
        build run smoke-test docs-check ci

# When no stack is detected, targets that need a toolchain no-op cleanly.
# Define real commands by overriding these in a stack-specific include.
ifeq ($(STACK),unknown)
setup:            ; @echo "[skip] no stack detected — wire src/ to enable setup"
dev:              ; @echo "[skip] no stack detected — wire src/ to enable dev"
format:           ; @echo "[skip] no stack detected — wire src/ to enable format"
format-check:     ; @echo "[skip] no stack detected — wire src/ to enable format-check"
lint:             ; @echo "[skip] no stack detected — wire src/ to enable lint"
typecheck:        ; @echo "[skip] no stack detected — wire src/ to enable typecheck"
test:             ; @echo "[skip] no stack detected — wire src/ to enable test"
test-unit:        ; @echo "[skip] no stack detected — wire src/ to enable test-unit"
test-contract:    ; @echo "[skip] no stack detected — wire src/ to enable test-contract"
test-integration: ; @echo "[skip] no stack detected — wire src/ to enable test-integration"
test-e2e:         ; @echo "[skip] no stack detected — wire src/ to enable test-e2e"
test-coverage:    ; @echo "[skip] no stack detected — wire src/ to enable test-coverage"
eval:             ; @echo "[skip] no stack detected — wire src/ to enable eval"
eval-regression:  ; @echo "[skip] no stack detected — wire src/ to enable eval-regression"
eval-safety:      ; @echo "[skip] no stack detected — wire src/ to enable eval-safety"
dependency-scan:  ; @echo "[skip] no stack detected — wire src/ to enable dependency-scan"
container-scan:   ; @echo "[skip] no stack detected — wire src/ to enable container-scan"
iac-scan:         ; @echo "[skip] no stack detected — wire src/ to enable iac-scan"
build:            ; @echo "[skip] no stack detected — wire src/ to enable build"
run:              ; @echo "[skip] no stack detected — wire src/ to enable run"
smoke-test:       ; @echo "[skip] no stack detected — wire src/ to enable smoke-test"
else
# Replace these stubs with real commands for your detected stack.
setup:            ; @echo "TODO: configure setup for $(STACK)"
dev:              ; @echo "TODO: configure dev server for $(STACK)"
format:           ; @echo "TODO: configure formatter for $(STACK)"
format-check:     ; @echo "TODO: configure format-check for $(STACK)"
lint:             ; @echo "TODO: configure linter for $(STACK)"
typecheck:        ; @echo "TODO: configure typecheck for $(STACK)"
test:             ; @echo "TODO: configure test for $(STACK)"
test-unit:        ; @echo "TODO: configure test-unit for $(STACK)"
test-contract:    ; @echo "TODO: configure test-contract for $(STACK)"
test-integration: ; @echo "TODO: configure test-integration for $(STACK)"
test-e2e:         ; @echo "TODO: configure test-e2e for $(STACK)"
test-coverage:    ; @echo "TODO: configure test-coverage for $(STACK)"
eval:             ; @echo "TODO: configure AI eval for $(STACK)"
eval-regression:  ; @echo "TODO: configure eval-regression"
eval-safety:      ; @echo "TODO: configure eval-safety"
dependency-scan:  ; @echo "TODO: configure dependency-scan for $(STACK)"
container-scan:   ; @echo "TODO: configure container-scan"
iac-scan:         ; @echo "TODO: configure iac-scan"
build:            ; @echo "TODO: configure build for $(STACK)"
run:              ; @echo "TODO: configure run for $(STACK)"
smoke-test:       ; @echo "TODO: configure smoke-test"
endif

# These targets always run (they validate the template itself or run in CI).
secret-scan:      ; @echo "[stub] gitleaks runs in CI (.github/workflows/secret-scan.yml)"
security: secret-scan dependency-scan container-scan iac-scan
docs-check:       ; @sh scripts/ci-local.sh
ci: format-check lint docs-check
	@echo "[ci] local gate (best-effort) complete"
