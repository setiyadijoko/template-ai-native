# Hosted Java Consumer Pilot Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prove the template's single-stack Java 21/Maven path on a fresh public consumer pull request and post-merge GitHub-hosted run, including JAR artifact and provenance attestation evidence.

**Architecture:** Create `setiyadinamikaintegrasi/template-java-pilot` from the published template, then add a framework-free deterministic classifier with pinned Maven quality and test plugins. Validate locally, observe the inherited hosted workflows without weakening them, require human approval before merge, and record only actual PR/main/attestation evidence back in the template roadmap.

**Tech Stack:** Java 21, Maven, JUnit Jupiter 5.11.4, Spotless Maven Plugin 2.44.3, Maven Checkstyle Plugin 3.6.0 with Checkstyle 10.21.2, Maven Surefire Plugin 3.5.2, JaCoCo Maven Plugin 0.8.12, GitHub Actions, GitHub CLI.

## Global Constraints

- Create the public consumer from `setiyadijoko/template-ai-native` with GitHub's template flow; do not copy selected files into an empty repository.
- Use repository `setiyadinamikaintegrasi/template-java-pilot`, branch `pilot/java-ci-contract`, Java release 21, Maven, and a root `pom.xml`.
- Record `.template/project.yaml` as version 1, layout `single`, primary stack `java`, and primary path `.`; do not add a profile configuration.
- Keep the application framework-free, deterministic, credential-free, and independent of network, database, filesystem, clock, cloud, and deployment services.
- Provide real `*Test`, `*IT`, and `*E2E` behavior tests and enforce overall JaCoCo line coverage of at least 80%.
- Preserve every inherited workflow permission, immutable Action pin, security threshold, check context, artifact identity, and attestation input.
- Never disable or skip a Java quality, test, coverage, build, or security check to make the pilot green.
- Treat a consumer configuration failure in the pilot; treat a template contract failure in a separate reviewed template change.
- Do not claim hosted success until the corresponding GitHub run completed successfully.
- Human approval is required before merging the consumer pull request.
- Do not delete the consumer repository; it remains public evidence unless the project owner explicitly authorizes deletion.

---

## File structure

### Consumer repository: `setiyadinamikaintegrasi/template-java-pilot`

**Create:**

- `pom.xml` — pinned Java build, quality, test, and coverage contract.
- `src/main/java/id/setiyadinamika/pilot/ticket/Priority.java` — priority result enum.
- `src/main/java/id/setiyadinamika/pilot/ticket/TicketPriorityClassifier.java` — deterministic input validation and classification.
- `src/test/java/id/setiyadinamika/pilot/ticket/TicketPriorityClassifierTest.java` — unit behavior and validation.
- `src/test/java/id/setiyadinamika/pilot/ticket/TicketPriorityClassifierIT.java` — public-boundary normalization contract.
- `src/test/java/id/setiyadinamika/pilot/ticket/TicketPriorityClassifierE2E.java` — complete request-to-priority journeys.

**Modify:**

- `README.md` — generated identity plus explicit hosted-pilot objective.
- `.template/project.yaml` — generated single Java root layout.
- `PRODUCT.md` — consumer purpose, users, scope, and success evidence.
- `DESIGN.md` — approved classifier rules and acceptance criteria.
- `ARCHITECTURE.md` — runtime/toolchain boundaries and data flow.
- `.gitignore` — ignore Maven `target/` output.

### Template repository: `setiyadijoko/template-ai-native`

**Modify after hosted proof:**

- `docs/plans/roadmap.md` — actual consumer PR, main run, artifact, attestation, runtime/noise, and limitation evidence.
- `docs/superpowers/specs/2026-08-10-hosted-java-consumer-pilot-design.md` — mark verified only after post-merge evidence passes.

---

### Task 1: Create and personalize the consumer repository

**Files:**

- Modify: consumer `README.md`
- Create: consumer `.template/project.yaml` through the initializer
- Modify: consumer `PRODUCT.md`
- Modify: consumer `DESIGN.md`
- Modify: consumer `ARCHITECTURE.md`
- Modify: consumer `.gitignore`

**Interfaces:**

- Produces: public repository `setiyadinamikaintegrasi/template-java-pilot`, local checkout `/tmp/template-java-pilot-hosted-pilot`, and branch `pilot/java-ci-contract`.
- Produces: version-1 single-stack config consumed by the inherited resolver and hosted dispatcher.
- Preserves: the exact template history and all inherited workflows.

- [ ] **Step 1: Prove the target and local checkout do not already exist**

Run:

```sh
if gh repo view setiyadinamikaintegrasi/template-java-pilot >/dev/null 2>&1; then
  printf '%s\n' 'repository already exists; stop instead of overwriting external state' >&2
  exit 65
fi
if [ -e /tmp/template-java-pilot-hosted-pilot ]; then
  printf '%s\n' 'local pilot path already exists; stop instead of deleting it' >&2
  exit 65
fi
```

