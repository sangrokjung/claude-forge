# Testing — Detail Reference

> Source: rules/testing.md (core requirements and TDD workflow are there, details here)

## Troubleshooting Checklist

When tests fail:
1. Use **tdd-guide** agent for guidance
2. Check test isolation — are tests sharing state?
3. Verify mocks are correct — do they match actual API?
4. Fix implementation, not tests (unless tests are genuinely wrong)
5. Check for timing issues — use condition-based waiting, not arbitrary delays
6. Check for environment differences — CI vs local

## Agent Support

| Agent | Purpose | When to Use |
|-------|---------|-------------|
| **tdd-guide** | TDD enforcement, RED→GREEN→IMPROVE cycles | New features, all code changes (PROACTIVE) |
| **e2e-runner** | Playwright E2E test generation and execution | Critical user flows, integration testing |

## Coverage Guidelines

- **80% minimum** overall coverage target
- Focus coverage on: business logic, error paths, edge cases
- Low-value coverage: getters/setters, framework boilerplate, type definitions
- When coverage drops below 80%: prioritize tests for changed files first
