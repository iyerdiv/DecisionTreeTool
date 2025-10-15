#!/bin/bash
# Decision Tree Watcher v2 - Activation Script
# Usage: ./activate.sh /path/to/workspace /path/to/tree.md

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

if [ $# -lt 2 ]; then
    echo "Usage: $0 <watch-path> <tree-path>"
    echo ""
    echo "Example:"
    echo "  $0 /path/to/workspace /path/to/tree.md"
    exit 1
fi

WATCH_PATH="$1"
TREE_PATH="$2"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WATCHER_DIR="$(dirname "$SCRIPT_DIR")"

echo -e "${BLUE}=== Decision Tree Watcher v2 Activation ===${NC}"

# Check if watcher is already running
PIDFILE="${WATCH_PATH}/.watcher.pid"
if [ -f "$PIDFILE" ]; then
    PID=$(cat "$PIDFILE")
    if ps -p "$PID" > /dev/null 2>&1; then
        echo -e "${YELLOW}⚠️  Watcher already running (PID: $PID)${NC}"
        echo -e "${BLUE}To stop: cd $WATCHER_DIR && source venv/bin/activate && ./watcher.py stop --watch-path $WATCH_PATH${NC}"
        exit 0
    else
        # Stale PID file
        rm "$PIDFILE"
    fi
fi

# Activate venv if not already active
if [ -z "$VIRTUAL_ENV" ]; then
    cd "$WATCHER_DIR"
    if [ ! -d "venv" ]; then
        echo -e "${YELLOW}⚡ Creating virtual environment...${NC}"
        python3 -m venv venv
    fi
    source venv/bin/activate

    # Install dependencies if needed
    if ! python3 -c "import watchdog" 2>/dev/null; then
        echo -e "${YELLOW}⚡ Installing dependencies...${NC}"
        pip install -q -r requirements.txt
    fi
fi

echo -e "${BLUE}Starting watcher daemon...${NC}"
./watcher.py start \
    --watch-path "$WATCH_PATH" \
    --tree-path "$TREE_PATH" \
    --daemon

sleep 1

# Verify it started
if [ -f "$PIDFILE" ]; then
    PID=$(cat "$PIDFILE")
    echo -e "${GREEN}✓ Daemon started successfully (PID: $PID)${NC}"
    echo -e "${GREEN}✓ Watching: $WATCH_PATH${NC}"
    echo -e "${GREEN}✓ Logging to: $TREE_PATH${NC}"
    echo ""
    echo -e "${BLUE}Commands:${NC}"
    echo -e "  Status: ./watcher.py status --watch-path $WATCH_PATH"
    echo -e "  Stop:   ./watcher.py stop --watch-path $WATCH_PATH"
    echo -e "  View:   cat $TREE_PATH"
else
    echo -e "${YELLOW}⚠️  Failed to start daemon${NC}"
    exit 1
fi
