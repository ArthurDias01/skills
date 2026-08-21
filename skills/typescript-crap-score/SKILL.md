---
name: typescript-crap-score
description: Score new TypeScript, TSX, and JSX functions on the current git branch for CRAP risk, cyclomatic complexity, and arity. Use when reviewing a branch, checking newly implemented functions, flagging functions with more than 4 arguments, or deciding what to simplify before merge.
---

# Branch CRAP check for TypeScript

Score **new functions on the current branch**. Goal is readable, maintainable code. Do not leave files, reports, or coverage output in the repo.

## Scope

1. Find the merge base with the default branch (`main` or `master`).
2. Diff `*.ts`, `*.tsx`, `*.jsx` against that base. Skip `*.d.ts`, generated code, and build output.
3. Score only functions that are **added** on this branch (new declarations, new methods, new arrow functions, new React components). Skip untouched functions. If an existing function grew a lot, score it too and label it as changed, not new.
4. If there is no git repo or no function-level diff, stop and say so. Do not walk the whole tree.

## Do not pollute the workspace

Never write coverage, lcov, Istanbul JSON, HTML reports, score tables, or scratch files into the project. Never `git add` any of that.

If you run tests for coverage:

- Send output to a temp dir outside the repo (`mktemp -d` under `$TMPDIR`).
- Point Jest/Vitest/c8/nyc `--coverageDirectory` (or equivalent) at that temp dir.
- Delete the temp dir when you finish, including on failure.
- Prefer an existing in-repo coverage file only if it is already there and current. Do not regenerate it in-place.
- If coverage would dirty the working tree, skip coverage. Report complexity and arity anyway. Do not invent coverage. Do not publish a CRAP number without real coverage.

## Simplicity bar

A new function fails the bar if any of these hold:

| Check | Fail when |
|-------|-----------|
| Arity | More than 4 parameters. Count TS, TSX, and JSX the same. React props: one props object is 1 argument. Destructured props count as 1 if they are a single parameter. Rest + 4 named params is a fail. |
| Complexity | Cyclomatic complexity > 8 |
| CRAP | Score > 15 when coverage exists |

Prefer one object parameter over a long positional list. Prefer extracting a helper over nested branches. Prefer early returns over `else` chains.

## Complexity

Base 1. Add 1 for each: `if`, `else if`, `case`, `for` / `for...of` / `for...in` / `for await`, `while`, `do...while`, `catch`, `&&`, `||`, `??`, ternary, `&&=` / `||=` / `??=`.

Do not count optional chaining (`?.`). Score nested and arrow functions on their own bodies.

## CRAP (only with real coverage)

$$\text{CRAP}(m) = \text{comp}(m)^2 \times (1 - \text{cov}(m))^3 + \text{comp}(m)$$

`cov` is 0.0–1.0 from the coverage file (statement coverage, or min of statement and branch). Match functions by line range when names do not line up.

| CRAP | Band |
|------|------|
| < 5 | Low |
| 5–15 | Moderate |
| 15–30 | High |
| > 30 | Critical |

100% coverage means CRAP equals complexity. Complexity ≥ 15 cannot get under CRAP 15 by tests alone. Split the function.

If coverage is missing, omit the CRAP column. Do not guess.

## Output

Reply in the conversation only. No files.

Table, worst first:

| Function | File | Args | Complexity | Coverage | CRAP | Verdict |
|----------|------|------|------------|----------|------|---------|
| `processOrder` | `src/orders.ts` | 6 | 11 | 40% | 27.4 | Fail: arity + CRAP |
| `OrderCard` | `src/OrderCard.tsx` | 1 | 3 | — | — | Pass |

Then:

- Count of new functions, how many fail, how many pass.
- For each fail, say what to change (drop args, extract, flatten branches). Keep it specific to the source you read.
- If coverage was skipped, say why (would dirty the tree / no runner).

Do not "fix" the code unless the user asked. This skill reports.
