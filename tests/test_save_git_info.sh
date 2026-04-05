#!/bin/bash
set -e

FAILED=0

echo "Starting tests for 'save_git_info.sh'..."
echo "---------------------------------------------------"

# Get absolute path to scripts directory
SCRIPTS_DIR="$(cd "$(dirname "$0")/../scripts" && pwd)"

# Create a temporary directory for tests
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

# Create a fake git binary to mock git outputs
mkdir -p "$TEST_DIR/bin"
cat <<'EOF_GIT' > "$TEST_DIR/bin/git"
#!/bin/bash
# Use octal for backtick (\140) to represent triple backticks safely
backticks="\140\140\140"
if [ "$1" == "show" ]; then
  printf "commit abc123def\n\n    Test commit with %b triple backticks\n" "$backticks"
elif [ "$1" == "log" ]; then
  printf "commit abc123def\n\n    Test commit with %b triple backticks\n" "$backticks"
fi
EOF_GIT
chmod +x "$TEST_DIR/bin/git"

# Add fake bin to PATH
OLD_PATH="$PATH"
export PATH="$TEST_DIR/bin:$PATH"

run_test() {
  local test_name="$1"
  local mode="$2"
  local initial_content="$3"
  local expected_header="$4"

  echo "$initial_content" > "$TEST_DIR/prompt.txt"

  if [ "$mode" == "--invalid" ]; then
      if "$SCRIPTS_DIR/save_git_info.sh" "$mode" 2>"$TEST_DIR/actual_stderr"; then
          echo "❌ FAIL: $test_name - Expected failure for invalid mode"
          FAILED=1
      else
          if grep -q "Usage:" "$TEST_DIR/actual_stderr"; then
              echo "✅ PASS: $test_name"
          else
              echo "❌ FAIL: $test_name - Usage message not found in stderr"
              FAILED=1
          fi
      fi
  else
      pushd "$TEST_DIR" > /dev/null
      "$SCRIPTS_DIR/save_git_info.sh" "$mode"
      popd > /dev/null

      if grep -q "$expected_header" "$TEST_DIR/prompt.txt"; then
          # Check for initial content preservation
          if grep -q "$initial_content" "$TEST_DIR/prompt.txt"; then
              # Check for triple backtick escaping (they should be replaced with ` ` `)
              if grep -F '` ` `' "$TEST_DIR/prompt.txt" > /dev/null; then
                  echo "✅ PASS: $test_name"
              else
                  echo "❌ FAIL: $test_name - Triple backticks not correctly escaped"
                  cat "$TEST_DIR/prompt.txt"
                  FAILED=1
              fi
          else
              echo "❌ FAIL: $test_name - Initial content not preserved"
              FAILED=1
          fi
      else
          echo "❌ FAIL: $test_name - Expected header '$expected_header' not found in prompt.txt"
          FAILED=1
      fi
  fi

  rm -f "$TEST_DIR/prompt.txt" "$TEST_DIR/actual_stderr"
}

run_test "Last commit mode" "--last-commit" "Existing prompt content" "Content of the latest commit"
run_test "Commit log mode" "--commit-log" "Existing prompt content" "Log of the last 20 commits"
run_test "Invalid mode" "--invalid" "Should stay" "No header"

export PATH="$OLD_PATH"

echo "---------------------------------------------------"
if [ "$FAILED" -eq 1 ]; then
  echo "❌ Tests failed"
  exit 1
else
  echo "✅ All tests passed"
fi
