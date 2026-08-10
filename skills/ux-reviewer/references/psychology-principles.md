# Behavioral psychology principles for UX review

Use these principles as lenses, not as automatic prescriptions. The objective is to reduce unnecessary cognitive effort, create momentum, and make value easier to understand while preserving informed choice and user control.

## 1. Smart defaults

**Mechanism:** Defaults reduce decision effort and can communicate a recommended or common path.

**Look for:**
- blank forms that could safely reuse known information;
- repetitive settings with a clearly common choice;
- configuration that forces decisions before users understand consequences;
- defaults that silently benefit the business at the user's expense.

**Recommend when:**
- a choice is low-risk and reversible;
- a common option genuinely serves most users;
- the system can explain or expose the default clearly.

**Avoid:**
- preselecting consent, paid add-ons, subscriptions, data sharing, or other consequential choices merely to increase uptake;
- defaults that are difficult to undo.

**Review prompt:** Does the default reduce effort while still representing the user's likely interest?

## 2. Goal gradient effect

**Mechanism:** Visible proximity to completion can increase motivation.

**Look for:**
- onboarding, setup, profile completion, application, checkout, or multi-step creation flows;
- long processes with no sense of progress;
- misleading progress indicators that imply work is complete when it is not.

**Recommend when:**
- progress accurately reflects meaningful completed work;
- the indicator helps users estimate effort or encourages continuation.

**Avoid:**
- fabricated completion percentages;
- artificial progress that materially misrepresents status.

**Review prompt:** Can the product truthfully show momentum, completed setup, or remaining work more clearly?

## 3. Reciprocity

**Mechanism:** Receiving useful value can increase willingness to continue or commit.

**Look for:**
- sign-up or payment gates that appear before the user understands value;
- tools that could safely preview an outcome before asking for commitment;
- excessive data collection before any benefit is delivered.

**Recommend when:**
- the product can reveal a useful preview, result, trial, or sample without compromising safety or privacy;
- early value helps users make a better-informed decision.

**Avoid:**
- bait-and-switch previews;
- deliberately withholding essential caveats until after commitment.

**Review prompt:** Can the interface prove value before asking for high-friction commitment?

## 4. IKEA / investment effect

**Mechanism:** Meaningful contribution or personalization can increase perceived ownership and relevance.

**Look for:**
- onboarding where users can make useful preferences before account creation;
- customizable products or workspaces;
- premature personalization tasks that create busywork.

**Recommend when:**
- user input immediately improves relevance or creates something they can keep;
- the effort is proportionate to the value created.

**Avoid:**
- artificial effort intended only to make users feel sunk cost;
- long customization before users understand the product.

**Review prompt:** Does early user effort create real, retained value?

## 5. Loss aversion

**Mechanism:** Potential losses often attract more attention than equivalent gains.

**Look for:**
- destructive actions, expiring work, storage limits, unsaved changes, plan downgrades, or permission changes;
- upgrade prompts using fear rather than accurate consequence communication.

**Recommend when:**
- the loss is real, material, and clearly attributable to the user's action or inaction;
- framing helps users avoid an unintended consequence.

**Avoid:**
- invented countdowns;
- exaggerated threats;
- shaming dismissals such as forcing users to affirm reckless behavior;
- vague fear-based copy designed to pressure a purchase.

**Review prompt:** Is the interface warning about a genuine consequence or manufacturing anxiety?

## 6. Contrast and anchoring

**Mechanism:** People evaluate value relative to nearby reference points.

**Look for:**
- pricing, plan comparisons, bundles, add-ons, feature tiers, and upgrade surfaces;
- anchors that make comparison easier versus anchors chosen only to distort perceived affordability.

**Recommend when:**
- comparison uses meaningful alternatives, total costs, or relevant unit economics;
- users can understand what changes between options.

**Avoid:**
- fake reference prices;
- hiding total recurring cost;
- visually minimizing materially more expensive commitments.

**Review prompt:** Does the comparison improve understanding of value and cost, or merely manipulate perception?

# Ethical decision rule

A behavioral technique is acceptable only when it passes all four checks:

1. **Truthful:** the underlying fact, status, consequence, or price is accurate.
2. **Aligned:** the pattern plausibly serves the user's stated or inferred goal.
3. **Reversible:** users can change their choice without unreasonable friction when reversal is technically possible.
4. **Transparent:** the interface does not rely on concealment, confusion, false urgency, or shame.

If a pattern fails one of these checks, flag it as a trust risk and recommend a less manipulative alternative.
