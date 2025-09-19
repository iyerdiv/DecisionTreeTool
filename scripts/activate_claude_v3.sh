#!/bin/bash
# Claude Daily Session Activation Script V3
# Single daily tree with continuous versioning

# Check for project parameter
PROJECT="${1:-OpsBrain}"  # Default to OpsBrain if not specified

echo "🧠 ACTIVATING CLAUDE SESSION"
echo "============================"
echo "Project: $PROJECT"
echo ""

# Get dates
TODAY=$(date '+%Y%m%d')
TODAY_FULL=$(date '+%Y-%m-%d')
YESTERDAY=$(date -v-1d '+%Y%m%d')
NOW=$(date '+%H:%M:%S')

# Set directories
TOOL_DIR="/Volumes/workplace/DecisionTreeTool"
PROJECT_DIR="$TOOL_DIR/$PROJECT"
mkdir -p "$PROJECT_DIR/trees"
mkdir -p "$PROJECT_DIR/prompts"
mkdir -p "$PROJECT_DIR/insights"

# Version tracking file
VERSION_FILE="$PROJECT_DIR/.version"
LINK_FILE="$PROJECT_DIR/.tree_chain"

# Get current version number
if [ -f "$VERSION_FILE" ]; then
    CURRENT_VERSION=$(cat "$VERSION_FILE")
