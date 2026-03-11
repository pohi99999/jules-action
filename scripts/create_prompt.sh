#!/bin/bash
set -e

# Create initial prompt
# Using printf "%s\n" to avoid edge cases with echo -n or backslashes
printf "%s\n" "$USER_PROMPT" > prompt.txt
