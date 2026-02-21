# Java Tooling

> **Principle:** The Java ecosystem is mature and opinionated -- use that to your advantage. Pin your JDK version, wrap your build tool, enforce style automatically, measure coverage, and eliminate classes of bugs with static analysis. A project that requires a README paragraph on "how to set up your local environment" has failed at tooling. Clone, run the wrapper, build. That's it.

---

## Rules

### 1. Maven or Gradle for Build Management -- Gradle with Kotlin DSL Preferred for New Projects

Every Java project uses Maven or Gradle. There is no third option worth considering. For new projects, prefer **Gradle with Kotlin DSL** (`build.gradle.kts`). Kotlin DSL provides compile-time checking of the build script, IDE autocompletion, and eliminates the stringly-typed Groovy problems. Maven is acceptable for teams already invested in it, for projects that benefit from Maven's stricter convention-over-configuration model, or for organizations where the Maven ecosystem (parent POMs, enforcer plugin, release plugin) is deeply integrated.

```kotlin
// DO: Gradle Kotlin DSL -- typed, autocomplete, compile-checked
// build.gradle.kts
plugins {
    java
    id("org.springframework.boot") version "3.2.4"
    id("io.spring.dependency-management") version "1.1.4"
}

java {
    toolchain {
        languageVersion = JavaLanguageVersion.of(21)
    }
}

dependencies {
    implementation("org.springframework.boot:spring-boot-starter-web")
    testImplementation("org.springframework.boot:spring-boot-starter-test")
    testImplementation("org.testcontainers:postgresql:1.19.7")
}

tasks.test {
    useJUnitPlatform()
}
```

```xml
<!-- ACCEPTABLE: Maven for teams already invested in the Maven ecosystem -->
<!-- pom.xml -->
<project>
    <modelVersion>4.0.0</modelVersion>
    <groupId>com.example</groupId>
    <artifactId>my-service</artifactId>
    <version>1.0.0-SNAPSHOT</version>

    <properties>
        <java.version>21</java.version>
        <maven.compiler.release>21</maven.compiler.release>
    </properties>

    <dependencies>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-web</artifactId>
        </dependency>
    </dependencies>
</project>
```

### 2. Use the Wrapper -- Don't Require Global Installs

Every project must include the Maven wrapper (`mvnw` / `mvnw.cmd`) or Gradle wrapper (`gradlew` / `gradlew.cmd`). The wrapper pins the build tool version in version control, guarantees every developer and CI server uses the same version, and eliminates "it works on my machine" problems. Never instruct someone to install Maven or Gradle globally.

```bash
# DO: Run via wrapper -- works for everyone, pinned version
./gradlew build
./mvnw clean verify

# DON'T: Require a global install -- version mismatch, setup friction
gradle build    # which version? who knows
mvn clean verify  # requires manual install, version not pinned
```

Commit the wrapper files to version control: `gradlew`, `gradlew.bat`, `gradle/wrapper/gradle-wrapper.jar`, `gradle/wrapper/gradle-wrapper.properties` (or the Maven equivalents). The `.jar` file is small and must be committed -- without it, the wrapper doesn't work.

### 3. SpotBugs or Error Prone for Static Analysis

Static analysis catches bugs that tests miss: null dereference paths, resource leaks, incorrect synchronization, format string mismatches, and common API misuses. **Error Prone** (Google) runs as a compiler plugin and catches bugs at compile time with zero false-positive tolerance. **SpotBugs** (successor to FindBugs) runs as a post-compilation analysis tool with a broader set of detectors. Use at least one. Error Prone is preferred for new projects because it integrates into the compilation step and blocks bugs before they reach the test phase.

```kotlin
// Gradle: Error Prone integration
plugins {
    id("net.ltgt.errorprone") version "3.1.0"
}

dependencies {
    errorprone("com.google.errorprone:error_prone_core:2.27.1")
}

tasks.withType<JavaCompile>().configureEach {
    options.errorprone {
        disableWarningsInGeneratedCode = true
        error("NullAway") // treat NullAway findings as errors
    }
}
```

```xml
<!-- Maven: SpotBugs integration -->
<plugin>
    <groupId>com.github.spotbugs</groupId>
    <artifactId>spotbugs-maven-plugin</artifactId>
    <version>4.8.4.0</version>
    <executions>
        <execution>
            <goals><goal>check</goal></goals>
        </execution>
    </executions>
</plugin>
```

### 4. Checkstyle or google-java-format for Style Enforcement

