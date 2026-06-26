#!/bin/bash
set -e

FAILED=0

echo "Starting tests for environment variable expansion in 'create_prompt.sh'..."
echo "---------------------------------------------------"

run_expansion_test() {
  local test_name="$1"
  local prompt_value="$2"
  local expected_output="$3"
  shift 3
  # Remaining arguments are environment variables to set

  # Set environment variables
  while (( "$#" )); do
    export "$1"
    shift
  done

  export USER_PROMPT="$prompt_value"

  ./scripts/create_prompt.sh

  # We use printf "%s\n" to match what create_prompt.sh does
  printf "%s\n" "$expected_output" > expected_prompt.txt

  if ! cmp -s prompt.txt expected_prompt.txt; then
    echo "❌ FAIL: $test_name"
    echo "Expected:"
    cat -v expected_prompt.txt
    echo "Got:"
    cat -v prompt.txt
    FAILED=1
  else
    echo "✅ PASS: $test_name"
  fi

  rm -f prompt.txt expected_prompt.txt
  # Unset environment variables to avoid interference (optional but good practice)
}

run_expansion_test "Simple expansion" "Hello \$NAME" "Hello World" "NAME=World"
run_expansion_test "Braced expansion" "Hello \${NAME}" "Hello World" "NAME=World"
run_expansion_test "Multiple expansions" "\$GREET \$NAME" "Hello World" "GREET=Hello" "NAME=World"
run_expansion_test "Escaped dollar sign" "Price is \\\$100" "Price is \$100"
run_expansion_test "Unset variable (remains as is)" "Hello \$UNKNOWN" "Hello \$UNKNOWN"
run_expansion_test "Mixed content" "User \$USER says: \${MSG}" "User jules says: hello world" "USER=jules" "MSG=hello world"
run_expansion_test "Expansion with special chars in value" "\$VAL" "Quotes \" and \$ and \\" "VAL=Quotes \" and \$ and \\"

echo "---------------------------------------------------"
if [ "$FAILED" -eq 1 ]; then
  echo "❌ Expansion tests failed"
  exit 1
else
  echo "✅ All expansion tests passed"
fi
