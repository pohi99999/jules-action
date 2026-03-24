#!/bin/bash
set -e

# scripts/save_git_info.sh
# Securely appends git information to prompt.txt

MODE="$1"

if [ "$MODE" == "--last-commit" ]; then
  {
    printf '\n\nContent of the latest commit (in the format of `git show`):\n'
    printf '```\n'
    git show | sed 's/```/` ` `/g'
    printf '```\n'
  } >> prompt.txt
elif [ "$MODE" == "--commit-log" ]; then
  {
    printf '\n\nLog of the last 20 commits (in the format of `git log --stat`):\n'
    printf '```\n'
    git log -20 --stat | sed 's/```/` ` `/g'
    printf '```\n'
  } >> prompt.txt
else
  echo "Usage: $0 [--last-commit | --commit-log]" >&2
  exit 1
fi