Style discussions are a waste of engineering time. Pick a formatter, enforce it in CI, and never argue about braces again. **google-java-format** is zero-configuration: it formats code to Google's Java style, period. No options, no debates. **Checkstyle** is configurable and appropriate when the team has an established style that differs from Google's. Whichever you choose, it must run in CI and block merges on violations.

```kotlin
// Gradle: google-java-format via Spotless
plugins {
    id("com.diffplug.spotless") version "6.25.0"
}

spotless {
    java {
        googleJavaFormat("1.22.0")
        removeUnusedImports()
        trimTrailingWhitespace()
        endWithNewline()
    }
}
```

```kotlin
// Gradle: Checkstyle (when Google style isn't the team convention)
plugins {
    checkstyle
}

checkstyle {
    toolVersion = "10.15.0"
    configFile = file("config/checkstyle/checkstyle.xml")
    maxWarnings = 0  // warnings are errors -- no broken windows
}
```

Configure your IDE to use the same formatter. For IntelliJ, install the google-java-format plugin or import the Checkstyle config. Format-on-save should be the default. A developer should never need to think about formatting.

### 5. JaCoCo for Code Coverage

JaCoCo is the standard code coverage tool for Java. Integrate it into the build, set a minimum coverage threshold, and fail the build if coverage drops below it. Coverage is not a goal in itself -- 100% coverage with meaningless assertions is worse than 70% coverage with real tests. Use JaCoCo to find untested code paths, not to gamify a number.

```kotlin
// Gradle: JaCoCo with coverage threshold
plugins {
    jacoco
}

tasks.jacocoTestReport {
    dependsOn(tasks.test)
    reports {
        xml.required = true  // for CI integration (SonarQube, Codecov)
        html.required = true // for local review
    }
}

tasks.jacocoTestCoverageVerification {
    violationRules {
        rule {
            limit {
                minimum = BigDecimal("0.80") // 80% line coverage minimum
            }
        }
        rule {
            element = "CLASS"
            excludes = listOf(
                "*.config.*",      // Spring config classes
                "*.Application"    // main class
            )
            limit {
                minimum = BigDecimal("0.70")
            }
        }
    }
}

tasks.check {
    dependsOn(tasks.jacocoTestCoverageVerification)
}
```

### 6. Use `dependencyManagement` / BOM for Version Alignment

When multiple libraries share a version lineage (Spring Boot, Jackson, Netty, testing libraries), managing individual versions is a recipe for incompatibility. A BOM (Bill of Materials) declares compatible versions in one place. Import the BOM in `dependencyManagement` (Maven) or the `platform()` directive (Gradle), then declare dependencies without version numbers.

```kotlin
// Gradle: BOM for version alignment
dependencies {
    implementation(platform("org.springframework.boot:spring-boot-dependencies:3.2.4"))
    implementation(platform("org.testcontainers:testcontainers-bom:1.19.7"))
    implementation(platform("software.amazon.awssdk:bom:2.25.16"))

    // No version numbers needed -- the BOM manages them
    implementation("org.springframework.boot:spring-boot-starter-web")
    implementation("software.amazon.awssdk:s3")
    testImplementation("org.testcontainers:postgresql")
}
```

```xml
<!-- Maven: BOM import in dependencyManagement -->
<dependencyManagement>
    <dependencies>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-dependencies</artifactId>
            <version>3.2.4</version>
            <type>pom</type>
            <scope>import</scope>
        </dependency>
        <dependency>
            <groupId>org.testcontainers</groupId>
            <artifactId>testcontainers-bom</artifactId>
            <version>1.19.7</version>
            <type>pom</type>
            <scope>import</scope>
        </dependency>
    </dependencies>
</dependencyManagement>
```

### 7. Use `jlink` / `jpackage` for Custom Runtime Images (Java 14+)

`jlink` creates a minimal JRE containing only the modules your application uses. The result is a self-contained runtime image that's 30-60% smaller than a full JDK. `jpackage` (Java 14+) goes further, producing platform-specific installers (`.deb`, `.rpm`, `.msi`, `.dmg`). Use `jlink` for Docker images (smaller base, faster startup) and `jpackage` for distributing desktop or CLI applications.

```bash
# Create a minimal runtime image with jlink
jlink \
    --module-path $JAVA_HOME/jmods:target/modules \
    --add-modules com.example.myapp \
    --output target/runtime \
    --strip-debug \
    --compress zip-9 \
    --no-header-files \
    --no-man-pages

# Result: target/runtime/ is a self-contained JRE (~40MB vs ~300MB full JDK)
```