Expected: exit 0 with no output.

- [ ] **Step 2: Create the public repository through the template flow**

Run:

```sh
gh repo create setiyadinamikaintegrasi/template-java-pilot \
  --public \
  --template setiyadijoko/template-ai-native \
  --description "Hosted Java 21/Maven consumer pilot for template-ai-native CI, security, artifact, and attestation validation."
gh repo view setiyadinamikaintegrasi/template-java-pilot \
  --json nameWithOwner,isPrivate,url,defaultBranchRef
```

Expected: `nameWithOwner` is `setiyadinamikaintegrasi/template-java-pilot`, `isPrivate` is false, and the default branch is `main`.

- [ ] **Step 3: Clone and create the pilot branch**

Run:

```sh
git clone https://github.com/setiyadinamikaintegrasi/template-java-pilot.git \
  /tmp/template-java-pilot-hosted-pilot
cd /tmp/template-java-pilot-hosted-pilot
git checkout -b pilot/java-ci-contract
git status --short --branch
```

Expected: clean branch `pilot/java-ci-contract`.

- [ ] **Step 4: Run the initializer with the exact single-root contract**

Run from `/tmp/template-java-pilot-hosted-pilot`:

```sh
sh scripts/init-project.sh \
  --name "Template Java Pilot" \
  --description "Hosted Java 21 and Maven validation for the template-ai-native consumer pipeline." \
  --stack java \
  --layout single \
  --primary-path .
```

Expected generated config:

```yaml
# Generated by scripts/init-project.sh; keep credentials out of this file.
version: 1
layout: single
primary_stack: java
primary_path: .
```

- [ ] **Step 5: Replace `PRODUCT.md` with the consumer product baseline**

Use `apply_patch` to make `PRODUCT.md` exactly:

```markdown
# Template Java Pilot Product

**Status:** Hosted validation pilot

## Product vision

Provide auditable evidence that a fresh Java 21/Maven consumer can adopt the
template-ai-native quality, security, build, artifact, and provenance controls
without framework or infrastructure dependencies.

## Users

- Template maintainers evaluating Java adoption readiness.
- Consumer engineers deciding whether the generic Java baseline is usable.
- Security and platform reviewers checking inherited controls.

## Business value

Reduce adoption risk by detecting Java-specific workflow gaps before a real
service depends on the template.

## Scope

- Deterministic ticket-priority domain logic.
- Unit, integration, E2E, coverage, quality, build, and hosted security checks.
- JAR artifact and post-merge provenance evidence.

## Out of scope

- Production service behavior, HTTP, persistence, authentication, deployment,
  AI providers, profile activation, and operational readiness.

## Success metrics

- Every applicable Java PR job executes and passes.
- Overall line coverage is at least 80%.
- A Java build artifact and post-merge attestation are produced.
- No inherited security control is weakened.
```

- [ ] **Step 6: Replace `DESIGN.md` with the approved consumer design**

Use `apply_patch` to make `DESIGN.md` exactly:

```markdown
# Template Java Pilot Design

**Status:** Approved 2026-08-10

## Problem

Local mapper contracts do not prove that the inherited Java workflow succeeds
on GitHub-hosted runners with a real Maven consumer.

## Decision

Implement a framework-free `TicketPriorityClassifier` on Java 21. It accepts
severity, customer impact, and a security-incident flag and returns `P1`, `P2`,
`P3`, or `P4`.

## Business rules

1. A security incident or critical severity returns `P1`.
2. High severity or business-wide impact returns `P2`.
3. Medium severity or multiple-user impact returns `P3`.
4. All other supported combinations return `P4`.
5. Blank and unsupported values fail with `IllegalArgumentException`.
6. The public boundary accepts case-insensitive values, surrounding whitespace,
   and hyphenated enum words.

## Quality contract

- Java release 21 and explicitly pinned Maven plugins.
- Spotless formatting and Google Checkstyle validation.
- JUnit unit, integration, and E2E behavior tests.
- JaCoCo overall line coverage of at least 80%.
- Standard JAR output under `target/`.

## Security and data

The classifier uses synthetic inputs, requires no credential, performs no I/O,
and has no external integration.

## Acceptance criteria

The pull request must execute and pass Java quality, test, coverage, build,
CodeQL, OSV, secret, documentation, metadata, and workflow-security controls.
After human-approved merge, the main workflow must create a Java artifact and
provenance attestation.
```

- [ ] **Step 7: Replace `ARCHITECTURE.md` with the consumer architecture**

Use `apply_patch` to make `ARCHITECTURE.md` exactly:

