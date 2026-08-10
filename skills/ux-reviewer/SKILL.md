---
name: ux-reviewer
description: Review UX decisions for a specific mobile or frontend app screen or feature. Use this skill whenever the user asks to assess, critique, audit, improve, validate, or compare a UI/UX flow, screen, interaction, onboarding step, form, checkout, paywall, settings experience, navigation pattern, or product feature. Require the user to select the exact screen or feature being assessed before reviewing it. Evaluate usability, interaction clarity, information architecture, accessibility, cognitive load, behavioral psychology, trust, conversion/retention implications, and implementation tradeoffs, then provide prioritized recommendations with rationale.
---

# UX Reviewer

Review one clearly selected UI screen or feature at a time and turn observations into prioritized product decisions.

## Intake gate

Before assessing anything, establish the review target.

1. Require the user to identify exactly one primary target:
   - a named screen, such as "Checkout", "Profile", or "Search results"; or
   - a bounded feature/flow, such as "password reset", "first-run onboarding", or "upgrade prompt".
2. If the user provides multiple screens/features, ask them to select one primary target first. Offer to review the others afterward.
3. Accept any useful evidence the user provides, including screenshots, recordings, mockups, code, written descriptions, analytics context, or product goals.
4. If no visual artifact is available, proceed from the description but label visual or interaction assumptions explicitly.
5. Ask only for missing context that materially changes the review. Prefer reasonable assumptions for minor gaps.

Do not produce a UX verdict before the target is bounded.

## Review sequence

Use this order so the review stays anchored to the user's goal rather than becoming a generic heuristic dump.

### 1. Establish user intent and success

Identify:
- primary user goal on this screen/feature;
- primary business/product goal;
- critical action or completion event;
- likely user state: new, returning, expert, stressed, comparison-shopping, etc.;
- platform constraints: mobile, responsive web, desktop web, or hybrid.

If these are not explicit, infer cautiously and state the inference.

### 2. Map the experience

Describe the current experience in a compact sequence:
- entry point;
- information presented;
- decisions required;
- primary and secondary actions;
- feedback after action;
- exit, error, or recovery paths.

Look for unnecessary steps, hidden dependencies, ambiguous state changes, and mismatches between visual hierarchy and task priority.

### 3. Evaluate the core UX dimensions

Assess only dimensions that are relevant to the selected target.

#### Clarity and hierarchy
- Is the primary task immediately obvious?
- Does visual hierarchy match importance?
- Are labels concrete and action-oriented?
- Are primary and secondary actions distinguishable?
- Does the screen expose too many equal-weight choices?

#### Interaction and feedback
- Are controls recognizable and predictable?
- Is system status visible after user actions?
- Are loading, success, empty, error, disabled, and destructive states handled?
- Can users recover from mistakes without losing work?
- Are touch targets, gesture dependencies, and keyboard/focus behavior appropriate for the platform?

#### Cognitive load and decision effort
- How much must users remember, compare, calculate, or decide?
- Can choices be reduced, grouped, sequenced, or safely defaulted?
- Is complexity disclosed progressively?
- Are users forced to make decisions before they have enough context?

#### Information architecture and navigation
- Does the content structure match the user's mental model?
- Is navigation location and direction clear?
- Are back, cancel, close, and escape behaviors predictable?
- Does the feature preserve context when users move between states?

#### Accessibility and inclusive use
Check relevant issues such as:
- semantic structure and accessible names;
- keyboard/focus order;
- screen-reader announcements and state changes;
- color-independent meaning;
- readable contrast and text sizing;
- motion sensitivity;
- error identification and recovery;
- tap target size and spacing;
- localization and text expansion resilience.

Do not claim formal WCAG conformance unless enough implementation evidence is available. Distinguish "likely issue" from "verified violation".