```dockerfile
# DO: Multi-stage Docker build with jlink
FROM eclipse-temurin:21-jdk-alpine AS build
WORKDIR /app
COPY . .
RUN ./gradlew build -x test
RUN jlink \
    --add-modules java.base,java.logging,java.sql,java.net.http \
    --output /app/runtime \
    --strip-debug --compress zip-9 --no-header-files --no-man-pages

FROM alpine:3.19
COPY --from=build /app/runtime /opt/java
COPY --from=build /app/build/libs/app.jar /opt/app/app.jar
ENTRYPOINT ["/opt/java/bin/java", "-jar", "/opt/app/app.jar"]

# DON'T: Ship the full JDK in the container
FROM eclipse-temurin:21-jdk  # 300MB+ base image for a 10MB app
COPY target/app.jar /app.jar
ENTRYPOINT ["java", "-jar", "/app.jar"]
```

### 8. Use GraalVM Native Image for CLI Tools and Serverless

When startup time matters -- CLI tools, serverless functions (Lambda/Cloud Functions), short-lived batch jobs -- GraalVM native-image compiles Java to a standalone binary with millisecond startup and no JVM overhead. The tradeoff is longer build times, no runtime reflection without configuration, and reduced peak throughput compared to JIT-compiled JVM. Use native-image for cold-start-sensitive workloads; use the JVM for long-running services where JIT compilation pays off.

```kotlin
// Gradle: GraalVM native image with Spring Boot
plugins {
    id("org.graalvm.buildtools.native") version "0.10.1"
}

graalvmNative {
    binaries {
        named("main") {
            imageName = "my-cli"
            mainClass = "com.example.cli.Main"
            buildArgs.add("--enable-url-protocols=https")
            buildArgs.add("-H:+ReportExceptionStackTraces")
        }
    }
}

// Build with: ./gradlew nativeCompile
// Result: build/native/nativeCompile/my-cli (single binary, ~50ms startup)
```

### 9. Pin Java Version

The JDK version must be pinned in the project, not left to whatever each developer has installed. There are three mechanisms, and you should use at least one:

- **`.java-version` file** (for version managers like `jenv`, `sdkman`, `asdf`): a single line with the version number. Checked into version control.
- **Gradle toolchains**: declares the required Java version in the build script. Gradle auto-downloads the correct JDK if it's not already available.
- **Maven `maven.compiler.release`**: enforces source and target compatibility in the POM.

```kotlin
// Gradle: Toolchain -- Gradle downloads the correct JDK automatically
java {
    toolchain {
        languageVersion = JavaLanguageVersion.of(21)
        vendor = JvmVendorSpec.ADOPTIUM  // optional: pin vendor too
    }
}
```

```bash
# .java-version file -- used by sdkman, jenv, asdf, mise
21.0.2
```

```xml
<!-- Maven: compiler release property -->
<properties>
    <maven.compiler.release>21</maven.compiler.release>
</properties>
```

Never assume the JDK version. CI and local development must use the same version. If the project uses Java 21 features and a developer has Java 17 installed, the build should fail immediately with a clear error -- not silently compile a subset of the code.

### 10. Use Lombok Sparingly -- Prefer Records; Lombok Only for Legacy Code or Builder Patterns

Lombok generates boilerplate at compile time via annotation processing: `@Data`, `@Builder`, `@Slf4j`, `@RequiredArgsConstructor`. It was essential when Java had no records, no text blocks, and no pattern matching. Today, records replace `@Value` and `@Data` for value types. What remains useful:

