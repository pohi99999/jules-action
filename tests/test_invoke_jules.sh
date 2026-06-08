#!/bin/bash
set -e

FAILED=0

echo "Starting tests for 'Invoke Jules' logic..."
echo "---------------------------------------------------"

run_invoke_jules_test() {
  local test_name="$1"
  local api_key="$2"
  local mock_status="$3"
  local mock_body="$4"

  echo "Test: $test_name"

  # Create a mock payload (non-empty)
  echo '{"test": "payload"}' > jules_payload.json

  # Create a mock server script
  cat << EOF > mock_server.py
from http.server import BaseHTTPRequestHandler, HTTPServer
import sys

class MyHandler(BaseHTTPRequestHandler):
    def do_POST(self):
        # Check API Key
        api_key = self.headers.get('X-Goog-Api-Key')
        content_type = self.headers.get('Content-Type')

        # Log headers for verification
        with open('mock_headers.txt', 'w') as f:
            f.write(f"X-Goog-Api-Key: {api_key}\n")
            f.write(f"Content-Type: {content_type}\n")

        self.send_response($mock_status)
        self.send_header('Content-Type', 'application/json')
        self.end_headers()
        self.wfile.write(b'$mock_body')

server = HTTPServer(('localhost', 8081), MyHandler)
server.handle_request()
EOF

  # Run mock server in background
  python3 mock_server.py &
  MOCK_PID=$!

  # Give server a moment to start
  sleep 1

  # Run the script, pointing it to localhost
  export JULES_API_KEY="$api_key"

  # Use sed to patch the URL for testing
  sed -i 's|https://jules.googleapis.com/v1alpha/sessions|http://localhost:8081|' scripts/invoke_jules.sh

  set +e
  OUTPUT=$(./scripts/invoke_jules.sh 2>&1)
  EXIT_CODE=$?
  set -e

  # Revert the patch
  sed -i 's|http://localhost:8081|https://jules.googleapis.com/v1alpha/sessions|' scripts/invoke_jules.sh

  # Cleanup mock server
  kill $MOCK_PID 2>/dev/null || true
  wait $MOCK_PID 2>/dev/null || true

  # Verifications
  if [ "$mock_status" -eq 200 ]; then
    if [ $EXIT_CODE -ne 0 ]; then
      echo "❌ FAIL: Expected success but got exit code $EXIT_CODE"
      echo "Output: $OUTPUT"
      FAILED=1
    else
      # Check if API Key was received correctly
      if grep -q "X-Goog-Api-Key: $api_key" mock_headers.txt; then
         echo "✅ PASS: API key correctly passed in headers"
      else
         echo "❌ FAIL: API key NOT correctly passed in headers"
         cat mock_headers.txt
         FAILED=1
      fi
    fi
  else
    if [ $EXIT_CODE -eq 0 ]; then
      echo "❌ FAIL: Expected failure (status $mock_status) but script succeeded"
      FAILED=1
    else
      echo "✅ PASS: Script failed as expected with status $mock_status"
      if echo "$OUTPUT" | grep -q "Error: Jules API request failed with status $mock_status"; then
         echo "✅ PASS: Error message contains correct status code"
      else
         echo "❌ FAIL: Error message missing or incorrect status code"
         echo "Output: $OUTPUT"
         FAILED=1
      fi
    fi
  fi

  # Cleanup
  rm -f mock_server.py mock_headers.txt
  : > jules_payload.json
}

run_invoke_jules_test "Success case" "my-secret-key" 200 '{"status": "ok"}'
run_invoke_jules_test "API Error 403" "wrong-key" 403 '{"error": "Unauthorized"}'
run_invoke_jules_test "API Error 500" "my-secret-key" 500 '{"error": "Internal Server Error"}'

echo "---------------------------------------------------"
if [ "$FAILED" -eq 1 ]; then
  echo "❌ Tests failed"
  exit 1
else
  echo "✅ All tests passed"
fi
