#!/bin/bash
set -e

FAILED=0

echo "Starting tests for 'Create initial prompt' logic..."
echo "---------------------------------------------------"

run_test() {
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

run_test "Single line prompt" "Fix the bug in main.py"
run_test "Multi-line prompt" "Line 1
Line 2
Line 3"
run_test "Special characters" 'Fix bug in "main.py" and '"'"'utils.js'"'"' with \n and $VAR'
run_test "Empty prompt" ""
run_test "Hyphen n prompt" "-n"
run_test "Hyphen e prompt" "-e"

echo "---------------------------------------------------"
if [ "$FAILED" -eq 1 ]; then
  echo "❌ Tests failed"
  kill -s TERM $$
fi