- **`@Builder`** for classes with many optional parameters (records don't have builders natively)
- **`@Slf4j`** for logger declarations (saves one line, but it's a hard habit to break)
- **Legacy code** where converting to records would require a large refactor

For new code, start without Lombok. Add it only when a specific Lombok feature provides clear value that modern Java cannot.

```java
// DO: Record instead of Lombok @Value
public record UserDto(String name, String email, Instant createdAt) {}

// ACCEPTABLE: Lombok @Builder for complex construction
@Builder
public class SearchQuery {
    private final String term;
    private final int page;
    private final int pageSize;
    @Builder.Default private final SortOrder sort = SortOrder.RELEVANCE;
    @Builder.Default private final Set<Filter> filters = Set.of();
}

// Usage: fluent builder for many optional params
SearchQuery query = SearchQuery.builder()
    .term("java idioms")
    .page(1)
    .pageSize(20)
    .sort(SortOrder.DATE)
    .build();

// DON'T: Lombok @Data on a new class that should be a record
@Data                    // generates mutable getters/setters, equals, hashCode, toString
@AllArgsConstructor      // when a record does all of this in one line
public class UserDto {
    private String name;
    private String email;
    private Instant createdAt;
}
```

---

## Examples

### Complete Build Configuration (Gradle Kotlin DSL)

```kotlin
// build.gradle.kts -- a well-configured Java project
plugins {
    java
    jacoco
    checkstyle
    id("org.springframework.boot") version "3.2.4"
    id("io.spring.dependency-management") version "1.1.4"
    id("com.diffplug.spotless") version "6.25.0"
    id("net.ltgt.errorprone") version "3.1.0"
}

group = "com.example"
version = "1.0.0-SNAPSHOT"

java {
    toolchain {
        languageVersion = JavaLanguageVersion.of(21)
    }
}

repositories {
    mavenCentral()
}

dependencies {
    implementation(platform("org.testcontainers:testcontainers-bom:1.19.7"))

    implementation("org.springframework.boot:spring-boot-starter-web")
    implementation("org.springframework.boot:spring-boot-starter-data-jpa")

    testImplementation("org.springframework.boot:spring-boot-starter-test")
    testImplementation("org.assertj:assertj-core:3.25.3")
    testImplementation("org.testcontainers:postgresql")
    testImplementation("com.tngtech.archunit:archunit-junit5:1.2.1")

    errorprone("com.google.errorprone:error_prone_core:2.27.1")
}

spotless {
    java {
        googleJavaFormat("1.22.0")
        removeUnusedImports()
    }
}

tasks.test {
    useJUnitPlatform()
    finalizedBy(tasks.jacocoTestReport)
}

tasks.jacocoTestCoverageVerification {
    violationRules {
        rule {
            limit {
                minimum = BigDecimal("0.80")
            }
        }
    }
}

tasks.check {
    dependsOn(tasks.jacocoTestCoverageVerification)
}
```

### CI Pipeline Verification (in order)

```bash
# 1. Format check -- fast, catches unformatted code
./gradlew spotlessCheck

# 2. Compile with Error Prone -- catches bugs at compile time
./gradlew compileJava

# 3. Unit tests with coverage
./gradlew test jacocoTestReport

# 4. Coverage verification -- fails if below threshold
./gradlew jacocoTestCoverageVerification

# 5. Integration tests (Testcontainers -- requires Docker)
./gradlew integrationTest

# 6. Full build artifact
./gradlew build
```

---

## Anti-Patterns

| Anti-Pattern | Why It's Harmful | What to Do Instead |
|---|---|---|
| No build wrapper (`gradle` or `mvn` without wrapper) | Version mismatch between machines; requires manual install | Commit `gradlew`/`mvnw` and wrapper JARs to version control |
| Groovy DSL for new Gradle projects (`build.gradle`) | No type checking, no IDE autocompletion, stringly-typed | Use Kotlin DSL (`build.gradle.kts`) for new projects |
| No static analysis in CI | Null dereferences, resource leaks, and API misuses ship to production | Add Error Prone (compile-time) or SpotBugs (post-compile) |
| No style enforcement | Formatting debates in code review; inconsistent codebase | Enforce google-java-format or Checkstyle in CI -- block merges on violations |
| No coverage threshold | Coverage silently degrades as untested code accumulates | Set JaCoCo minimum (e.g., 80%) and fail the build below it |
| Hardcoded dependency versions without BOM | Incompatible library versions cause runtime `NoSuchMethodError` | Use BOMs (`platform()` in Gradle, `dependencyManagement` in Maven) |
| Full JDK in Docker images | 300MB+ image for a small application; slow deploys | Use `jlink` to create a minimal runtime; multi-stage Docker build |
| Unpinned Java version | "Works on my machine" with Java 21 features; CI runs Java 17 | Pin with `.java-version`, Gradle toolchains, or Maven `compiler.release` |
| Lombok `@Data` on new classes | Generates mutable setters; records do the same thing immutably in one line | Use records for value types; Lombok only for builders on legacy code |
| Manual formatting in code review | Wastes reviewer time; inconsistent results | Automate with Spotless or Checkstyle; format-on-save in IDE |
| Running `gradle build` or `mvn install` as the only CI step | Misses static analysis, coverage enforcement, and format checks | Separate steps: format check, compile, test, coverage, analysis, build |
| Global JDK install instructions in README | Friction for new developers; version drift | Use Gradle toolchains (auto-downloads JDK) or `sdkman`/`mise` with `.java-version` |
