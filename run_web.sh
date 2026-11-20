#!/bin/bash
# Master DND - Launch Flutter Web on stable port 8080
# Usage: ./run_web.sh [extra flutter args]

PORT=8080
echo "===================================================="
echo " Starting Master DND Flutter Web on Port $PORT"
echo " URL: http://localhost:$PORT"
echo "===================================================="

# Check if flutter is in PATH, fallback to common install location if needed
if command -v flutter &> /dev/null; then
  FLUTTER_CMD="flutter"
elif [ -f "$HOME/develop/flutter/bin/flutter" ]; then
  FLUTTER_CMD="$HOME/develop/flutter/bin/flutter"
else
  FLUTTER_CMD="flutter"
fi

$FLUTTER_CMD run -d chrome --web-port=$PORT "$@"
