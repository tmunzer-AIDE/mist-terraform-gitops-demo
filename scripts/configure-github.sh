#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "Usage: $0 OWNER/REPOSITORY [ENVIRONMENT_REVIEWER]" >&2
  exit 2
fi

repository="$1"
reviewer="${2:-}"
visibility="$(gh api "repos/${repository}" --jq .visibility)"

gh api \
  --method PUT \
  "repos/${repository}/actions/permissions" \
  --input - <<'JSON'
{
  "enabled": true,
  "allowed_actions": "selected",
  "sha_pinning_required": true
}
JSON

gh api \
  --method PUT \
  "repos/${repository}/actions/permissions/selected-actions" \
  --input - <<'JSON'
{
  "github_owned_allowed": true,
  "verified_allowed": true,
  "patterns_allowed": []
}
JSON

if [[ "$visibility" == "private" && -z "$reviewer" ]]; then
  gh api \
    --method PUT \
    "repos/${repository}/environments/mist-production" \
    --input - <<'JSON'
{}
JSON

  echo "Configured ${repository} for pinned Actions and manual Terraform operations."
  echo "GitHub Free does not enforce branch or environment protection on private repositories."
  exit 0
fi

if [[ -z "$reviewer" ]]; then
  echo "ENVIRONMENT_REVIEWER is required for a public repository." >&2
  exit 2
fi

reviewer_id="$(gh api "users/${reviewer}" --jq .id)"

gh api \
  --method PUT \
  "repos/${repository}/environments/mist-production" \
  --input - <<JSON
{
  "wait_timer": 0,
  "prevent_self_review": true,
  "reviewers": [
    {"type": "User", "id": ${reviewer_id}}
  ],
  "deployment_branch_policy": null
}
JSON

gh api \
  --method PUT \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "repos/${repository}/branches/main/protection" \
  --input - <<'JSON'
{
  "required_status_checks": {
    "strict": true,
    "contexts": [
      "Trusted PR source",
      "Terraform"
    ]
  },
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": false,
    "required_approving_review_count": 1,
    "require_last_push_approval": true
  },
  "restrictions": null,
  "required_conversation_resolution": true,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "block_creations": false,
  "required_linear_history": true,
  "lock_branch": false,
  "allow_fork_syncing": false
}
JSON

echo "Protected ${repository}:main and mist-production with reviewer ${reviewer}."
