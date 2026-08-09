# Version pinning and CI cache policy

## Actions and toolchains

Pin third-party GitHub Actions to immutable commit SHAs and document the
release tag in a trailing comment. The repository workflows follow this rule;
do not replace a SHA with a floating tag such as `@main`.

Runtime toolchains must also be made reproducible by the consumer. The current
template has these cache behaviors:

| Stack | Current CI cache | Consumer action |
|---|---|---|
| Node.js | `setup-node` with `cache: npm` | Commit the lockfile and keep the package-manager cache path stable. |
| Go | `setup-go` with `cache: true` | Commit `go.sum`; keep `go.mod` at the detected project location. |
| Java | `setup-java` with `cache: maven` | Commit the Maven wrapper or pin the Maven version used by the project. |
| Python | No default cache | Add `cache: pip` and an explicit `cache-dependency-path` after choosing the requirements/lockfile format. |
| .NET | No default cache | Add a NuGet cache keyed by `packages.lock.json` or the selected lockfile after adopting the stack. |

Python and .NET caching is intentionally not enabled speculatively: a cache key
without a committed consumer lockfile can reuse stale dependencies. Enable the
cache together with the consumer's dependency and runtime pinning.

## Python CI dependency contract

Python consumers own their runtime and development versions. The shared
`scripts/setup-python-deps.sh` installs those dependencies before inherited
quality, test, and build commands run. When the consumer has not supplied a
required CI tool, the helper uses these repository-controlled fallbacks from
`scripts/python-ci-tools.txt`:

| Tool | Fallback version |
|---|---|
| Ruff | 0.15.22 |
| mypy | 2.3.0 |
| pytest | 9.1.1 |
| pytest-cov | 7.1.0 |
| build | 1.5.0 |

The helper checks import availability after installing consumer dependencies;
it does not replace a compatible consumer-provided tool merely because its
version differs from the fallback. Review fallback upgrades like any other CI
toolchain change.

No default pip cache is enabled. Cache activation requires a committed lock or
constraints file and an explicit `cache-dependency-path`. A Pipfile alone is
not a reproducible hosted-install contract; adopt and document a pinned Pipenv
toolchain plus `Pipfile.lock` before adding that path.

## Upgrade process

1. Change one runtime or action pin at a time.
2. Review the upstream release and security advisories.
3. Run the complete local and CI validation gates.
4. Record material compatibility or rollback impact in an ADR or technical
   debt entry.
