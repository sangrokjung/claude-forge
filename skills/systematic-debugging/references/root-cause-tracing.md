# Root Cause Tracing

## Overview

Bugs often surface deep in the call stack. The temptation is to fix where the error appears, but that's treating symptoms.

**Core principle: Trace the call chain backwards to find the original trigger. Fix at the source.**

## When to Use

- Error occurs deep in the stack, not at the entry point
- Stack trace shows a long call chain
- Invalid data origin is unclear
- Need to identify which test/code triggers the problem

## 5-Step Backtracing

### 1. Observe the Symptom
```
Error: git init failed in /Users/project/packages/core
```

### 2. Find the Immediate Cause
**Does this code directly produce the error?**
```typescript
await execFileAsync('git', ['init'], { cwd: projectDir });
```

### 3. Trace Callers
```
WorktreeManager.createSessionWorktree(projectDir, sessionId)
  → Session.initializeWorkspace()
  → Session.create()
  → test: Project.create()
```

### 4. Trace Values
**What value was passed?**
- `projectDir = ''` (empty string!)
- Empty string `cwd` resolves to `process.cwd()`

### 5. Find the Origin
**Where did the empty string come from?**
```typescript
const context = setupCoreTest(); // returns { tempDir: '' }
Project.create('name', context.tempDir); // accessed before beforeEach!
```
→ Fix: change tempDir to a getter that throws if accessed before beforeEach

## Stack Trace Instrumentation

When manual tracing fails, add instrumentation:

```typescript
async function gitInit(directory: string) {
  const stack = new Error().stack;
  console.error('DEBUG git init:', {
    directory,
    cwd: process.cwd(),
    stack,
  });
  await execFileAsync('git', ['init'], { cwd: directory });
}
```

**Key points:**
- Use `console.error()` in tests (loggers may be suppressed)
- Log **before** dangerous operations (not after failure)
- Include directory, cwd, env vars, timestamps
- Use `new Error().stack` to capture the full call chain

## Test Pollution Detection

When you don't know which test causes pollution, use bisection:

```bash
# Run tests one by one to find the polluter
for test in src/**/*.test.ts; do
  npx vitest run "$test" 2>&1 | grep -q "pollution evidence" && echo "POLLUTER: $test" && break
done
```

## Key Takeaway

**Never fix only where the symptom appears.** Trace back to the original trigger.