```markdown
# Template Java Pilot Architecture

**Status:** Hosted validation pilot

## Runtime boundary

The runtime consists only of the pure Java `TicketPriorityClassifier` and its
`Priority` result enum. There is no server, database, queue, cache, filesystem,
network, provider, or deployment boundary.

## Build boundary

The root `pom.xml` owns Java 21 compilation, JUnit, Spotless, Checkstyle,
JaCoCo, Surefire, and JAR output. The inherited template mapper invokes Maven;
the consumer does not replace workflow commands.

## Data flow

```text
severity + customer impact + security flag
                    |
                    v
        TicketPriorityClassifier
                    |
                    v
             P1 | P2 | P3 | P4
```

Invalid input stops at the classifier boundary with `IllegalArgumentException`.
No input is stored or transmitted.

## Delivery boundary

GitHub Actions runs inherited quality, test, security, build, and attestation
workflows. Deployment and smoke-test workflows remain unwired and out of scope.
```

- [ ] **Step 8: Add the README objective and Maven ignore rule**

Use `apply_patch` to add this section immediately after the generated identity
block in `README.md`:

```markdown
## Pilot evidence objective

This public consumer validates the inherited Java 21/Maven quality, test,
security, build-artifact, and post-merge provenance paths on GitHub-hosted
runners. It is intentionally framework-free and is not a production service.
```

Use `apply_patch` to add this build-artifact entry under `.gitignore`'s build
artifact section:

```gitignore
target/
```

- [ ] **Step 9: Validate adoption state and commit**

Run:

```sh
sh scripts/validate-project-config.sh
grep -F '# Template Java Pilot' README.md PRODUCT.md DESIGN.md ARCHITECTURE.md
test "$(git diff --name-only | sort | tr '\n' ' ')" = ".gitignore .template/project.yaml ARCHITECTURE.md DESIGN.md PRODUCT.md README.md "
git diff --check
git add .gitignore .template/project.yaml ARCHITECTURE.md DESIGN.md PRODUCT.md README.md
git commit -m "docs: initialize hosted Java pilot"
```

Expected: project config valid, no whitespace error, and one six-file consumer
adoption commit.

---

### Task 2: Add the pinned Maven contract and unit-tested domain rules

**Files:**

- Create: consumer `pom.xml`
- Create: consumer `src/main/java/id/setiyadinamika/pilot/ticket/Priority.java`
- Create: consumer `src/main/java/id/setiyadinamika/pilot/ticket/TicketPriorityClassifier.java`
- Create: consumer `src/test/java/id/setiyadinamika/pilot/ticket/TicketPriorityClassifierTest.java`

**Interfaces:**

- Produces: `Priority TicketPriorityClassifier.classify(String severity, String impact, boolean securityIncident)`.
- Produces: root Maven JAR project consumed by inherited stack detection, quality, test, coverage, and build commands.
- Defers: case/whitespace/hyphen normalization to Task 3's public-boundary contract.

- [ ] **Step 1: Add the exact pinned `pom.xml`**

Use `apply_patch` to create:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd">
  <modelVersion>4.0.0</modelVersion>

  <groupId>id.setiyadinamika.pilot</groupId>
  <artifactId>template-java-pilot</artifactId>
  <version>0.1.0-SNAPSHOT</version>
  <name>Template Java Pilot</name>
  <description>Hosted Java consumer validation for template-ai-native.</description>

  <properties>
    <maven.compiler.release>21</maven.compiler.release>
    <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
    <junit.version>5.11.4</junit.version>
    <compiler.version>3.13.0</compiler.version>
    <surefire.version>3.5.2</surefire.version>
    <spotless.version>2.44.3</spotless.version>
    <google-java-format.version>1.25.2</google-java-format.version>
    <checkstyle-plugin.version>3.6.0</checkstyle-plugin.version>
    <checkstyle.version>10.21.2</checkstyle.version>
    <jacoco.version>0.8.12</jacoco.version>
  </properties>

  <dependencies>
    <dependency>
      <groupId>org.junit.jupiter</groupId>
      <artifactId>junit-jupiter</artifactId>
      <version>${junit.version}</version>
      <scope>test</scope>
    </dependency>
  </dependencies>

  <build>
    <plugins>
      <plugin>
        <groupId>org.apache.maven.plugins</groupId>
        <artifactId>maven-compiler-plugin</artifactId>
        <version>${compiler.version}</version>
      </plugin>
      <plugin>
        <groupId>org.apache.maven.plugins</groupId>
        <artifactId>maven-surefire-plugin</artifactId>
        <version>${surefire.version}</version>
        <configuration>
          <failIfNoTests>true</failIfNoTests>
          <useModulePath>false</useModulePath>
        </configuration>
      </plugin>
      <plugin>
        <groupId>com.diffplug.spotless</groupId>
        <artifactId>spotless-maven-plugin</artifactId>
        <version>${spotless.version}</version>
        <configuration>
          <java>
            <googleJavaFormat>
              <version>${google-java-format.version}</version>
            </googleJavaFormat>
          </java>
        </configuration>
      </plugin>
      <plugin>
        <groupId>org.apache.maven.plugins</groupId>
        <artifactId>maven-checkstyle-plugin</artifactId>
        <version>${checkstyle-plugin.version}</version>
        <configuration>
          <configLocation>google_checks.xml</configLocation>
          <includeTestSourceDirectory>true</includeTestSourceDirectory>
          <failOnViolation>true</failOnViolation>
        </configuration>
        <dependencies>
          <dependency>
            <groupId>com.puppycrawl.tools</groupId>
            <artifactId>checkstyle</artifactId>
            <version>${checkstyle.version}</version>
          </dependency>
        </dependencies>
      </plugin>
    </plugins>
  </build>

  <profiles>
    <profile>
      <id>coverage</id>
      <build>
        <plugins>
          <plugin>
            <groupId>org.jacoco</groupId>
            <artifactId>jacoco-maven-plugin</artifactId>
            <version>${jacoco.version}</version>
            <executions>
              <execution>
                <id>prepare-agent</id>
                <goals>
                  <goal>prepare-agent</goal>
                </goals>
              </execution>
              <execution>
                <id>report</id>
                <phase>verify</phase>
                <goals>
                  <goal>report</goal>
                </goals>
              </execution>
              <execution>
                <id>check</id>
                <phase>verify</phase>
                <goals>
                  <goal>check</goal>
                </goals>
                <configuration>
                  <rules>
                    <rule>
                      <element>BUNDLE</element>
                      <limits>
                        <limit>
                          <counter>LINE</counter>
                          <value>COVEREDRATIO</value>
                          <minimum>0.80</minimum>
                        </limit>
                      </limits>
                    </rule>
                  </rules>
                </configuration>
              </execution>
            </executions>
          </plugin>
        </plugins>
      </build>
    </profile>
  </profiles>
