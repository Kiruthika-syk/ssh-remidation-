#!/bin/bash
# One-time GitHub push using token from ~/.github_token (not committed to git)
set -euo pipefail

TOKEN_FILE="${HOME}/.github_token"
REPO="https://github.com/Kiruthika-syk/ssh-remidation-.git"
USER="Kiruthika-syk"

if [[ ! -f "${TOKEN_FILE}" ]]; then
  echo "ERROR: ${TOKEN_FILE} not found."
  echo ""
  echo "Create it with your GitHub token (classic token needs 'repo' scope):"
  echo "  echo 'ghp_YOUR_TOKEN_HERE' > ~/.github_token"
  echo "  chmod 600 ~/.github_token"
  exit 1
fi

TOKEN="$(tr -d '[:space:]' < "${TOKEN_FILE}")"
if [[ -z "${TOKEN}" || "${TOKEN}" != ghp_* ]]; then
  echo "ERROR: Token in ${TOKEN_FILE} looks invalid (should start with ghp_)."
  exit 1
fi

cd /home/tpx-admin
git remote set-url origin "${REPO}"

export GIT_TERMINAL_PROMPT=0
export GIT_ASKPASS=/bin/false

# Push via authenticated URL (token never printed)
git push "https://${USER}:${TOKEN}@github.com/Kiruthika-syk/ssh-remidation-.git" master

git remote set-url origin "${REPO}"
git branch --set-upstream-to=origin/master master 2>/dev/null || true

echo ""
echo "SUCCESS: pushed to ${REPO}"
echo "View at: https://github.com/Kiruthika-syk/ssh-remidation-"
