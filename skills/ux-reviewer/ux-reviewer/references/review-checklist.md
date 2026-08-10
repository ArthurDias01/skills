# UX review checklist

Use this checklist when the target needs a systematic pass. Do not mechanically report every item; surface only meaningful findings.

## Task and hierarchy
- Primary user goal is identifiable within seconds.
- Primary action has appropriate prominence.
- Secondary actions do not compete unnecessarily.
- Content order matches task order.
- Labels use the user's language rather than internal terminology.

## Inputs and forms
- Ask only for necessary information.
- Reuse known data safely.
- Provide appropriate defaults where low-risk and reversible.
- Match input types to expected data.
- Preserve data after validation errors.
- Put validation near the relevant field and explain recovery.
- Do not hide requirements until submit.

## Navigation and orientation
- User knows where they are.
- Back/cancel behavior is predictable.
- Deep links and refresh do not unexpectedly destroy state.
- Mobile navigation does not hide critical destinations without reason.
- Web navigation supports keyboard and browser conventions.

## System feedback
- Loading states prevent duplicate actions.
- Success states explain what happened and what comes next.
- Empty states explain both status and next action.
- Errors identify cause where possible and suggest recovery.
- Destructive changes receive proportional confirmation or undo.

## Cognitive load
- Related information is grouped.
- Users are not required to memorize information from prior steps.
- Choice sets are understandable and not unnecessarily broad.
- Advanced complexity is progressively disclosed.
- Comparisons use consistent attributes and units.

## Accessibility
- Interactive controls have accessible names.
- Focus order follows visual/task order.
- Focus is visible.
- Meaning is not conveyed by color alone.
- Text and controls remain usable under zoom/text scaling.
- Dynamic status is announced where necessary.
- Error messaging is programmatically associated where applicable.
- Motion has alternatives when needed.
- Touch targets and spacing reduce accidental activation.

## Trust and consent
- Price and billing cadence are obvious before purchase.
- Recurring charges are not visually obscured.
- Permission requests are contextual and justified.
- Privacy-sensitive choices are understandable.
- Declining is not intentionally confusing.
- Destructive consequences are explicit.

## Mobile specifics
- Reachability and thumb-zone implications are considered.
- Bottom sheets, modals, keyboards, and safe areas do not obscure controls.
- Gesture-only actions have discoverable alternatives when needed.
- Orientation and interrupted-session recovery are sensible.

## Frontend web specifics
- Keyboard navigation is complete.
- Hover-only information has non-hover access.
- Responsive breakpoints preserve hierarchy and task completion.
- Browser back/forward behavior does not corrupt flow state.
- URLs, deep links, and reload behavior support expected navigation where appropriate.