</project>
```

- [ ] **Step 2: Write the failing unit behavior contract**

Use `apply_patch` to create
`src/test/java/id/setiyadinamika/pilot/ticket/TicketPriorityClassifierTest.java`:

```java
package id.setiyadinamika.pilot.ticket;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

import org.junit.jupiter.api.Test;

class TicketPriorityClassifierTest {
  private final TicketPriorityClassifier classifier = new TicketPriorityClassifier();

  @Test
  void securityIncidentIsP1() {
    assertEquals(Priority.P1, classifier.classify("LOW", "SINGLE_USER", true));
  }

  @Test
  void criticalSeverityIsP1() {
    assertEquals(Priority.P1, classifier.classify("CRITICAL", "SINGLE_USER", false));
  }

  @Test
  void highSeverityIsP2() {
    assertEquals(Priority.P2, classifier.classify("HIGH", "SINGLE_USER", false));
  }

  @Test
  void businessWideImpactIsP2() {
    assertEquals(Priority.P2, classifier.classify("LOW", "BUSINESS_WIDE", false));
  }

  @Test
  void mediumSeverityIsP3() {
    assertEquals(Priority.P3, classifier.classify("MEDIUM", "SINGLE_USER", false));
  }

  @Test
  void multipleUserImpactIsP3() {
    assertEquals(Priority.P3, classifier.classify("LOW", "MULTIPLE_USERS", false));
  }

  @Test
  void lowSingleUserTicketIsP4() {
    assertEquals(Priority.P4, classifier.classify("LOW", "SINGLE_USER", false));
  }

  @Test
  void blankSeverityFailsClosed() {
    IllegalArgumentException error =
        assertThrows(
            IllegalArgumentException.class,
            () -> classifier.classify(" ", "SINGLE_USER", false));
    assertEquals("severity is required", error.getMessage());
  }

  @Test
  void unsupportedImpactFailsClosed() {
    IllegalArgumentException error =
        assertThrows(
            IllegalArgumentException.class,
            () -> classifier.classify("LOW", "CONTINENT", false));
    assertEquals("unsupported impact: CONTINENT", error.getMessage());
  }
}
```

- [ ] **Step 3: Run the unit contract to verify RED**

Run:

```sh
mvn -q -Dtest=TicketPriorityClassifierTest test
```

Expected: non-zero compilation failure because `TicketPriorityClassifier` and
`Priority` do not exist.

- [ ] **Step 4: Add the minimal priority enum**

Use `apply_patch` to create
`src/main/java/id/setiyadinamika/pilot/ticket/Priority.java`:

```java
package id.setiyadinamika.pilot.ticket;

public enum Priority {
  P1,
  P2,
  P3,
  P4
}
```

- [ ] **Step 5: Add the minimal exact-value classifier**

Use `apply_patch` to create
`src/main/java/id/setiyadinamika/pilot/ticket/TicketPriorityClassifier.java`:

```java
package id.setiyadinamika.pilot.ticket;

