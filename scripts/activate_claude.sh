#!/bin/bash
# Claude Daily Session Activation Script
# Loads previous context and creates new daily decision tree

echo "🧠 ACTIVATING CLAUDE SESSION"
echo "============================"
echo ""

# Get dates
TODAY=$(date '+%Y%m%d')
TODAY_FULL=$(date '+%Y-%m-%d')
NOW=$(date '+%H%M%S')

# Create directories
MEMORY_DIR="/Volumes/workplace/OpsBrainMemory"
mkdir -p "$MEMORY_DIR/daily_trees"
mkdir -p "$MEMORY_DIR/session_context"

# Step 1: Load previous session context (silently)
echo "📖 Loading previous session context..."

# Find yesterday's decision tree
PREV_TREE=$(ls -t $MEMORY_DIR/daily_trees/*.md 2>/dev/null | head -1)
if [ -f "$PREV_TREE" ]; then
    echo "   ✓ Loaded: $(basename $PREV_TREE)"
else
    # Fallback to latest tree in main directories
    PREV_TREE=$(ls -t /Volumes/workplace/OpsBrainDecisionTrees/decision_tree_*.md 2>/dev/null | head -1)
    if [ -f "$PREV_TREE" ]; then
        echo "   ✓ Loaded: $(basename $PREV_TREE)"
    fi
fi

# Load latest prompt
LATEST_PROMPT=$(ls -t /Volumes/workplace/NEXT_CLAUDE_PROMPT*.md 2>/dev/null | head -1)
if [ -f "$LATEST_PROMPT" ]; then
    echo "   ✓ Loaded: $(basename $LATEST_PROMPT)"
fi

# Load latest insights
LATEST_INSIGHTS=$(ls -t /Volumes/workplace/KEY_INSIGHTS*.md 2>/dev/null | head -1)
if [ -f "$LATEST_INSIGHTS" ]; then
    echo "   ✓ Loaded: $(basename $LATEST_INSIGHTS)"
fi

echo ""

# Step 2: Create NEW daily decision tree
echo "🌳 Creating today's decision tree..."

TODAY_TREE="$MEMORY_DIR/daily_trees/decision_tree_${TODAY}_session.md"

# Initialize today's tree with context from previous session
cat > "$TODAY_TREE" << EOF
# Decision Tree - ${TODAY_FULL}
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

# Add key discovery if exists
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

echo "   ✓ Created: $(basename $TODAY_TREE)"
echo ""

# Step 3: Create session end save script
SAVE_SCRIPT="/Volumes/workplace/save_session.sh"
cat > "$SAVE_SCRIPT" << 'SAVE_EOF'
#!/bin/bash
# Save current session's decision tree

TODAY=$(date '+%Y%m%d')
TODAY_TREE="/Volumes/workplace/OpsBrainMemory/daily_trees/decision_tree_${TODAY}_session.md"

if [ -f "$TODAY_TREE" ]; then
    # Add session end timestamp
    echo "" >> "$TODAY_TREE"
    echo "---" >> "$TODAY_TREE"
    echo "## Session End: $(date '+%Y-%m-%d %H:%M:%S')" >> "$TODAY_TREE"

    # Create final version
    FINAL_TREE="/Volumes/workplace/OpsBrainMemory/daily_trees/decision_tree_${TODAY}_final.md"
    cp "$TODAY_TREE" "$FINAL_TREE"

    echo "✅ Session saved to: $(basename $FINAL_TREE)"

    # Optional: Create summary for next session
    SUMMARY="/Volumes/workplace/OpsBrainMemory/session_context/summary_${TODAY}.md"
    echo "# Session Summary - $(date '+%Y-%m-%d')" > "$SUMMARY"
    echo "" >> "$SUMMARY"
    tail -50 "$TODAY_TREE" >> "$SUMMARY"

    echo "📋 Summary created for next session"
else
    echo "⚠️  No session tree found for today"
fi
SAVE_EOF

chmod +x "$SAVE_SCRIPT"

echo "💾 Session Management"
echo "--------------------"
echo "Today's tree: $(basename $TODAY_TREE)"
echo "To save session: ./save_session.sh"
echo ""

# Step 4: Display Key Insights
echo "💡 KEY INSIGHTS"
echo "---------------"
if [ -f "$LATEST_INSIGHTS" ]; then
    cat "$LATEST_INSIGHTS"
else
    echo "No key insights file found."
fi
echo ""

# Step 5: Show Context Info
echo "📍 CONTEXT INFORMATION"
echo "----------------------"
echo "Working Directory: /Volumes/workplace"
echo "Project: PerfectMileSciOpsBrain"
echo "Activation Time: $(date '+%Y-%m-%d %H:%M:%S')"
echo "Previous Tree: $(basename $PREV_TREE 2>/dev/null || echo 'None')"
echo "Today's Tree: $(basename $TODAY_TREE)"
echo ""

# Step 6: Show ready status
echo "✅ CLAUDE ACTIVATED"
echo "==================="
echo "Mode: Daily Decision Tree"
echo "Previous context: Loaded"
echo "Today's tree: Created"
echo "Key insights: Displayed"
echo ""

# Create context file for Claude to read
CONTEXT_FILE="/Volumes/workplace/.claude_context"
cat > "$CONTEXT_FILE" << EOF
CONTEXT_LOADED: ${TODAY_FULL}
PREVIOUS_TREE: $PREV_TREE
TODAY_TREE: $TODAY_TREE
LATEST_PROMPT: $LATEST_PROMPT
LATEST_INSIGHTS: $LATEST_INSIGHTS
WORKING_DIR: /Volumes/workplace
PROJECT: PerfectMileSciOpsBrain
EOF

echo "Ready for work. Remember to run './save_session.sh' at session end."
echo "============================"