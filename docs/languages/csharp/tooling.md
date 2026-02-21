# C# Tooling

**Principle:** The `dotnet` CLI and MSBuild are the foundation. Centralize project settings, pin SDK versions, enforce code style at build time, and use Roslyn analyzers to catch bugs before they reach review.

---

## Rules

### 1. .NET SDK and `dotnet` CLI

The `dotnet` CLI is the single entry point for building, testing, running, and publishing .NET applications. All CI/CD should use `dotnet` commands — not Visual Studio-specific workflows.

```bash
dotnet build       # Compile
dotnet test        # Run tests
dotnet run         # Run the application
dotnet publish     # Produce deployment artifacts
dotnet format      # Format code
```

### 2. Pin the SDK Version with `global.json`

Commit a `global.json` to ensure all developers and CI use the same SDK version. Prevents "works on my machine" from SDK version drift.

```json
{
  "sdk": {
    "version": "8.0.400",
    "rollForward": "latestPatch"
  }
}
```

### 3. `Directory.Build.props` for Shared Settings

Centralize project settings that apply to every project in the solution. Avoids duplicating `<Nullable>`, `<ImplicitUsings>`, analyzer settings, etc. across dozens of `.csproj` files.

```xml
<!-- Directory.Build.props at solution root -->
<Project>
  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
    <TreatWarningsAsErrors>true</TreatWarningsAsErrors>
    <EnforceCodeStyleInBuild>true</EnforceCodeStyleInBuild>
    <AnalysisLevel>latest-recommended</AnalysisLevel>
  </PropertyGroup>
</Project>
```

### 4. Central Package Management

Use `Directory.Packages.props` to manage NuGet package versions in one place across all projects.

```xml
<!-- Directory.Packages.props at solution root -->
<Project>
  <PropertyGroup>
    <ManagePackageVersionsCentrally>true</ManagePackageVersionsCentrally>
  </PropertyGroup>
  <ItemGroup>
    <PackageVersion Include="Microsoft.Extensions.Logging" Version="8.0.0" />
    <PackageVersion Include="Npgsql.EntityFrameworkCore.PostgreSQL" Version="8.0.4" />
    <PackageVersion Include="xunit" Version="2.9.0" />
    <PackageVersion Include="FluentAssertions" Version="7.0.0" />
  </ItemGroup>
</Project>
```

Then in `.csproj` files, reference packages without version:
```xml
<PackageReference Include="FluentAssertions" />
```

### 5. `dotnet format` with EditorConfig

Use `dotnet format` for code formatting, driven by `.editorconfig`. Enforce in CI.

```ini
# .editorconfig
root = true

[*.cs]
indent_style = space
indent_size = 4
dotnet_sort_system_directives_first = true
csharp_style_var_for_built_in_types = true:suggestion
csharp_style_var_when_type_is_apparent = true:suggestion
csharp_style_var_elsewhere = false:suggestion
csharp_prefer_simple_using_statement = true:warning
csharp_style_namespace_declarations = file_scoped:warning
csharp_style_prefer_primary_constructors = true:suggestion
```

```bash
# CI enforcement
dotnet format --verify-no-changes
```

### 6. Roslyn Analyzers

Enable built-in analyzers and treat code style as build errors. Use `<EnforceCodeStyleInBuild>true</EnforceCodeStyleInBuild>` in `Directory.Build.props`. Add third-party analyzers for deeper analysis:

```xml
<ItemGroup>
  <!-- Microsoft's recommended analyzers (included in SDK but opt-in for stricter rules) -->
  <PackageReference Include="Microsoft.CodeAnalysis.NetAnalyzers" Version="8.0.0" />
  <!-- Security-focused analysis -->
  <PackageReference Include="SecurityCodeScan.VS2019" Version="5.6.7" />
  <!-- Async best practices -->
  <PackageReference Include="Microsoft.VisualStudio.Threading.Analyzers" Version="17.10.48" />
</ItemGroup>
```

### 7. Secret Management

Never store secrets in `appsettings.json` or code. Use `dotnet user-secrets` for local development.

```bash
# Initialize secrets for a project
dotnet user-secrets init

# Set a secret
dotnet user-secrets set "Database:ConnectionString" "Host=localhost;..."

# Access in code via standard configuration
var connectionString = configuration["Database:ConnectionString"];
```

For production: use Azure Key Vault, AWS Secrets Manager, or environment variables.

### 8. Minimal APIs over Controllers

For new ASP.NET Core projects (7+), prefer minimal APIs. They're lighter, faster to write, and more testable.

```csharp
// DO: Minimal API
app.MapGet("/users/{id}", async (int id, IUserService service) =>
{
    var user = await service.GetByIdAsync(id);
    return user is not null ? Results.Ok(user) : Results.NotFound();
});

// Controllers are fine for complex scenarios with filters, model binding, etc.
// But don't default to them for simple CRUD.
```

### 9. Source Generators over Reflection

Where possible, use compile-time source generators instead of runtime reflection. They're faster, AOT-friendly, and catch errors at compile time.

```csharp
// DO: Source-generated JSON serialization
[JsonSerializable(typeof(User))]
[JsonSerializable(typeof(List<User>))]
internal partial class AppJsonContext : JsonSerializerContext { }

// Use it
var json = JsonSerializer.Serialize(user, AppJsonContext.Default.User);

// DON'T: Runtime reflection-based serialization in hot paths
var json = JsonSerializer.Serialize(user); // Uses reflection, slow, not AOT-safe
```

### 10. BenchmarkDotNet for Performance

Use BenchmarkDotNet for reliable micro-benchmarks. It handles warmup, statistical analysis, and GC measurement.

```csharp
[MemoryDiagnoser]
public class ParsingBenchmarks
{
    [Benchmark(Baseline = true)]
    public int ParseWithSubstring() => int.Parse(Input.Substring(0, 4));

    [Benchmark]
    public int ParseWithSpan() => int.Parse(Input.AsSpan(0, 4));
}
```

```bash
dotnet run -c Release -- --filter '*Parsing*'
```

### 11. Vulnerability Auditing

Audit NuGet packages for known vulnerabilities:

```bash
dotnet list package --vulnerable --include-transitive
```

Run in CI. Fail the build on known vulnerabilities.

---

## Anti-Patterns

| Don't | Do Instead |
|---|---|
| Duplicate settings across `.csproj` files | `Directory.Build.props` for shared settings |
| Float NuGet versions across projects | Central Package Management (`Directory.Packages.props`) |
| Skip nullable reference types | `<Nullable>enable</Nullable>` with warnings-as-errors |
| Store secrets in `appsettings.json` | `dotnet user-secrets` for local dev, vault for production |
| Ignore `dotnet format` in CI | `dotnet format --verify-no-changes` in the pipeline |
| Runtime reflection for serialization | Source generators (`JsonSerializerContext`) |
| No SDK version pinning | `global.json` with specific SDK version |
| Controllers for every endpoint | Minimal APIs for simple routes |
| Manual benchmarks with `Stopwatch` | BenchmarkDotNet with proper statistical analysis |
| Ignore vulnerable dependencies | `dotnet list package --vulnerable` in CI |
