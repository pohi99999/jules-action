#!/bin/bash
set -e

# scripts/save_git_info.sh
# Securely appends git information to prompt.txt

MODE="$1"

# Helper function to format and append git info to prompt.txt
append_git_info() {
  local header="$1"
  shift
  {
    printf '\n\n%s:\n' "$header"
    printf '```\n'
    "$@" | sed 's/```/` ` `/g'
    printf '```\n'
  } >> prompt.txt
}

if [ "$MODE" == "--last-commit" ]; then
  append_git_info 'Content of the latest commit (in the format of `git show`)' git show
elif [ "$MODE" == "--commit-log" ]; then
  append_git_info 'Log of the last 20 commits (in the format of `git log --stat`)' git log -20 --stat
else
  echo "Usage: $0 [--last-commit | --commit-log]" >&2
  exit 1
fi
