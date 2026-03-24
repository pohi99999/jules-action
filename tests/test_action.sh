#!/bin/bash
set -e

FAILED=0

echo "Starting tests for 'Create initial prompt' logic..."
echo "---------------------------------------------------"

run_create_prompt_test() {
  local test_name="$1"
  local prompt_value="$2"

  export USER_PROMPT="$prompt_value"

  # Call the actual script used by the action
  ./scripts/create_prompt.sh

  if [ ! -f "prompt.txt" ]; then
    echo "❌ FAIL: $test_name - prompt.txt was not created"
    FAILED=1
  else
    # The expected output should match the string value exactly as printed by printf "%s\n"
    printf "%s\n" "$USER_PROMPT" > expected_prompt.txt

    if ! cmp -s prompt.txt expected_prompt.txt; then
      echo "❌ FAIL: $test_name - prompt.txt content is incorrect."
      echo "Expected file content:"
      cat -v expected_prompt.txt
      echo ""
      echo "Got file content:"
      cat -v prompt.txt
      echo ""
      FAILED=1
    else
      echo "✅ PASS: $test_name"
    fi
  fi

  rm -f prompt.txt expected_prompt.txt
}

run_create_prompt_test "Single line prompt" "Fix the bug in main.py"
run_create_prompt_test "Multi-line prompt" "Line 1
Line 2
Line 3"
run_create_prompt_test "Special characters" 'Fix bug in "main.py" and '"'"'utils.js'"'"' with \n and $VAR'
run_create_prompt_test "Empty prompt" ""
run_create_prompt_test "Hyphen n prompt" "-n"
run_create_prompt_test "Hyphen e prompt" "-e"

echo ""
echo "Starting tests for 'Assemble Jules payload' logic..."
echo "---------------------------------------------------"

run_assemble_payload_test() {
  local test_name="$1"
  local prompt_content="$2"
  local starting_branch="$3"
  local repo_full_name="$4"

  echo "$prompt_content" > prompt.txt
  export STARTING_BRANCH="$starting_branch"
  export REPO_FULL_NAME="$repo_full_name"

  ./scripts/assemble_payload.sh

  if [ ! -f "jules_payload.json" ]; then
    echo "❌ FAIL: $test_name - jules_payload.json was not created"
    FAILED=1
  else
    # Verify JSON structure and values
    eval "$(jq -r '@sh "local actual_prompt=\(.prompt) actual_branch=\(.sourceContext.githubRepoContext.startingBranch) actual_source=\(.sourceContext.source) actual_approval=\(.requirePlanApproval) actual_mode=\(.automationMode)"' jules_payload.json)"
    # Strip trailing newlines from actual_prompt to match previous command substitution behavior
    actual_prompt="${actual_prompt%"${actual_prompt##*[!$'\n']}"}"

    local errors=""
    if [ "$actual_prompt" != "$prompt_content" ]; then
      errors+="  - Incorrect prompt\n"
    fi
    if [ "$actual_branch" != "$starting_branch" ]; then
      errors+="  - Incorrect starting branch: got $actual_branch, want $starting_branch\n"
    fi
    if [ "$actual_source" != "sources/github/$repo_full_name" ]; then
      errors+="  - Incorrect source: got $actual_source, want sources/github/$repo_full_name\n"
    fi
    if [ "$actual_approval" != "false" ]; then
      errors+="  - Incorrect requirePlanApproval: got $actual_approval, want false\n"
    fi
    if [ "$actual_mode" != "AUTO_CREATE_PR" ]; then
      errors+="  - Incorrect automationMode: got $actual_mode, want AUTO_CREATE_PR\n"
    fi

    if [ -n "$errors" ]; then
      echo "❌ FAIL: $test_name"
      printf "$errors"
      FAILED=1
    else
      echo "✅ PASS: $test_name"
    fi
  fi

  rm -f prompt.txt jules_payload.json
}

run_assemble_payload_test "Standard payload" "Fix all bugs" "main" "google-labs-code/jules-invoke"
run_assemble_payload_test "Custom branch" "Add feature" "develop" "my-org/my-repo"
run_assemble_payload_test "Multi-line prompt in payload" "Line 1
Line 2" "main" "org/repo"
run_assemble_payload_test "Special characters in payload" 'Quotes " and $ and \ ' "feat/branch" "org/repo"

echo "---------------------------------------------------"
if [ "$FAILED" -eq 1 ]; then
  echo "❌ Tests failed"
  exit 1
else
  echo "✅ All tests passed"
fi
