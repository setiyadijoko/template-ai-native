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

Python and .NET are intentionally not changed speculatively: the template has
no consumer dependency file, and a cache key without a committed lockfile can
reuse stale dependencies. Enable the cache together with the consumer's
dependency and runtime pinning.

## Upgrade process

1. Change one runtime or action pin at a time.
2. Review the upstream release and security advisories.
3. Run the complete local and CI validation gates.
4. Record material compatibility or rollback impact in an ADR or technical
   debt entry.
