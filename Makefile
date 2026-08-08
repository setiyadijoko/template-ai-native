SHELL := /bin/sh
STACK := $(shell sh scripts/detect-stack.sh)

.PHONY: setup dev format format-check lint typecheck \
        test test-unit test-contract test-integration test-e2e test-coverage \
        eval eval-regression eval-safety \
        security secret-scan dependency-scan container-scan iac-scan \
        build run smoke-test docs-check readiness-check project-config-check ci test-scripts

# When no stack is detected, targets that need a toolchain no-op cleanly.
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
build:            ; @echo "[skip] no stack detected — wire src/ to enable build"
run:              ; @echo "[skip] no stack detected — wire src/ to enable run"
smoke-test:       ; @echo "[skip] no stack detected — wire src/ to enable smoke-test"
else
# Real commands for the detected stack, resolved via scripts/stack-tools.sh.
# Swap a tool by editing scripts/stack-tools.sh (single source of truth).
setup:            ; @echo "setup ready for $(STACK) (configure bootstrap as needed)"
dev:              ; @echo "configure dev server for $(STACK)"
format:           ; @sh -c "$$(sh scripts/stack-tools.sh format)"
format-check:     ; @sh -c "$$(sh scripts/stack-tools.sh format-check)"
lint:             ; @sh -c "$$(sh scripts/stack-tools.sh lint)"
typecheck:        ; @sh -c "$$(sh scripts/stack-tools.sh typecheck)"
test:             ; @sh -c "$$(sh scripts/stack-tools.sh test-unit)"
test-unit:        ; @sh -c "$$(sh scripts/stack-tools.sh test-unit)"
test-contract:    ; @sh -c "$$(sh scripts/stack-tools.sh test-integration)"
test-integration: ; @sh -c "$$(sh scripts/stack-tools.sh test-integration)"
test-e2e:         ; @sh -c "$$(sh scripts/stack-tools.sh test-e2e)"
test-coverage:    ; @sh -c "$$(sh scripts/stack-tools.sh coverage)"
eval:             ; @echo "configure AI eval for $(STACK)"
eval-regression:  ; @echo "configure eval-regression"
eval-safety:      ; @echo "configure eval-safety"
build:            ; @sh -c "$$(sh scripts/stack-tools.sh build)"
run:              ; @echo "configure run for $(STACK)"
smoke-test:       ; @echo "configure smoke-test"
endif

# These targets always run (they validate the template itself or run in CI).
secret-scan:      ; @command -v gitleaks >/dev/null 2>&1 && gitleaks detect --source . --no-banner || echo "[stub] gitleaks runs in CI (.github/workflows/secret-scan.yml)"
dependency-scan:  ; @echo "[stub] dependency-review + dependency-audit run in CI (.github/workflows/dependency-review.yml, dependency-audit.yml)"
container-scan:   ; @echo "[stub] trivy runs in CI when containers exist"
iac-scan:         ; @echo "[stub] checkov runs in CI when IaC exists"
security: secret-scan dependency-scan container-scan iac-scan
docs-check:       ; @sh scripts/ci-local.sh
readiness-check:   ; @sh scripts/validate-production-readiness.sh
project-config-check: ; @sh scripts/validate-project-config.sh
test-scripts:
	@sh scripts/test/test-stack-detection.sh
	@sh scripts/test/test-delivery-workflows.sh
	@sh scripts/test/test-security-workflows.sh
	@sh scripts/test/test-production-readiness.sh
	@sh scripts/test/test-code-review-graph.sh
	@sh scripts/test/test-graphify-integration.sh
	@sh scripts/test/test-branch-protection.sh
	@sh scripts/test/test-prompt-eval-assets.sh
	@sh scripts/test/test-init-project.sh
	@sh scripts/test/test-project-config.sh
	@sh scripts/test/test-openapi-contract.sh
ci: format-check lint docs-check readiness-check project-config-check test-scripts
	@echo "[ci] local gate (best-effort) complete"