public final class TicketPriorityClassifier {
  private enum Severity {
    LOW,
    MEDIUM,
    HIGH,
    CRITICAL
  }

  private enum Impact {
    SINGLE_USER,
    MULTIPLE_USERS,
    BUSINESS_WIDE
  }

  public Priority classify(String severityValue, String impactValue, boolean securityIncident) {
    Severity severity = parse("severity", severityValue, Severity.class);
    Impact impact = parse("impact", impactValue, Impact.class);

    if (securityIncident || severity == Severity.CRITICAL) {
      return Priority.P1;
    }
    if (severity == Severity.HIGH || impact == Impact.BUSINESS_WIDE) {
      return Priority.P2;
    }
    if (severity == Severity.MEDIUM || impact == Impact.MULTIPLE_USERS) {
      return Priority.P3;
    }
    return Priority.P4;
  }

  private static <T extends Enum<T>> T parse(String field, String value, Class<T> type) {
    if (value == null || value.isBlank()) {
      throw new IllegalArgumentException(field + " is required");
    }
    try {
      return Enum.valueOf(type, value);
    } catch (IllegalArgumentException error) {
      throw new IllegalArgumentException("unsupported " + field + ": " + value, error);
    }
  }
}
```

- [ ] **Step 6: Format and verify GREEN**

Run:

```sh
mvn -q spotless:apply
mvn -q -Dtest=TicketPriorityClassifierTest test
mvn -q spotless:check
mvn -q checkstyle:check
mvn -q compile
```

Expected: every command exits 0 and the nine unit tests pass.

- [ ] **Step 7: Pin the inherited mapper contract and commit**

Run:

```sh
test "$(sh scripts/detect-stack.sh)" = "java"
test "$(sh scripts/stack-tools.sh format-check)" = "mvn -q spotless:check"
test "$(sh scripts/stack-tools.sh lint)" = "mvn -q checkstyle:check"
test "$(sh scripts/stack-tools.sh typecheck)" = "mvn -q compile"
test "$(sh scripts/stack-tools.sh test-unit)" = "mvn -q test"
test "$(sh scripts/stack-tools.sh build)" = "mvn -q -DskipTests package"
git diff --check
git add pom.xml src/main src/test/java/id/setiyadinamika/pilot/ticket/TicketPriorityClassifierTest.java
git commit -m "feat: add Java priority classifier"
```

Expected: one code/toolchain commit with no generated `target/` files staged.

---

### Task 3: Add boundary normalization, integration/E2E tests, and full local gates

**Files:**

- Modify: consumer `src/main/java/id/setiyadinamika/pilot/ticket/TicketPriorityClassifier.java`
- Create: consumer `src/test/java/id/setiyadinamika/pilot/ticket/TicketPriorityClassifierIT.java`
- Create: consumer `src/test/java/id/setiyadinamika/pilot/ticket/TicketPriorityClassifierE2E.java`

**Interfaces:**

- Consumes: `Priority TicketPriorityClassifier.classify(String, String, boolean)` from Task 2.
- Produces: case-insensitive, whitespace-tolerant, and hyphen-normalized public boundary.
- Produces: the three exact test categories consumed by inherited Java CI.

- [ ] **Step 1: Write the failing integration boundary contract**

Use `apply_patch` to create
`src/test/java/id/setiyadinamika/pilot/ticket/TicketPriorityClassifierIT.java`:

```java
package id.setiyadinamika.pilot.ticket;

import static org.junit.jupiter.api.Assertions.assertEquals;

import org.junit.jupiter.api.Test;

class TicketPriorityClassifierIT {
  @Test
  void normalizesPublicBoundaryValues() {
    TicketPriorityClassifier classifier = new TicketPriorityClassifier();

    assertEquals(Priority.P2, classifier.classify(" high ", "single-user", false));
  }
}
```

- [ ] **Step 2: Run the integration contract to verify RED**

Run:

```sh
mvn -q verify -Dtest='*IT'
```

Expected: non-zero test failure with an unsupported severity error for
`" high "`.

- [ ] **Step 3: Implement minimal boundary normalization**

Use `apply_patch` to add this import to
`TicketPriorityClassifier.java`:

```java
import java.util.Locale;
```

Replace the `Enum.valueOf` argument inside `parse` with:

```java
String normalized = value.trim().toUpperCase(Locale.ROOT).replace('-', '_');
```

and then:

```java
return Enum.valueOf(type, normalized);
```

Keep error messages based on the original `value`, not the normalized value.

- [ ] **Step 4: Verify the integration contract is GREEN**

Run:

```sh
mvn -q spotless:apply
mvn -q verify -Dtest='*IT'
```

Expected: exit 0 and one integration test passes.

- [ ] **Step 5: Add complete E2E journeys**

Use `apply_patch` to create
`src/test/java/id/setiyadinamika/pilot/ticket/TicketPriorityClassifierE2E.java`:

```java
package id.setiyadinamika.pilot.ticket;

