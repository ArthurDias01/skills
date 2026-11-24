# Skills

A growing collection of practical AI skills I build for my own workflows and share publicly.

These skills are designed to turn repeatable ways of thinking, reviewing, building, and making decisions into reusable instructions that AI agents can apply consistently.

Rather than treating skills as prompts, I think of them as small pieces of operational knowledge: a skill should capture not only **what to do**, but also **how to reason about the task, what good looks like, what to avoid, and why the workflow exists in the first place**.

The repository will continue to evolve as I build skills around product design, UX, engineering, research, decision-making, and other workflows I use regularly.

---

## Skill Catalog

| Skill | What it does | Intent |
| --- | --- | --- |
| [UX Reviewer](./skills/ux-reviewer) | Reviews a selected mobile or frontend screen/feature and identifies UX problems, behavioral friction, accessibility issues, interaction problems, and opportunities for improvement. | Provide a structured UX critique that goes beyond visual polish and considers user psychology, usability, trust, product outcomes, and ethical design. |
| [TypeScript CRAP Score](./skills/typescript-crap-score) | Scores new TypeScript, TSX, and JSX functions on the current branch for CRAP, complexity, and arity. Writes nothing into the repo. | Keep new functions simple: at most 4 arguments, low complexity, no leftover coverage artifacts. |
| [Review Postgres Mistakes](./skills/review-postgres-mistakes) | Finds and fixes the Postgres mistakes from Scott Mead's talk (via Neon's X thread): growing JSONB documents, transactions left open during network calls, bulk DELETE instead of partitions, unused indexes, plus connection churn and missing timeouts. | Catch the patterns that quietly hold connections longer until the pool runs out, in code review or on a live database. |

More skills will be added over time.

---

# UX Reviewer

`ux-reviewer`

A structured UX review skill for mobile applications and frontend products.

The skill is designed for situations where you want an AI agent to critically assess a **specific screen, flow, or feature** rather than give broad or generic design feedback.

Before reviewing anything, the skill establishes exactly what part of the experience should be assessed.

It then evaluates the interface across areas such as:

- usability and interaction design
- information hierarchy
- cognitive load
- clarity and discoverability
- user motivation and behavioral psychology
- accessibility
- trust and transparency
- error prevention and recovery
- mobile and responsive behavior
- product and business impact

The output prioritizes findings by severity and explains both the problem and the reasoning behind the recommendation.

### Behavioral psychology

The skill also incorporates several behavioral principles commonly encountered in product design:

- Smart Defaults
- Goal Gradient Effect
- Reciprocity
- IKEA Effect
- Loss Aversion
- Contrast Effect

These principles are treated as **design lenses rather than conversion hacks**.

The goal is to understand how interface decisions affect user behavior while avoiding manipulative patterns, artificial urgency, misleading defaults, or coercive design.

### Example use cases

You might use the skill to review:

> Review the checkout screen of this mobile app.

> Assess the onboarding flow, particularly the step where users choose their preferences.

> Review this pricing screen and tell me where users may hesitate or misunderstand the plans.

> Evaluate the password-reset experience from a UX and accessibility perspective.

> Review this feature and identify the three highest-impact UX changes we should make before launch.

The reviewer will first establish the exact screen or feature being assessed before performing the review.

---

# TypeScript CRAP Score

`typescript-crap-score`

Scores **new functions on the current git branch** (TypeScript, TSX, JSX). Checks CRAP when coverage can be collected without dirtying the tree, cyclomatic complexity, and arity (max 4 arguments).

It reports in the chat. It does not write coverage folders, score files, or other artifacts into the project.

Install:

```bash
npx skills add ArthurDias01/skills --skill typescript-crap-score
```

---

## Repository Structure

Each skill lives independently inside the `skills/` directory.

```text
skills/
│
├── README.md
│
└── skills/
    │
    ├── ux-reviewer/
    │   ├── SKILL.md
    │   ├── agents/
    │   ├── references/
    │   └── evals/
    │
    ├── typescript-crap-score/
    │   └── SKILL.md
    │
    ├── future-skill/
    │   └── ...
    │
    └── another-skill/
        └── ...
