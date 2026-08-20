#!/usr/bin/env bash
# publish-to-skills-sh.sh
# Preps ArthurDias01/skills for discovery on skills.sh and registers it
# by triggering the CLI telemetry event skills.sh relies on for listing.
#
# Usage: run from inside your local clone of the repo, e.g.:
#   cd ~/code/skills && bash publish-to-skills-sh.sh

set -euo pipefail

REPO_SLUG="ArthurDias01/skills"
BADGE_LINE="[![skills.sh](https://skills.sh/b/${REPO_SLUG})](https://skills.sh/${REPO_SLUG})"

echo "==> Checking we're in a git repo"
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
  echo "ERROR: not inside a git repository. cd into your local clone first."
  exit 1
}

echo "==> Verifying each skill has a valid SKILL.md with name + description frontmatter"
missing=0
while IFS= read -r -d '' f; do
  if ! grep -q "^name:" "$f" || ! grep -q "^description:" "$f"; then
    echo "  WARNING: $f is missing 'name:' or 'description:' in frontmatter"
    missing=1
  else
    echo "  OK: $f"
  fi
done < <(find skills -maxdepth 2 -name "SKILL.md" -print0)

if [ "$missing" -eq 1 ]; then
  echo "  Fix the frontmatter above before publishing — skills.sh search matches on it."
fi

echo "==> Adding skills.sh install badge to README.md if missing"
if [ -f README.md ] && ! grep -qF "skills.sh/b/${REPO_SLUG}" README.md; then
  tmpfile=$(mktemp)
  {
    head -n 2 README.md
    echo ""
    echo "$BADGE_LINE"
    echo ""
    tail -n +3 README.md
  } > "$tmpfile"
  mv "$tmpfile" README.md
  echo "  Badge added."
else
  echo "  Badge already present or README.md not found — skipping."
fi

echo "==> Staging and committing changes (if any)"
git add -A
if git diff --cached --quiet; then
  echo "  Nothing to commit."
else
  git commit -m "chore: add skills.sh install badge"
  echo "  Committed."
fi

echo "==> Pushing to origin"
current_branch=$(git rev-parse --abbrev-ref HEAD)
git push origin "$current_branch"

echo "==> Registering with skills.sh by running the install command (generates telemetry)"
npx --yes skills add "${REPO_SLUG}" || {
  echo "  NOTE: npx skills add failed. Make sure Node/npm is installed and you have network access."
  exit 1
}

echo "==> Also registering individual skill paths"
npx --yes skills add "${REPO_SLUG}" --skill ux-reviewer || true
npx --yes skills add "${REPO_SLUG}" --skill typescript-crap-score || true

echo "==> Done. It can take a little time for the leaderboard/search index to reflect the new install(s)."
echo "    Check: https://skills.sh/${REPO_SLUG}"