import static org.junit.jupiter.api.Assertions.assertEquals;

import java.util.List;
import org.junit.jupiter.api.Test;

class TicketPriorityClassifierE2E {
  private record Scenario(
      String severity, String impact, boolean securityIncident, Priority expected) {}

  @Test
  void classifiesRepresentativeTicketJourneys() {
    TicketPriorityClassifier classifier = new TicketPriorityClassifier();
    List<Scenario> scenarios =
        List.of(
            new Scenario("low", "single-user", true, Priority.P1),
            new Scenario("critical", "single-user", false, Priority.P1),
            new Scenario("high", "multiple-users", false, Priority.P2),
            new Scenario("low", "business-wide", false, Priority.P2),
            new Scenario("medium", "single-user", false, Priority.P3),
            new Scenario("low", "multiple-users", false, Priority.P3),
            new Scenario("low", "single-user", false, Priority.P4));

    for (Scenario scenario : scenarios) {
      assertEquals(
          scenario.expected(),
          classifier.classify(
              scenario.severity(), scenario.impact(), scenario.securityIncident()));
    }
  }
}
```

- [ ] **Step 6: Run every inherited Java command locally**

Run:

```sh
mvn -q spotless:check
mvn -q checkstyle:check
mvn -q compile
mvn -q test
mvn -q verify -Dtest='*IT'
mvn -q verify -Dtest='*E2E'
mvn -q verify -Pcoverage
mvn -q -DskipTests package
test -f target/template-java-pilot-0.1.0-SNAPSHOT.jar
test -f target/site/jacoco/jacoco.xml
```

Expected: all commands exit 0, coverage is at least 80%, and both files exist.

- [ ] **Step 7: Run repository-native gates and commit**

Run:

```sh
make test-scripts
make docs-check
make ci
git diff --check
test -z "$(git status --short | grep '^?? target/' || true)"
git add src/main/java/id/setiyadinamika/pilot/ticket/TicketPriorityClassifier.java \
  src/test/java/id/setiyadinamika/pilot/ticket/TicketPriorityClassifierIT.java \
  src/test/java/id/setiyadinamika/pilot/ticket/TicketPriorityClassifierE2E.java
git commit -m "test: cover Java integration and e2e paths"
git status --short --branch
```

Expected: full local gates pass and the branch is clean after the third
consumer commit.

---

### Task 4: Publish the consumer pull request and verify hosted PR checks

**Files:**

- No repository file change is required unless a hosted failure proves a
  consumer defect.
- Create local temporary PR body: `/tmp/template-java-pilot-pr.md`.

**Interfaces:**

- Consumes: clean consumer branch with three reviewed commits.
- Produces: draft consumer pull request and a complete hosted-check inventory.
- Stops: on a template defect, external-service failure, or security-policy
  conflict; do not silently remediate the template from the consumer branch.

- [ ] **Step 1: Re-run publication preflight**

Run from `/tmp/template-java-pilot-hosted-pilot`:

```sh
git status --short --branch
git log --oneline main..HEAD
git diff --check main..HEAD
gh auth status
```

Expected: clean `pilot/java-ci-contract`, exactly three consumer commits, no
diff errors, and active GitHub authentication with access to the organization.

- [ ] **Step 2: Create the exact pull-request body**

Use `apply_patch` to create `/tmp/template-java-pilot-pr.md`:

```markdown
## Business purpose

Validate the published template-ai-native Java 21/Maven path on a fresh public
consumer using GitHub-hosted runners.

## Scope

- Single-stack Java consumer initialized at repository root.
- Pinned Maven quality, test, coverage, and JAR build contract.
- Deterministic ticket-priority classifier.
- Unit, integration, and E2E behavior tests.

## Out of scope

Frameworks, HTTP, persistence, authentication, AI providers, deployment,
profile activation, and production-readiness claims.

## Testing performed

- Spotless, Checkstyle, Java 21 compilation.
- Unit, integration, and E2E Maven test categories.
- JaCoCo coverage profile with an 80% line threshold.
- Maven package and JAR existence check.
- `make test-scripts`, `make docs-check`, `make ci`, and `git diff --check`.

## Risk and rollback

Low: synthetic deterministic code with no data or integration. Revert the
consumer commits or close this pilot PR; no external runtime resource exists.

## Confirmations

- [x] No secret or sensitive data is committed.
- [x] No inherited workflow or security control is weakened.
- [x] Hosted results will be reported only after GitHub completes them.
```

- [ ] **Step 3: Push and create the draft PR**

Run:

```sh
git push -u origin pilot/java-ci-contract
PILOT_PR_URL="$(gh pr create \
  --draft \
  --base main \
  --head pilot/java-ci-contract \
  --title "test: validate hosted Java consumer pipeline" \
  --body-file /tmp/template-java-pilot-pr.md)"
