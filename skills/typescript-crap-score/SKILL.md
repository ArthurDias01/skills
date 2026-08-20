---
name: typescript-crap-score
description: Calculate CRAP (Change Risk Anti-Patterns) scores for TypeScript functions to find code that is both complex and under-tested. Use on code reviews, when assessing risky functions, prioritizing tests, or refactoring high-complexity code into simpler pieces.
---

# CRAP Score Analysis for TypeScript

Calculate CRAP scores for TypeScript functions to spot code that is both complex and undertested.

## Background

The CRAP score combines cyclomatic complexity and code coverage into one number:

$$\text{CRAP}(m) = \text{comp}(m)^2 \times (1 - \text{cov}(m))^3 + \text{comp}(m)$$

Where:

- $\text{comp}(m)$ = cyclomatic complexity of function $m$
- $\text{cov}(m)$ = code coverage ratio (0.0 to 1.0) of function $m$

| CRAP Score | Risk Level | Interpretation |
|------------|------------|----------------|
| < 5        | Low        | Simple and well-tested |
| 5-15       | Moderate   | Acceptable for most code |
| 15-30      | High       | Needs more tests or simplification |
| > 30       | Critical   | Refactor and add coverage urgently |

A function with 100% coverage has CRAP equal to its complexity (the minimum). A function with 0% coverage has CRAP = complexity² + complexity.

## When to Use

- User wants to assess which functions are risky because of low coverage and high complexity
- User asks for CRAP score of specific functions, classes, modules, or files
- User wants to prioritize which code to test next
- User wants to evaluate test quality beyond plain coverage percentages
- During code reviews when complexity looks high and tests may be thin
- When refactoring complex TypeScript into simpler pieces guided by CRAP numbers

## When Not to Use

- User just wants to run tests (use the project's normal test command)
- User wants to write new tests from scratch
- User only wants a coverage percentage with no complexity analysis

## Inputs

| Input | Required | Description |
|-------|----------|-------------|
| Target scope | Yes | Function name, class name, module path, or file path to analyze |
| Test command / coverage path | No | How to produce coverage data. Defaults to discovering the project's test runner and existing coverage files |
| Source root | No | Path to the source under analysis (often `src/`) |

## Workflow

### Step 1: Collect code coverage data

CRAP scores always need real coverage data. Never estimate or invent coverage numbers.

Look first for an existing Istanbul-style report (`coverage/coverage-final.json`, `coverage/coverage-v8.json`, or similar). If none exists, or if it is stale, regenerate it.

Common commands (run from project root):

- Jest: `npx jest --coverage --coverageReporters=json --coverageDirectory=./coverage`
- Vitest (v8 or istanbul provider): `npx vitest run --coverage`
- c8 / nyc wrappers: whatever the repo already uses that emits Istanbul JSON or LCOV

If the project already has a coverage script in `package.json`, prefer that. Search recursively for `coverage-final.json` or `lcov.info` under the results directory.

If tests fail but still execute, use the coverage from the tests that ran and note the failures.

If every collection path fails, report that coverage could not be collected, show the commands tried and their errors, and stop. You may still report raw complexity if it is useful, but never publish a CRAP number based on assumed coverage.

### Step 2: Compute cyclomatic complexity

Read the target source files and count decision points per function. Base complexity is 1. Each of the following adds 1:

| Construct | Example |
|-----------|---------|
| if | `if (x > 0)` |
| else if | `else if (y < 0)` |
| case (each) | `case 1:` |
| for / for...of / for...in / for await | `for (const item of list)` |
| while | `while (running)` |
| do...while | `do { } while (cond)` |
| catch (each) | `catch (err)` |
| && | `if (a && b)` |
| \|\| | `if (a \|\| b)` |
| ?? | `value ?? fallback` |
| ternary | `x > 0 ? a : b` |
| logical assignment | `a &&= b`, `a \|\|= b`, `a ??= b` |

Optional chaining (`?.`) is usually not counted as a branch (matches common ESLint complexity behavior). Nested functions and arrow functions are scored on their own bodies. Report the breakdown of decision points for each function.

### Step 3: Extract per-function coverage

Parse the coverage report (prefer Istanbul `coverage-final.json`). For each function, take the statement coverage (or the minimum of statement and branch coverage when both are present).

If only line-level data is available:

$$\text{cov}(m) = \frac{\text{lines with hits} > 0}{\text{total lines}}$$

Function names in coverage maps often differ from source (arrow functions, async, generators, class methods). Match by source location / line ranges when names do not line up.

### Step 4: Calculate CRAP scores

For each function in scope apply:

$$\text{CRAP}(m) = \text{comp}(m)^2 \times (1 - \text{cov}(m))^3 + \text{comp}(m)$$

### Step 5: Present results

Show a table sorted highest CRAP first:

| Function | Complexity | Coverage | CRAP Score | Risk |
|----------|------------|----------|------------|------|
| OrderService.processOrder | 12 | 45% | 28.4 | High |
| OrderService.validateItems | 8 | 90% | 8.1 | Moderate |
| OrderService.calculateTotal | 3 | 100% | 3.0 | Low |

Include:

- Summary: total functions analyzed, count in each risk band
- Top offenders: functions with CRAP > 30, with concrete recommendations
- Quick wins: high-complexity functions where a modest coverage increase would drop the score a lot

### Step 6: Provide actionable recommendations

For high-CRAP functions suggest one or both:

- Add tests — name the uncovered branches and sketch specific test cases
- Reduce complexity — propose extract-function or early-return refactors for nested logic

Calculate the coverage needed to bring a function under CRAP 15:

$$\text{cov}_{\text{needed}} = 1 - \left(\frac{15 - \text{comp}}{\text{comp}^2}\right)^{1/3}$$

This only works when complexity < 15. When complexity ≥ 15 the lowest possible CRAP is the complexity itself, so coverage alone cannot get under the threshold. The function must be simplified first.

Report it like: "To bring processOrder (complexity 12) under CRAP 15, raise coverage from 45% to at least 72%." For functions where complexity already exceeds the threshold: "complexMethod (complexity 18) cannot reach CRAP < 15 through testing alone — extract sub-functions first."

## Validation

- Confirm coverage data was collected successfully and the file contains real numbers
- Every coverage figure must come from that file — no estimates, no guesses from comments
- Cross-check function names or line ranges against the source
- Spot-check the formula on at least one function by hand
- A 100%-covered function must show CRAP exactly equal to its complexity

## Common Pitfalls

- Estimating coverage when collection fails. Never do it. Work the fallbacks, then report the blocker.
- Trusting a stale `// complexity: 7` comment. Always recompute from current source.
- Using an old coverage report. Always regenerate before scoring.
- Name mismatches. Coverage maps mangle async, arrow, and class methods. Match by line range.
- Generated files. Skip `*.d.ts`, build output, and auto-generated code unless the user explicitly asks for them.
