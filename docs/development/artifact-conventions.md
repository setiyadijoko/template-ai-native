# Build artifact conventions

**Status:** Consumer guidance. The template does not select a framework or
deployment target for you.

The reusable build workflow packages one deterministic artifact per selected
stack. For Node.js, the generic packaging boundary currently includes `dist/`
and `build/`. A consumer that uses a framework with a different output
directory must either configure that framework to emit one of those directories
or update the consumer-owned packaging step before enabling release or deploy
workflows.

| Framework | Typical build output | Consumer packaging action |
|---|---|---|
| Next.js | `.next/` (or `.next/standalone` with `output: "standalone"`) | Keep the required `.next` runtime/static files together, or configure a consumer-owned artifact step; it is not auto-selected by the generic Node packaging contract. |
| Nuxt | `.output/` | Package `.output/` with the selected Nitro preset, or adapt the consumer-owned artifact step; it is not auto-selected by the generic Node packaging contract. |
| Angular | `dist/<project>/` | Confirm the configured `outputPath` under `dist/`; the generic `dist/` convention can include it. |

## Python package output

A Python dependency boundary may be the repository root or direct `src/`, but
not both. Package builds additionally require `pyproject.toml` or `setup.py` at
that boundary; requirements files and `Pipfile` can identify a dependency
boundary without defining a buildable package. Root projects produce `dist/`;
direct-src projects produce `src/dist/`.

Packaging preserves those literal archive member paths: `dist/` for a root
project and `src/dist/` for a direct-src project. The uploaded artifact name
remains `build-python` in both layouts for the single-stack workflow. Version-2
components retain their declared component artifact identity. This layout
support does not change pytest discovery, workflow permissions, provenance
inputs, or deployment readiness.

## Artifact identity

Use the component or stack artifact name as the stable Actions artifact identity
(`build-node` for a single Node.js project, or the declared component artifact
for a version-2 monorepo). Promotion must use the exact artifact validated in
staging; do not rebuild a different framework output for production.

Before enabling deployment, document the runtime entrypoint, required static
assets, environment variables, health endpoint, and rollback artifact for the
chosen framework. The deploy and smoke-test workflows remain skeletons until a
consumer wires those platform-specific steps.
