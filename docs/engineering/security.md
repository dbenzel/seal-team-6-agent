# Security

**Principle:** Security is not a feature — it's a constraint on every feature. Validate at boundaries, protect secrets absolutely, and treat every external input as hostile.

---

## Rules

### 1. Validate at System Boundaries

Trust internal code. Validate external input. The boundary is where your system meets the outside world:

- HTTP request parameters, headers, and bodies
- File uploads
- Database query results from shared databases
- Environment variables and configuration files
- Third-party API responses
- User-generated content

**Inside** the boundary (your own functions calling each other), don't re-validate. Trust your types and your tests.

### 2. OWASP Top 10 Awareness

| Vulnerability | Prevention |
|---|---|
| **Injection** (SQL, command, template) | Use parameterized queries, never string concatenation. Use ORM/query builder methods. Escape shell arguments. |
| **Broken Auth** | Use established auth libraries. Hash passwords with bcrypt/argon2. Enforce session timeouts. |
| **Sensitive Data Exposure** | Encrypt at rest and in transit. Don't log sensitive data. Don't return secrets in API responses. |
| **XSS** | Escape all output in HTML contexts. Use framework auto-escaping. Set `Content-Security-Policy` headers. |
| **Broken Access Control** | Check authorization on every request. Don't rely on client-side checks. Default-deny. |
| **Security Misconfiguration** | Disable debug mode in production. Remove default credentials. Keep dependencies updated. |
| **CSRF** | Use anti-CSRF tokens. Validate `Origin`/`Referer` headers. Use `SameSite` cookies. |

### 3. Secrets Management

**Absolute rules — no exceptions:**

- Never commit secrets to version control (`.env`, API keys, tokens, passwords)
- Never hardcode secrets in source code
- Never log secrets or include them in error messages
- Never return secrets in API responses

**Do this instead:**
- Use environment variables for runtime secrets
- Use `.env` files locally with `.env` in `.gitignore`
- Use secret management services in production (Vault, AWS Secrets Manager, etc.)
- Rotate secrets on suspected compromise

### 4. Dependency Security

- Keep dependencies updated — known vulnerabilities in outdated packages are low-hanging fruit for attackers
- Audit dependencies before adding them — check download counts, maintenance status, and known vulnerabilities
- Use lock files to pin dependency versions
- Run `npm audit`, `pip audit`, `cargo audit`, or equivalent regularly
- Prefer well-maintained, widely-used packages over obscure alternatives

### 5. Principle of Least Privilege

- Request only the permissions you need
- Don't run services as root/admin
- Don't give database users `DROP TABLE` access if they only need `SELECT`
- API tokens should have minimal scopes
- File permissions should be restrictive by default

### 6. Defense in Depth

No single security measure is sufficient. Layer your defenses:

- Input validation + parameterized queries (not just one)
- Authentication + authorization + rate limiting
- Encryption in transit + encryption at rest
- Application security + infrastructure security

---

## Anti-Patterns

| Don't | Do Instead |
|---|---|
| `query("SELECT * FROM users WHERE id=" + userId)` | Use parameterized queries |
| Store passwords in plaintext | Hash with bcrypt/argon2 |
| Commit `.env` files | Add `.env` to `.gitignore` |
| Disable CORS checks "because it's easier" | Configure CORS properly for your use case |
| Trust client-side validation alone | Always validate server-side; client-side is UX, not security |
