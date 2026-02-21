# TypeScript Tooling

**Principle:** Tooling decisions should be made once, enforced automatically, and never debated in code review. The right tools eliminate entire categories of bugs and bike-shedding — pick them, configure them strictly, and move on.

---

## Rules

### 1. tsconfig.json — Strict by Default

The compiler is your most reliable reviewer. Give it maximum authority. Start from this baseline and add project-specific settings as needed.

```jsonc
{
  "compilerOptions": {
    // Safety — non-negotiable
    "strict": true,                          // Enables all strict type-checking options
    "noUncheckedIndexedAccess": true,        // array[0] is T | undefined, not T
    "exactOptionalPropertyTypes": true,      // { x?: string } means string | undefined, not string | undefined | missing
    "noFallthroughCasesInSwitch": true,      // Prevents missing break in switch
    "noImplicitReturns": true,               // Every code path must return a value
    "noImplicitOverride": true,              // override keyword required in subclasses
    "forceConsistentCasingInFileNames": true, // Prevents case-sensitivity bugs on macOS/Windows

    // Module resolution
    "module": "ESNext",                      // Or "NodeNext" for Node.js projects
    "moduleResolution": "bundler",           // Or "nodenext" for Node.js projects
    "resolveJsonModule": true,
    "isolatedModules": true,                 // Required for Vite, esbuild, swc
    "verbatimModuleSyntax": true,            // Forces explicit type-only imports

    // Output
    "target": "ES2022",                      // Modern baseline — adjust per deployment target
    "lib": ["ES2022"],                       // Add "DOM" for browser projects
    "declaration": true,                     // Generate .d.ts for libraries
    "declarationMap": true,                  // Source maps for declarations
    "sourceMap": true,                       // Source maps for debugging

    // Paths
    "baseUrl": ".",
    "outDir": "dist",
    "rootDir": "src"
  },
  "include": ["src"],
  "exclude": ["node_modules", "dist"]
}
```

Key settings to understand:

- **`noUncheckedIndexedAccess`**: Without this, `Record<string, User>` pretends every key exists. With it, `users["abc"]` is `User | undefined`, which forces you to handle the missing case. This catches real bugs.
- **`exactOptionalPropertyTypes`**: Without this, `{ name?: string }` allows `{ name: undefined }` — which is semantically different from omitting the key. This flag enforces the distinction.
- **`verbatimModuleSyntax`**: Forces `import type { Foo }` instead of `import { Foo }` for type-only imports. This makes the intent explicit and prevents runtime import of types that don't exist in JavaScript.

### 2. ESLint with @typescript-eslint

ESLint catches patterns the compiler doesn't — logic errors, stylistic inconsistencies, and dangerous patterns. Use `@typescript-eslint` for type-aware rules.

```bash
# Install
pnpm add -D eslint @typescript-eslint/parser @typescript-eslint/eslint-plugin eslint-config-prettier
```

Key rules to enable (these catch real bugs):

```jsonc
// eslint.config.js (flat config) — key rules
{
  "rules": {
    // Prevent accidental floating promises (forgetting await)
    "@typescript-eslint/no-floating-promises": "error",

    // Prevent unsafe any usage spreading through the codebase
    "@typescript-eslint/no-unsafe-assignment": "error",
    "@typescript-eslint/no-unsafe-call": "error",
    "@typescript-eslint/no-unsafe-member-access": "error",
    "@typescript-eslint/no-unsafe-return": "error",

    // Prevent misuse of promises (forgetting await in conditionals)
    "@typescript-eslint/no-misused-promises": "error",

    // Require explicit return types on exported functions (library boundary documentation)
    "@typescript-eslint/explicit-module-boundary-types": "warn",

    // Prevent unused variables (auto-fixable with underscore prefix convention)
    "@typescript-eslint/no-unused-vars": ["error", {
      "argsIgnorePattern": "^_",
      "varsIgnorePattern": "^_"
    }],

    // Ban specific types — no Object, {}, Function
    "@typescript-eslint/ban-types": "error",

    // Enforce consistent type imports
    "@typescript-eslint/consistent-type-imports": ["error", {
      "prefer": "type-imports",
      "fixStyle": "separate-type-imports"
    }],

    // Require switch exhaustiveness checking
    "@typescript-eslint/switch-exhaustiveness-check": "error",

    // Prevent non-null assertions
    "@typescript-eslint/no-non-null-assertion": "error"
  }
}
```

