# Glossary

**Status:** Template baseline — extend with project-specific terms.

Shared terminology for `template-ai-native`.

| Term | Definition |
|---|---|
| ADR | Architecture Decision Record — a dated, traceable record of an architecture decision and its consequences. |
| AGENTS.md | The canonical instruction file every AI coding agent must read before modifying the repo. |
| DoR / DoD | Definition of Ready / Definition of Done. |
| Eval | An AI evaluation — deterministic or model-based check of AI behavior (regression, safety, leakage, cost). |
| Guardrail | A runtime check that constrains AI output (e.g. schema validation, prompt-injection defense). |
| LLM | Large Language Model. |
| OIDC | OpenID Connect — used here for short-lived deployment credentials instead of long-lived cloud keys. |
| Prompt registry | A versioned catalog of production prompts (`prompts/registry.yaml`) with metadata per prompt. |
| Prompt injection | An attack where untrusted text causes a model to execute unintended instructions. |
| RAG | Retrieval-Augmented Generation — supplying retrieved context to a model at inference time. |
| RPO / RTO | Recovery Point Objective / Recovery Time Objective (disaster recovery). |
| SBOM | Software Bill of Materials — inventory of components in a build artifact (SPDX or CycloneDX). |
| SLO / SLI | Service Level Objective / Service Level Indicator. |
| Stack-agnostic | The template commits no programming language or framework; consumers adopt their own. |
| Structured output | Schema-constrained model output that is validated before use. |
