#!/bin/bash
set -e

# Create initial prompt
# Using perl to safely expand environment variables in the USER_PROMPT.
# This prevents prompt injection by passing untrusted data via environment variables.
# Supports $VAR and ${VAR} syntax, and \$ to escape the dollar sign.
printf "%s\n" "$USER_PROMPT" | perl -pe 's/(?<!\\)\$\{?(\w+)\}?/$ENV{$1} \/\/ $&/ge; s/\\(\$)/$1/g' > prompt.txt
