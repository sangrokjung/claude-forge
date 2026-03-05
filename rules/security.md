# Security Guidelines

## Mandatory Security Checks

Before ANY commit:
- [ ] No hardcoded secrets (API keys, passwords, tokens)
- [ ] All user inputs validated
- [ ] SQL injection prevention (parameterized queries)
- [ ] XSS prevention (sanitized HTML)
- [ ] CSRF protection enabled
- [ ] Authentication/authorization verified
- [ ] Rate limiting on all endpoints
- [ ] Error messages don't leak sensitive data

## Secret Management

```typescript
// NEVER: Hardcoded secrets
const apiKey = "sk-proj-xxxxx"

// ALWAYS: Environment variables
const apiKey = process.env.OPENAI_API_KEY

if (!apiKey) {
  throw new Error('OPENAI_API_KEY not configured')
}
```

## Security Response Protocol

If security issue found:
1. STOP immediately
2. Use **security-reviewer** agent
3. Fix CRITICAL issues before continuing
4. Rotate any exposed secrets
5. Review entire codebase for similar issues

## Remote Session Security

When using Claude Code remote sessions (e.g., `claude --remote`):

- **Never share session URLs** in public channels (Slack, Discord, GitHub issues)
- **Terminate idle sessions** — close remote sessions when not actively in use
- **Use VPN** when connecting to remote sessions over untrusted networks
- **Restrict session access** — only share session URLs with authorized team members via secure channels
- **Review session logs** — periodically check for unauthorized access or unexpected commands
