#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Function to cleanup background processes on exit
cleanup() {
    echo ""
    echo "🛑 Shutting down Nexus Studio..."
    kill $(jobs -p) 2>/dev/null
    exit
}

trap cleanup INT TERM EXIT

echo "--------------------------------------------"
echo "🚀 NEXUS STUDIO: Starting Collaborative Environment"
echo "--------------------------------------------"

# 0. Start DevTool Server
if [ -d "$ROOT_DIR/packages/tooling/dev_tool_server" ]; then
    echo "🛠️  [1/3] Launching DevTool Server..."
    cd "$ROOT_DIR/packages/tooling/dev_tool_server"
    dart pub get > /dev/null
    dart run bin/dev_tool_server.dart &
    DEVTOOL_PID=$!
    cd "$SCRIPT_DIR"
else
    echo "🛠️  [1/3] DevTool Server not found. Skipping."
fi

# 1. Start Server
echo "📦 [2/3] Launching Relay Server..."
cd "$SCRIPT_DIR/server"
dart pub get > /dev/null
dart run bin/server.dart &
SERVER_PID=$!
cd "$SCRIPT_DIR"

# 2. Start App
echo "📱 [3/3] Launching Flutter App ..."
cd "$SCRIPT_DIR/app"
flutter pub get > /dev/null

# Default to chrome (use -d <device> to change)
DEVICE="chrome"
if [[ "$*" == *"-d"* ]]; then
    # Pass through device arguments if provided
    flutter run "$@"
else
    flutter run -d $DEVICE
fi

# Wait for all background processes
wait
