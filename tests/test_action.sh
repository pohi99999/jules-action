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
    local -A expected=(
      ["prompt"]="$prompt_content"
      ["branch"]="$starting_branch"
      ["source"]="sources/github/$repo_full_name"
      ["approval"]="false"
      ["mode"]="AUTO_CREATE_PR"
    )

    local -A paths=(
      ["prompt"]=".prompt"
      ["branch"]=".sourceContext.githubRepoContext.startingBranch"
      ["source"]=".sourceContext.source"
      ["approval"]=".requirePlanApproval"
      ["mode"]=".automationMode"
    )

    local -A labels=(
      ["prompt"]="prompt"
      ["branch"]="starting branch"
      ["source"]="source"
      ["approval"]="requirePlanApproval"
      ["mode"]="automationMode"
    )

    local errors=""
    local field
    for field in prompt branch source approval mode; do
      local actual=$(jq -r "${paths[$field]}" jules_payload.json)
      local want="${expected[$field]}"
      if [ "$actual" != "$want" ]; then
        if [ "$field" == "prompt" ]; then
          errors+="  - Incorrect prompt\n"
        else
          errors+="  - Incorrect ${labels[$field]}: got $actual, want $want\n"
        fi
      fi
    done

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
