#!/bin/bash
set -e

# Assemble Jules payload
# Using --rawfile for the prompt to avoid shell command-line length limits (ARG_MAX)
jq -n --rawfile jules_prompt prompt.txt --arg starting_branch "$STARTING_BRANCH" --arg repo_full_name "$REPO_FULL_NAME" '{
    "prompt": $jules_prompt,
    "sourceContext": {
      "source": "sources/github/\($repo_full_name)",
      "githubRepoContext": {
        "startingBranch": $starting_branch
      }
    },
    "requirePlanApproval": false,
    "automationMode": "AUTO_CREATE_PR"
  }' > jules_payload.json
