# Output examples and severity calibration

## Strong finding example

### High impact — The form asks for commitment before showing value
- **Observed:** The first screen requires account creation before users can preview the generated result.
- **Why it matters:** Users must pay the cost of registration before they can judge whether the product solves their problem. This adds commitment at the point of highest uncertainty.
- **Recommendation:** Let users complete the initial input and show a meaningful partial result before requiring account creation to save or export it.
- **Expected impact:** Higher progression into signup and better-informed registrations.
- **Tradeoff:** More anonymous compute and additional abuse controls may be required.
- **Validation:** Compare preview-first vs signup-first flows on preview completion, signup rate, and downstream activation rather than signup rate alone.

## Weak finding to avoid

"The page feels cluttered. Make it cleaner and simplify the layout."

Why it is weak:
- no observable evidence;
- no user goal;
- no concrete recommendation;
- no impact hypothesis;
- driven by taste rather than interaction behavior.

## Severity calibration

### Blocker
Use when users are likely unable to complete the core task, may suffer serious unintended consequences, or a major accessibility barrier excludes the target audience.

Examples:
- submit button is covered by the mobile keyboard with no reliable way to dismiss it;
- payment succeeds but the UI reports failure and encourages duplicate purchase;
- required task is inaccessible by keyboard for a keyboard-dependent user.

### High impact
Use when a problem meaningfully increases abandonment, errors, mistrust, or misunderstanding across a substantial part of the target journey.

### Medium impact
Use when a problem causes friction or confusion but users can usually recover and complete the task.

### Polish
Use for details that improve perceived quality, consistency, or efficiency without materially changing task success.

## Psychology check example

- **Smart defaults — missed opportunity:** A low-risk preference has a dominant common choice, but the user must select it every time. Consider a transparent, reversible default.
- **Loss aversion — trust risk:** The upgrade modal warns that users will "lose everything today," but the actual policy gives a 30-day read-only period. Replace the exaggerated warning with the real consequence and timeline.