else
    # Count existing trees to determine version
    CURRENT_VERSION=$(ls -1 /Volumes/workplace/*decision_tree*.md 2>/dev/null | wc -l | tr -d ' ')
    if [ -z "$CURRENT_VERSION" ] || [ "$CURRENT_VERSION" -eq 0 ]; then
        CURRENT_VERSION=1
    fi
fi

echo "📊 Version Management"
echo "--------------------"
echo "Current Global Version: V$CURRENT_VERSION"

# Today's tree file
TODAY_TREE="$PROJECT_DIR/trees/decision_tree_${TODAY}.md"

# Check if today's tree already exists
if [ -f "$TODAY_TREE" ]; then
    echo "✓ Continuing today's tree: $(basename $TODAY_TREE)"
    echo ""

    # Add session marker
    echo "" >> "$TODAY_TREE"
    echo "---" >> "$TODAY_TREE"
    echo "## Session Resumed: $(date '+%Y-%m-%d %H:%M:%S')" >> "$TODAY_TREE"
    echo "" >> "$TODAY_TREE"
else
    # Find yesterday's tree for linking
    YESTERDAY_TREE="$PROJECT_DIR/trees/decision_tree_${YESTERDAY}.md"
    if [ ! -f "$YESTERDAY_TREE" ]; then
        # Check other locations
        YESTERDAY_TREE=$(ls -t $PROJECT_DIR/trees/decision_tree_*.md 2>/dev/null | head -1)
        if [ ! -f "$YESTERDAY_TREE" ]; then
            # Check legacy locations for OpsBrain
            if [ "$PROJECT" = "OpsBrain" ]; then
                YESTERDAY_TREE=$(ls -t /Volumes/workplace/OpsBrainMemory/daily_trees/decision_tree_*.md 2>/dev/null | head -1)
            fi
        fi
    fi

    # Increment version for new day
    CURRENT_VERSION=$((CURRENT_VERSION + 1))
    echo $CURRENT_VERSION > "$VERSION_FILE"

    echo "📝 Creating new daily tree"
    echo "Version: V$CURRENT_VERSION"
    echo ""

    # Create new tree with proper linking
    cat > "$TODAY_TREE" << EOF
# Decision Tree - ${TODAY_FULL}
## Project: $PROJECT | Global Version: V$CURRENT_VERSION
## Session Start: $(date '+%Y-%m-%d %H:%M:%S')

---

## Tree Chain
EOF

    # Add link to previous tree
    if [ -f "$YESTERDAY_TREE" ]; then
        PREV_VERSION=$((CURRENT_VERSION - 1))
        echo "**Previous**: [$(basename $YESTERDAY_TREE)]($YESTERDAY_TREE) (V$PREV_VERSION)" >> "$TODAY_TREE"

        # Extract key context from previous tree
        echo "" >> "$TODAY_TREE"
        echo "### Carried Forward from V$PREV_VERSION" >> "$TODAY_TREE"

        # Get last 3 TODOs if any
        TODOS=$(grep "TODO:" "$YESTERDAY_TREE" 2>/dev/null | tail -3)
        if [ -n "$TODOS" ]; then
            echo "#### Outstanding TODOs:" >> "$TODAY_TREE"
            echo "$TODOS" | while IFS= read -r line; do
                echo "- $line" >> "$TODAY_TREE"
            done
            echo "" >> "$TODAY_TREE"
        fi

        # Get last decision point
        LAST_DECISION=$(grep -E "Decision:|DECISION:" "$YESTERDAY_TREE" 2>/dev/null | tail -1)
        if [ -n "$LAST_DECISION" ]; then
            echo "#### Last Decision:" >> "$TODAY_TREE"
            echo "- $LAST_DECISION" >> "$TODAY_TREE"
            echo "" >> "$TODAY_TREE"
        fi

        # Update tree chain file
        echo "$(basename $YESTERDAY_TREE) -> $(basename $TODAY_TREE)" >> "$LINK_FILE"
    else
        echo "**Previous**: None (First tree in chain)" >> "$TODAY_TREE"
        echo "$(basename $TODAY_TREE)" > "$LINK_FILE"
    fi

    cat >> "$TODAY_TREE" << EOF

---

## Today's Work

### Morning Session - $NOW

#### Context
- Working Directory: /Volumes/workplace
- Active Project: $PROJECT
- Session Type: ${SESSION_TYPE:-Development}

#### Objectives
1. Review previous work
2. Continue outstanding tasks
3. Document decisions

---

## Decision Log

### Node 1 - Initialization [$NOW]
**Status**: Session initialized
**Context**: Loaded previous tree context, ready for work
**Next**: Await user objectives

EOF

    echo "✓ Created: $(basename $TODAY_TREE)"
fi

# Load insights and prompts
echo ""
echo "📖 Loading context files..."

# Find latest prompt
LATEST_PROMPT=$(ls -t $PROJECT_DIR/prompts/NEXT_CLAUDE_PROMPT*.md 2>/dev/null | head -1)
if [ -f "$LATEST_PROMPT" ]; then
    echo "   ✓ Prompt: $(basename $LATEST_PROMPT)"
fi

# Find latest insights
LATEST_INSIGHTS=$(ls -t $PROJECT_DIR/insights/KEY_INSIGHTS*.md 2>/dev/null | head -1)
if [ -f "$LATEST_INSIGHTS" ]; then
    echo "   ✓ Insights: $(basename $LATEST_INSIGHTS)"
fi

# Create/update session management script
echo ""
echo "💾 Session Commands"
echo "-------------------"
echo "Quick commands available:"
echo "  save    - Save current session"
echo "  bye     - End session and prepare for tomorrow"
echo "  status  - Check session status"

# Create quick command aliases
cat > "$TOOL_DIR/.session_commands" << 'EOF'
alias save="bash /Volumes/workplace/DecisionTreeTool/scripts/save_session.sh"
alias bye="bash /Volumes/workplace/DecisionTreeTool/scripts/bye_claude_v3.sh"
alias status="bash /Volumes/workplace/DecisionTreeTool/claude.sh status"
EOF

# Display insights if they exist
if [ -f "$LATEST_INSIGHTS" ]; then
    echo ""
    echo "💡 KEY INSIGHTS FROM PREVIOUS SESSION"
    echo "--------------------------------------"
    head -15 "$LATEST_INSIGHTS"
fi

echo ""
echo "📍 SESSION INFO"
echo "---------------"
echo "Project: $PROJECT"
echo "Today's Tree: $(basename $TODAY_TREE)"
echo "Global Version: V$CURRENT_VERSION"
echo "Tree Location: $PROJECT_DIR/trees/"

# For OpsBrain, maintain compatibility
if [ "$PROJECT" = "OpsBrain" ]; then
    LEGACY_DIR="/Volumes/workplace/OpsBrainMemory/daily_trees"
    ln -sf "$TODAY_TREE" "$LEGACY_DIR/decision_tree_${TODAY}_V${CURRENT_VERSION}.md" 2>/dev/null
    echo "Legacy Link: $LEGACY_DIR"
fi

echo ""
echo "✅ CLAUDE ACTIVATED"
echo "==================="
echo "Session ready. Tree will be appended throughout the day."
echo "Use 'bye' when ending work to create tomorrow's prompt."
echo "============================"