printf '%s\n' "$PILOT_PR_URL"
gh pr view "$PILOT_PR_URL" \
  --json number,title,url,state,isDraft,baseRefName,headRefName
```

Expected: one open draft PR from `pilot/java-ci-contract` to `main`.

- [ ] **Step 4: Watch the hosted check set to completion**

Run:

```sh
gh pr checks "$PILOT_PR_URL" --watch --interval 10
gh pr view "$PILOT_PR_URL" --json statusCheckRollup
```

Expected Java contract:

- Detect stack: success and reports Java.
- Java quality: success, not skipped.
- Java integration/E2E/coverage: success, not skipped.
- Java build: success, not skipped.
- CodeQL, OSV, secret scan, metadata, docs, actionlint, and zizmor: success.
- Component-aware monorepo and attestation: skipped on the pull request by
  documented design.
- Advisory graph/AI checks may run, skip, or report separately without changing
  the deterministic Java verdict.

- [ ] **Step 5: Classify any hosted failure before changing code**

If a check fails, capture evidence first:

```sh
PILOT_PR_NUMBER="$(gh pr view "$PILOT_PR_URL" --json number --jq '.number')"
gh run list \
  --branch pilot/java-ci-contract \
  --event pull_request \
  --limit 30 \
  --json databaseId,name,workflowName,status,conclusion,url,headSha
```

For each failed run, execute:

```sh
gh run view "$(gh run list \
  --branch pilot/java-ci-contract \
  --status failure \
  --limit 1 \
  --json databaseId \
  --jq '.[0].databaseId')" --log-failed
```

Classify the exact cause in the task report as one of:

- `consumer configuration` — fix only the pilot branch, rerun the covering
  local command, commit, push, and watch checks again;
- `template contract` — stop and propose a separate template fix;
- `runner/tool service` — retain logs and rerun only when evidence supports a
  transient failure;
- `external advisory service` — record separately from the deterministic Java
  verdict.

- [ ] **Step 6: Present evidence for human merge approval**

Report the PR URL, commit SHA, every applicable check conclusion, skipped-check
reasons, failed/fixed history, and whether a template change was required.
Stop here and request explicit human approval before making the draft ready or
merging it.

---

### Task 5: Merge with human approval and record post-merge provenance evidence

**Files:**

- Modify: template `docs/plans/roadmap.md`
- Modify: template `docs/superpowers/specs/2026-08-10-hosted-java-consumer-pilot-design.md`

**Interfaces:**

- Consumes: explicit human merge approval and a green hosted consumer PR.
- Produces: merged consumer main run, downloaded Java artifact, verified
  attestation output, and a template evidence commit.
- Preserves: consumer repository as public audit evidence.

- [ ] **Step 1: Make the consumer PR ready and merge only after approval**

After the project owner explicitly approves the merge, run:

```sh
cd /tmp/template-java-pilot-hosted-pilot
PILOT_PR_URL="$(gh pr view --json url --jq '.url')"
gh pr ready "$PILOT_PR_URL"
gh pr merge "$PILOT_PR_URL" --squash --delete-branch
gh pr view "$PILOT_PR_URL" --json state,mergedAt,mergeCommit,url
```

Expected: PR state `MERGED` with a non-empty merge commit.

- [ ] **Step 2: Watch the post-merge `ci` run**

Run:

```sh
MERGE_SHA="$(gh pr view "$PILOT_PR_URL" --json mergeCommit --jq '.mergeCommit.oid')"
CI_RUN_ID=''
attempt=0
while [ -z "$CI_RUN_ID" ] && [ "$attempt" -lt 24 ]; do
  CI_RUN_ID="$(gh run list \
    --workflow ci \
    --commit "$MERGE_SHA" \
    --event push \
    --limit 1 \
    --json databaseId \
    --jq '.[0].databaseId')"
  [ -n "$CI_RUN_ID" ] || sleep 5
  attempt=$((attempt + 1))
done
test -n "$CI_RUN_ID"
gh run watch "$CI_RUN_ID" --exit-status
gh run view "$CI_RUN_ID" --json databaseId,url,status,conclusion,headSha,jobs
```

Expected: conclusion `success`; Java quality/test/build run and attestation
executes rather than skips.

- [ ] **Step 3: Download and verify the Java artifact and attestation**

Run:

```sh
ARTIFACT_DIR="$(mktemp -d /tmp/template-java-artifact.XXXXXX)"
gh run download "$CI_RUN_ID" --name build-java --dir "$ARTIFACT_DIR"
ARTIFACT_ARCHIVE="$(find "$ARTIFACT_DIR" -type f -name 'template-ai-native-build-java.tar.gz' -print -quit)"
test -n "$ARTIFACT_ARCHIVE"
tar -tzf "$ARTIFACT_ARCHIVE" | grep -E 'target/template-java-pilot-0\.1\.0-SNAPSHOT\.jar$'
shasum -a 256 "$ARTIFACT_ARCHIVE"
gh attestation verify "$ARTIFACT_ARCHIVE" \
  --repo setiyadinamikaintegrasi/template-java-pilot
