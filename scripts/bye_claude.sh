#!/bin/bash

# bye_claude.sh - Session wrap-up script
# Automatically updates decision tree and creates tomorrow's prompt

echo "👋 CLOSING CLAUDE SESSION"
echo "=========================="
echo ""

# Get today's date
TODAY=$(date +"%Y%m%d")
TOMORROW=$(date -v+1d +"%Y%m%d")

# File paths - match activate_claude.sh structure
MEMORY_DIR="/Volumes/workplace/OpsBrainMemory"
DECISION_TREE="${MEMORY_DIR}/daily_trees/decision_tree_${TODAY}_session.md"
NEXT_PROMPT="NEXT_CLAUDE_PROMPT_${TOMORROW}.md"
KEY_INSIGHTS="KEY_INSIGHTS_${TODAY}.md"

# Update decision tree with session summary
echo "📝 Updating today's decision tree..."
if [ -f "$DECISION_TREE" ]; then
    # Append session end marker
    echo "" >> "$DECISION_TREE"
    echo "---" >> "$DECISION_TREE"
    echo "## Session End: $(date +"%Y-%m-%d %H:%M:%S")" >> "$DECISION_TREE"
    echo "Session completed. Ready for next activation." >> "$DECISION_TREE"
    echo "   ✓ Updated: $DECISION_TREE"
else
    echo "   ⚠️  Decision tree not found: $DECISION_TREE"
fi

# Extract key insights from today's work
echo ""
echo "🔍 Extracting key insights..."
if [ -f "$DECISION_TREE" ]; then
    # Create key insights file
    echo "# Key Insights - $(date +"%Y-%m-%d")" > "$KEY_INSIGHTS"
    echo "" >> "$KEY_INSIGHTS"
    echo "## Session Summary" >> "$KEY_INSIGHTS"
    echo "- Session Date: $(date +"%Y-%m-%d")" >> "$KEY_INSIGHTS"
    echo "- Working Directory: $(pwd)" >> "$KEY_INSIGHTS"
    echo "" >> "$KEY_INSIGHTS"
    echo "## Important Decisions" >> "$KEY_INSIGHTS"
    # Extract any lines with "Decision:", "Important:", or "TODO:"
    grep -E "(Decision:|Important:|TODO:|NEXT:)" "$DECISION_TREE" >> "$KEY_INSIGHTS" 2>/dev/null || echo "- No specific decisions marked" >> "$KEY_INSIGHTS"
    echo "   ✓ Created: $KEY_INSIGHTS"
fi

# Create tomorrow's prompt
echo ""
echo "📅 Creating tomorrow's prompt..."
cat > "$NEXT_PROMPT" << 'EOF'
# Claude Session Prompt
## Date: TOMORROW_DATE

### Previous Session Context
- Last session: TODAY_DATE
- Decision tree: DECISION_TREE_FILE
- Key insights: KEY_INSIGHTS_FILE

### Session Objectives
1. Review previous decision tree
2. Continue work on outstanding tasks
3. Address any TODOs from previous session

### Context to Load
Please load and review:
- Previous decision tree: `DECISION_TREE_FILE`
- Key insights: `KEY_INSIGHTS_FILE`
- Any relevant project files mentioned in previous session

### Initial Actions
1. Run `./activate_claude.sh` to set up session
2. Review previous work and decisions
3. Continue with planned tasks

### Remember
- Update decision tree throughout session
- Document important decisions
- Run `./bye_claude.sh` at session end
EOF

# Replace placeholders
sed -i '' "s/TOMORROW_DATE/$(date -v+1d +"%Y-%m-%d")/g" "$NEXT_PROMPT"
sed -i '' "s/TODAY_DATE/$(date +"%Y-%m-%d")/g" "$NEXT_PROMPT"
sed -i '' "s|DECISION_TREE_FILE|$(basename $DECISION_TREE)|g" "$NEXT_PROMPT"
sed -i '' "s/KEY_INSIGHTS_FILE/$KEY_INSIGHTS/g" "$NEXT_PROMPT"

echo "   ✓ Created: $NEXT_PROMPT"

# Save session (if save_session.sh exists)
if [ -f "./save_session.sh" ]; then
    echo ""
    echo "💾 Running save_session.sh..."
    ./save_session.sh
fi

echo ""
echo "✅ SESSION WRAP-UP COMPLETE"
echo "=========================="
echo ""
echo "📋 Summary:"
echo "   • Decision tree updated: $(basename $DECISION_TREE)"
echo "   • Key insights saved: $KEY_INSIGHTS"
echo "   • Tomorrow's prompt: $NEXT_PROMPT"
echo ""
echo "👋 Goodbye! See you tomorrow!"
echo "   Next session: Run './activate_claude.sh' to start"