#### Trust and user control
- Are consequences clear before commitment?
- Are pricing, permissions, privacy implications, recurring charges, destructive actions, and data use transparent?
- Are defaults reversible and easy to understand?
- Can users decline or defer without deceptive friction?
- Are confirmation patterns proportional to the risk of the action?

### 4. Apply behavioral psychology carefully

Read `references/psychology-principles.md` when the screen/feature includes choice architecture, onboarding progress, commitment, personalization, upgrades, pricing, retention prompts, or other behavior-shaping decisions.

Use psychology to reduce friction, improve comprehension, and support informed action. Do not recommend deceptive, coercive, manipulative, or misleading patterns. Flag any current pattern that appears to exploit users rather than help them.

### 5. Identify the highest-impact problems

Separate findings into:
- **Blockers**: likely to prevent task completion, create severe confusion, exclude users, or cause meaningful harm.
- **High impact**: likely to materially improve completion, confidence, conversion, retention, or error rate.
- **Medium impact**: meaningful usability improvements with narrower effect.
- **Polish**: refinements that improve quality but should not outrank structural problems.

Avoid inflating severity. Aesthetic preference alone is not a blocker.

### 6. Recommend changes as decisions

For every important recommendation, include:
- the problem;
- evidence or reasoning;
- recommended change;
- expected user impact;
- tradeoff or risk;
- how to validate it.

Prefer specific behavioral changes over vague advice like "make this cleaner" or "improve hierarchy".

When useful, give revised microcopy, layout ordering, state logic, or interaction behavior. Do not redesign unrelated parts of the product.

### 7. Suggest validation

Choose lightweight validation proportional to uncertainty, for example:
- 5-user usability test around a specific task;
- funnel or step-drop analysis;
- time-on-task and error-rate comparison;
- A/B test when the change is isolated and ethically appropriate;
- accessibility testing with keyboard and screen reader;
- session replay review for a specific interaction failure;
- prototype test before engineering investment.

Name the hypothesis and success signal instead of merely saying "test it".

## Output format

Use this structure unless the user requests another format.

# UX review: [screen or feature]

## Executive verdict
Give a 2-4 sentence summary of whether the current design supports the primary user goal, the biggest risk, and the highest-leverage opportunity.

## What works
Call out 2-5 decisions worth preserving. Do not invent praise when evidence is weak.

## Priority findings
For each finding use:

### [Severity] [Finding title]
- **Observed:** What the interface currently does.
- **Why it matters:** User-behavior, usability, accessibility, trust, or business reasoning.
- **Recommendation:** A concrete change.
- **Expected impact:** What should improve.
- **Tradeoff:** Cost, risk, or downside.
- **Validation:** How to test the decision.

## Psychology check
Include only principles that materially apply. State whether each is being used well, missed, or used in a potentially manipulative way.

## Accessibility check
Summarize verified or likely accessibility concerns and what evidence would be needed to confirm them.

## Recommended next move
Name the single change or experiment to do first and explain why it outranks the others.

## Review rules

- Review the selected target, not the entire product unless explicitly requested.
- Tie criticism to user goals and observable behavior, not taste.
- Distinguish facts, observations, assumptions, and hypotheses.
- Do not fabricate research, benchmark percentages, or user data.
- Treat analytics claims supplied by the user as context, not universal truth.
- Prefer reversible, transparent defaults over coercive choice architecture.
- Do not recommend false urgency, confirmshaming, hidden opt-outs, trick questions, disguised ads, forced continuity, or intentional obstruction.
- Use platform-native conventions unless there is a strong reason to diverge.
- When mobile and web conventions differ, call out the platform-specific implication.
- Preserve useful constraints from the user's design system, technical architecture, or business model when known.

## Reference files

- Read `references/psychology-principles.md` for the six behavior-design principles and ethical application rules.
- Read `references/review-checklist.md` when a broad systematic pass is needed or when evidence is limited.
- Read `references/output-examples.md` when you need examples of strong finding phrasing or severity calibration.