```

Expected: the archive contains the JAR, has a recorded SHA-256 digest, and
GitHub verifies its provenance attestation for the consumer repository.

- [ ] **Step 4: Generate a factual evidence block from observed values**

Run:

```sh
PR_NUMBER="$(gh pr view "$PILOT_PR_URL" --json number --jq '.number')"
PR_URL="$(gh pr view "$PILOT_PR_URL" --json url --jq '.url')"
CI_RUN_URL="$(gh run view "$CI_RUN_ID" --json url --jq '.url')"
ARCHIVE_SHA256="$(shasum -a 256 "$ARTIFACT_ARCHIVE" | awk '{print $1}')"
cat > /tmp/template-java-pilot-evidence.md <<EOF
### Hosted single-stack Java pilot — verified 2026-08-10

- Consumer: [setiyadinamikaintegrasi/template-java-pilot](https://github.com/setiyadinamikaintegrasi/template-java-pilot).
- Pull request: [#${PR_NUMBER}](${PR_URL}).
- Merge commit: \`${MERGE_SHA}\`.
- Main CI: [run ${CI_RUN_ID}](${CI_RUN_URL}) completed successfully.
- The hosted run executed Java quality, integration/E2E/coverage, build, security, and provenance jobs.
- Artifact \`build-java\` contained \`target/template-java-pilot-0.1.0-SNAPSHOT.jar\`.
- Downloaded archive SHA-256: \`${ARCHIVE_SHA256}\`.
- \`gh attestation verify\` verified the archive against \`setiyadinamikaintegrasi/template-java-pilot\`.
- The pilot used Java 21, Maven, deterministic synthetic logic, and no secret, external service, framework, deployment, or profile activation.
EOF
cat /tmp/template-java-pilot-evidence.md
```

Expected: every value is populated from observed GitHub state; no example ID or
invented conclusion remains.

- [ ] **Step 5: Record evidence in the template roadmap and design status**

Return to `/Users/jokosetiyadi/Project/template-ai-native`. Use `apply_patch`
to append the exact generated evidence block from
`/tmp/template-java-pilot-evidence.md` under the roadmap's prioritized work.
Add actual failure/noise/runtime observations only when supported by the PR or
run output.

Use `apply_patch` to change the design status from:

```markdown
**Status:** Approved 2026-08-10
```

to:

```markdown
**Status:** Verified 2026-08-10
```

- [ ] **Step 6: Verify and commit the template evidence**

Run from the template repository:

```sh
make docs-check
make ci
git diff --check
git diff -- docs/plans/roadmap.md \
  docs/superpowers/specs/2026-08-10-hosted-java-consumer-pilot-design.md
git add docs/plans/roadmap.md \
  docs/superpowers/specs/2026-08-10-hosted-java-consumer-pilot-design.md
git commit -m "docs: record hosted Java pilot evidence"
git status --short --branch
```

Expected: template docs checks and local CI pass, evidence contains only actual
hosted values, and the branch is clean.

---

## Final verification

Before declaring the pilot complete:

1. Review the complete consumer diff and three consumer commits.
2. Confirm the hosted PR check inventory contains no skipped Java contract job.
3. Confirm the post-merge CI run matches the consumer merge SHA.
4. Confirm `build-java` contains the expected JAR.
5. Confirm `gh attestation verify` succeeds for the downloaded archive.
6. Review the complete template documentation diff.
7. Report unavailable tools, advisory failures, and hosted limitations without
   translating them into success.

## Dependency verification references

The pinned versions in this plan were verified as published Maven Central
artifacts before the plan was written:

- [JUnit Jupiter](https://repo.maven.apache.org/maven2/org/junit/jupiter/junit-jupiter/)
- [Spotless Maven Plugin](https://repo.maven.apache.org/maven2/com/diffplug/spotless/spotless-maven-plugin/)
- [Maven Checkstyle Plugin 3.6.0](https://repo.maven.apache.org/maven2/org/apache/maven/plugins/maven-checkstyle-plugin/3.6.0/)
- [Checkstyle](https://repo.maven.apache.org/maven2/com/puppycrawl/tools/checkstyle/)
- [Maven Compiler Plugin 3.13.0](https://repo.maven.apache.org/maven2/org/apache/maven/plugins/maven-compiler-plugin/3.13.0/)
- [Maven Surefire Plugin 3.5.2](https://repo.maven.apache.org/maven2/org/apache/maven/plugins/maven-surefire-plugin/3.5.2/)
- [JaCoCo Maven Plugin 0.8.12](https://repo.maven.apache.org/maven2/org/jacoco/jacoco-maven-plugin/0.8.12/)