The `no-floating-promises` rule alone justifies the ESLint setup — forgetting `await` on a promise is one of the most common and hardest-to-debug TypeScript mistakes.

### 3. Prettier for Formatting — No Debates

Formatting is not a design decision. Use Prettier. Configure it once. Never discuss tabs vs. spaces, semicolons, or trailing commas in a review again.

```jsonc
// .prettierrc
{
  "semi": true,
  "singleQuote": false,
  "trailingComma": "all",
  "printWidth": 100,
  "tabWidth": 2,
  "arrowParens": "always",
  "endOfLine": "lf"
}
```

Enforce Prettier via:
- **Editor:** Format-on-save (every team member)
- **Pre-commit hook:** `lint-staged` + `husky` to catch anything the editor missed
- **CI:** `prettier --check .` to block PRs with unformatted code

```jsonc
// package.json
{
  "lint-staged": {
    "*.{ts,tsx,js,jsx,json,css,md}": ["prettier --write"]
  }
}
```

Prettier and ESLint overlap on formatting rules. Use `eslint-config-prettier` to disable ESLint's formatting rules and let Prettier handle all formatting. ESLint should only enforce logic and correctness rules.

### 4. Bundler Choice

Different project types have different bundling needs. Don't use a library bundler for an app or vice versa.

| Project Type | Recommended Bundler | Why |
|---|---|---|
| **Web application** | Vite | Fast HMR, ESM-native, minimal config, huge ecosystem |
| **Library (npm package)** | tsup | Zero-config for most cases, supports CJS + ESM dual output |
| **Monorepo library** | unbuild | Passive bundling, stub mode for development, works well with monorepos |
| **Node.js server** | None (use `tsx` for dev, `tsc` for prod) | Servers don't need bundling — just compile and run |
| **CLI tool** | tsup with `--target node18` | Single-file output, shebang support, tree-shaking |

```bash
# Library with tsup — generates CJS + ESM + types
# tsup.config.ts
import { defineConfig } from "tsup";

export default defineConfig({
  entry: ["src/index.ts"],
  format: ["cjs", "esm"],
  dts: true,
  splitting: false,
  clean: true,
});
```

Avoid Webpack for new projects unless you have a specific, non-negotiable requirement (legacy plugin, specific loader). The configuration complexity is not worth it when Vite handles 95% of use cases.

### 5. Package Manager — pnpm Preferred for Monorepos

| Context | Recommendation | Why |
|---|---|---|
| **Monorepo** | pnpm | Strict dependency isolation, workspace protocol, disk-efficient |
| **Single-package project** | pnpm or npm | pnpm is faster; npm has zero install friction |
| **Team with mixed experience** | npm | Lowest learning curve, ships with Node.js |

pnpm's strict mode prevents phantom dependencies — packages that work because a sibling package installed them, but break when deployed alone. This catches real bugs that npm and Yarn miss.

```bash
# pnpm workspace setup
# pnpm-workspace.yaml
packages:
  - "packages/*"
  - "apps/*"

# Install a dependency in a specific workspace package
pnpm add zod --filter @myorg/api

# Run a script across all workspace packages
pnpm -r run build
```

Lock files (`pnpm-lock.yaml`, `package-lock.json`, `yarn.lock`) must always be committed. Never add lock files to `.gitignore`.

### 6. Path Aliases via tsconfig Paths

Avoid deep relative imports (`../../../utils/format`). Use tsconfig path aliases for clean, refactorable imports.

```jsonc
// tsconfig.json
{
  "compilerOptions": {
    "baseUrl": ".",
    "paths": {
      "@/*": ["src/*"],
      "@/test/*": ["test/*"]
    }
  }
}
```

