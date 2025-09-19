#!/bin/bash
# Claude Daily Session Activation Script V2
# Supports multiple projects with centralized management

# Check for project parameter
PROJECT="${1:-OpsBrain}"  # Default to OpsBrain if not specified

echo "🧠 ACTIVATING CLAUDE SESSION"
echo "============================"
echo "Project: $PROJECT"
echo ""

# Get dates
TODAY=$(date '+%Y%m%d')
TODAY_FULL=$(date '+%Y-%m-%d')
NOW=$(date '+%H%M%S')

# Set directories based on project
TOOL_DIR="/Volumes/workplace/DecisionTreeTool"
PROJECT_DIR="$TOOL_DIR/$PROJECT"
mkdir -p "$PROJECT_DIR/trees"
mkdir -p "$PROJECT_DIR/prompts"
mkdir -p "$PROJECT_DIR/insights"

# OpsBrain also saves to legacy location for compatibility
if [ "$PROJECT" = "OpsBrain" ]; then
    LEGACY_DIR="/Volumes/workplace/OpsBrainMemory"
    mkdir -p "$LEGACY_DIR/daily_trees"
    mkdir -p "$LEGACY_DIR/session_context"
fi

# Step 1: Load previous session context
echo "📖 Loading previous session context..."

# Find yesterday's decision tree
PREV_TREE=$(ls -t $PROJECT_DIR/trees/*.md 2>/dev/null | head -1)
if [ -f "$PREV_TREE" ]; then
    echo "   ✓ Loaded: $(basename $PREV_TREE)"
else
    # For OpsBrain, check legacy locations too
    if [ "$PROJECT" = "OpsBrain" ]; then
        PREV_TREE=$(ls -t $LEGACY_DIR/daily_trees/*.md 2>/dev/null | head -1)
        if [ -f "$PREV_TREE" ]; then
            echo "   ✓ Loaded: $(basename $PREV_TREE) (legacy)"
        fi
    fi
fi

# Load latest prompt
LATEST_PROMPT=$(ls -t $PROJECT_DIR/prompts/NEXT_CLAUDE_PROMPT*.md 2>/dev/null | head -1)
if [ -f "$LATEST_PROMPT" ]; then
    echo "   ✓ Loaded: $(basename $LATEST_PROMPT)"
fi

# Load latest insights
LATEST_INSIGHTS=$(ls -t $PROJECT_DIR/insights/KEY_INSIGHTS*.md 2>/dev/null | head -1)
if [ -f "$LATEST_INSIGHTS" ]; then
    echo "   ✓ Loaded: $(basename $LATEST_INSIGHTS)"
fi

echo ""

# Step 2: Create NEW daily decision tree
echo "🌳 Creating today's decision tree..."

TODAY_TREE="$PROJECT_DIR/trees/decision_tree_${TODAY}_session.md"

# Initialize today's tree
cat > "$TODAY_TREE" << EOF
# Decision Tree - ${TODAY_FULL}
## Project: $PROJECT
## Session Start: $(date '+%Y-%m-%d %H:%M:%S')

---

## Previous Context Loaded
EOF

# Add summary from previous tree if exists
if [ -f "$PREV_TREE" ]; then
    echo "" >> "$TODAY_TREE"
    echo "### Previous Session Summary" >> "$TODAY_TREE"
    echo "From: $(basename $PREV_TREE)" >> "$TODAY_TREE"
    echo "" >> "$TODAY_TREE"
    # Extract last node info
    grep -A 2 "Current Node:" "$PREV_TREE" | tail -3 >> "$TODAY_TREE" 2>/dev/null
    echo "" >> "$TODAY_TREE"
fi

# Add key context if exists
if [ -f "$LATEST_PROMPT" ]; then
    echo "### Key Context" >> "$TODAY_TREE"
    grep -E "^## 🚨 CRITICAL|^### The|^## KEY MESSAGES" "$LATEST_PROMPT" | head -5 >> "$TODAY_TREE" 2>/dev/null
    echo "" >> "$TODAY_TREE"
fi

echo "---" >> "$TODAY_TREE"
echo "" >> "$TODAY_TREE"
echo "## Today's Nodes" >> "$TODAY_TREE"
echo "" >> "$TODAY_TREE"
echo "### Node 1 - Session Initialize $(date +%H:%M)" >> "$TODAY_TREE"
echo "- Context loaded from previous session" >> "$TODAY_TREE"
echo "- Ready for new tasks" >> "$TODAY_TREE"
echo "" >> "$TODAY_TREE"

# Copy to legacy location for OpsBrain
if [ "$PROJECT" = "OpsBrain" ] && [ -n "$LEGACY_DIR" ]; then
    cp "$TODAY_TREE" "$LEGACY_DIR/daily_trees/"
    echo "   ✓ Created: $(basename $TODAY_TREE)"
    echo "   ✓ Legacy copy: $LEGACY_DIR/daily_trees/"
else
    echo "   ✓ Created: $(basename $TODAY_TREE)"
fi

echo ""

# Step 3: Create/update save_session script with project awareness
SAVE_SCRIPT="$TOOL_DIR/scripts/save_session.sh"
cat > "$SAVE_SCRIPT" << 'SAVE_EOF'
#!/bin/bash
# Save current session's decision tree

# Get project from parameter or environment
PROJECT="${1:-${CURRENT_PROJECT:-OpsBrain}}"
TODAY=$(date '+%Y%m%d')

TOOL_DIR="/Volumes/workplace/DecisionTreeTool"
PROJECT_DIR="$TOOL_DIR/$PROJECT"
TODAY_TREE="$PROJECT_DIR/trees/decision_tree_${TODAY}_session.md"

if [ -f "$TODAY_TREE" ]; then
    # Add session end timestamp
    echo "" >> "$TODAY_TREE"
    echo "---" >> "$TODAY_TREE"
    echo "## Session End: $(date '+%Y-%m-%d %H:%M:%S')" >> "$TODAY_TREE"

    # Create final version
    FINAL_TREE="$PROJECT_DIR/trees/decision_tree_${TODAY}_final.md"
    cp "$TODAY_TREE" "$FINAL_TREE"

    echo "✅ Session saved to: $(basename $FINAL_TREE)"

    # For OpsBrain, also save to legacy location
    if [ "$PROJECT" = "OpsBrain" ]; then
        LEGACY_DIR="/Volumes/workplace/OpsBrainMemory"
        cp "$FINAL_TREE" "$LEGACY_DIR/daily_trees/"
        echo "📦 Legacy copy saved to OpsBrainMemory"
    fi

    # Create summary for next session
    SUMMARY="$PROJECT_DIR/insights/summary_${TODAY}.md"
    echo "# Session Summary - $(date '+%Y-%m-%d')" > "$SUMMARY"
    echo "## Project: $PROJECT" >> "$SUMMARY"
    echo "" >> "$SUMMARY"
    tail -50 "$TODAY_TREE" >> "$SUMMARY"

    echo "📋 Summary created for next session"
else
    echo "⚠️  No session tree found for project: $PROJECT"
fi
SAVE_EOF

chmod +x "$SAVE_SCRIPT"

# Set environment variable for current project
export CURRENT_PROJECT="$PROJECT"

echo "💾 Session Management"
echo "--------------------"
echo "Today's tree: $(basename $TODAY_TREE)"
echo "Project location: $PROJECT_DIR"
echo "To save session: $TOOL_DIR/scripts/save_session.sh"
echo ""

# Step 4: Display Key Insights
echo "💡 KEY INSIGHTS"
echo "---------------"
if [ -f "$LATEST_INSIGHTS" ]; then
    head -20 "$LATEST_INSIGHTS"
else
    echo "No key insights file found."
fi
echo ""

# Step 5: Show Context Info
echo "📍 CONTEXT INFORMATION"
echo "----------------------"
echo "Working Directory: /Volumes/workplace"
echo "Project: $PROJECT"
echo "Project Dir: $PROJECT_DIR"
echo "Activation Time: $(date '+%Y-%m-%d %H:%M:%S')"
echo "Previous Tree: $(basename $PREV_TREE 2>/dev/null || echo 'None')"
echo "Today's Tree: $(basename $TODAY_TREE)"
echo ""

# Step 6: Show ready status
echo "✅ CLAUDE ACTIVATED"
echo "==================="
echo "Mode: Daily Decision Tree"
echo "Project: $PROJECT"
echo "Previous context: Loaded"
echo "Today's tree: Created"
echo "Key insights: Displayed"
echo ""

# Create context file for Claude to read
CONTEXT_FILE="$PROJECT_DIR/.claude_context"
cat > "$CONTEXT_FILE" << EOF
CONTEXT_LOADED: ${TODAY_FULL}
PROJECT: $PROJECT
PROJECT_DIR: $PROJECT_DIR
PREVIOUS_TREE: $PREV_TREE
TODAY_TREE: $TODAY_TREE
LATEST_PROMPT: $LATEST_PROMPT
LATEST_INSIGHTS: $LATEST_INSIGHTS
WORKING_DIR: /Volumes/workplace
EOF

echo "Ready for work. Remember to run 'bye_claude' at session end."
echo "============================"