```typescript
// Do: Clean aliased imports
import { formatDate } from "@/utils/format";
import { buildUser } from "@/test/factories";

// Don't: Fragile relative path chains
import { formatDate } from "../../../utils/format";
import { buildUser } from "../../../../test/factories";
```

Path aliases must be configured in **both** tsconfig.json (for the compiler) **and** the bundler/runner:

| Tool | Configuration |
|---|---|
| **Vite** | `resolve.alias` in `vite.config.ts` or `vite-tsconfig-paths` plugin |
| **tsup** | Resolves from tsconfig automatically |
| **Vitest** | Inherits from Vite config, or use `vite-tsconfig-paths` |
| **Jest** | `moduleNameMapper` in `jest.config.ts` |
| **tsx / ts-node** | Uses tsconfig paths natively (tsx) or via `tsconfig-paths/register` (ts-node) |
| **Node.js** | `--experimental-transform-types` (v23+) or `tsx` as loader |

Forgetting to sync path aliases between tsconfig and the bundler is a common source of "compiles but crashes at runtime" bugs. If you add a path alias, verify it works end-to-end.

### 7. Use `tsx` or `ts-node` for Scripts

TypeScript files can't run directly in Node.js (prior to v23). Use `tsx` for scripts, migrations, seeds, and one-off tasks. It's faster than `ts-node`, supports ESM natively, and requires zero configuration.

```bash
# Do: Run TypeScript files directly with tsx
npx tsx src/scripts/migrate.ts
npx tsx src/scripts/seed-database.ts

# Do: Add as package.json scripts
{
  "scripts": {
    "db:migrate": "tsx src/scripts/migrate.ts",
    "db:seed": "tsx src/scripts/seed-database.ts",
    "dev": "tsx watch src/server.ts"
  }
}

# Don't: Compile to JS first, then run
npx tsc && node dist/scripts/migrate.js  # Slow, leaves build artifacts
```

For production servers, compile with `tsc` and run the JavaScript output. `tsx` is for development and scripts, not production runtime — it adds startup overhead and skips type checking.

| Use Case | Tool | Why |
|---|---|---|
| **Development server** | `tsx watch` | Fast restart, no compile step |
| **One-off scripts** | `tsx` | Zero config, fast execution |
| **Production server** | `tsc` + `node dist/` | No runtime overhead, type-checked at build |
| **CI type checking** | `tsc --noEmit` | Verifies types without generating output |

---

## Project Setup Checklist

When starting a new TypeScript project or auditing an existing one, verify:

- [ ] `tsconfig.json` has `strict: true`, `noUncheckedIndexedAccess: true`, `exactOptionalPropertyTypes: true`
- [ ] ESLint is configured with `@typescript-eslint` and `no-floating-promises` is `"error"`
- [ ] Prettier is configured with format-on-save and a pre-commit hook
- [ ] Path aliases are configured in tsconfig **and** the bundler/test runner
- [ ] Lock file is committed (never gitignored)
- [ ] `tsx` or equivalent is available for running scripts
- [ ] CI runs `tsc --noEmit`, `eslint .`, `prettier --check .`, and the test suite

---

## Anti-Patterns

| Don't | Do Instead |
|---|---|
| `strict: false` or missing strict flag in tsconfig | `strict: true` with additional strict flags enabled |
| ESLint without `@typescript-eslint` type-aware rules | Enable `no-floating-promises`, `no-unsafe-*`, and `no-misused-promises` |
| Debate formatting in code review | Configure Prettier once and automate enforcement |
| Webpack for new projects without specific need | Vite for apps, tsup for libraries |
| `npm install` in a monorepo without strict isolation | pnpm with workspace protocol for dependency isolation |
| Deep relative imports: `../../../utils` | Path aliases: `@/utils` with tsconfig paths |
| Compile scripts to JS before running | `tsx` for development scripts, `tsc` + `node` for production only |
| Ignore lock file or add to `.gitignore` | Always commit the lock file — reproducible installs are non-negotiable |
| Skip CI type checking because "the editor catches it" | `tsc --noEmit` in CI — editors aren't authoritative |
| Configure path aliases in tsconfig but not the bundler | Sync aliases across all tools or use a plugin like `vite-tsconfig-paths` |
