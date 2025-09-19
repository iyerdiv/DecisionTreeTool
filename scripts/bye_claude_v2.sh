#!/bin/bash
# bye_claude.sh V2 - Session wrap-up script with project support
# Automatically updates decision tree and creates tomorrow's prompt

# Get project from parameter or environment
PROJECT="${1:-${CURRENT_PROJECT:-OpsBrain}}"

echo "👋 CLOSING CLAUDE SESSION"
echo "=========================="
echo "Project: $PROJECT"
echo ""

# Get dates
TODAY=$(date +"%Y%m%d")
TOMORROW=$(date -v+1d +"%Y%m%d")

# Set directories
TOOL_DIR="/Volumes/workplace/DecisionTreeTool"
PROJECT_DIR="$TOOL_DIR/$PROJECT"

# Ensure directories exist
mkdir -p "$PROJECT_DIR/trees"
mkdir -p "$PROJECT_DIR/prompts"
mkdir -p "$PROJECT_DIR/insights"

# File paths
DECISION_TREE="$PROJECT_DIR/trees/decision_tree_${TODAY}_session.md"
NEXT_PROMPT="$PROJECT_DIR/prompts/NEXT_CLAUDE_PROMPT_${TOMORROW}.md"
KEY_INSIGHTS="$PROJECT_DIR/insights/KEY_INSIGHTS_${TODAY}.md"

# Logic hole fix #1: Check if tree exists in multiple possible locations
if [ ! -f "$DECISION_TREE" ]; then
    # Check OpsBrain legacy location
    if [ "$PROJECT" = "OpsBrain" ]; then
        ALT_TREE="/Volumes/workplace/OpsBrainMemory/daily_trees/decision_tree_${TODAY}_session.md"
        if [ -f "$ALT_TREE" ]; then
            DECISION_TREE="$ALT_TREE"
            echo "   📍 Using legacy tree location"
        fi
    fi

    # Check current directory
    if [ ! -f "$DECISION_TREE" ]; then
        LOCAL_TREE="decision_tree_${TODAY}_session.md"
        if [ -f "$LOCAL_TREE" ]; then
            DECISION_TREE="$LOCAL_TREE"
            echo "   📍 Using local tree"
        fi
    fi
fi

# Update decision tree with session summary
echo "📝 Updating today's decision tree..."
if [ -f "$DECISION_TREE" ]; then
    # Append session end marker
    echo "" >> "$DECISION_TREE"
    echo "---" >> "$DECISION_TREE"
    echo "## Session End: $(date +"%Y-%m-%d %H:%M:%S")" >> "$DECISION_TREE"
    echo "Session completed. Ready for next activation." >> "$DECISION_TREE"
    echo "   ✓ Updated: $(basename $DECISION_TREE)"

    # Copy to project directory if it was found elsewhere
    if [[ "$DECISION_TREE" != "$PROJECT_DIR/trees/"* ]]; then
        cp "$DECISION_TREE" "$PROJECT_DIR/trees/"
        echo "   ✓ Copied to project directory"
    fi
else
    echo "   ⚠️  Decision tree not found for today"
    echo "   Creating minimal tree for documentation..."

    # Create minimal tree
    cat > "$PROJECT_DIR/trees/decision_tree_${TODAY}_session.md" << EOF
# Decision Tree - $(date +"%Y-%m-%d")
## Project: $PROJECT
## Session End: $(date +"%Y-%m-%d %H:%M:%S")

No session tree was active. Created for continuity.
EOF
    DECISION_TREE="$PROJECT_DIR/trees/decision_tree_${TODAY}_session.md"
fi

# Extract key insights from today's work
echo ""
echo "🔍 Extracting key insights..."
if [ -f "$DECISION_TREE" ]; then
    # Create key insights file
    cat > "$KEY_INSIGHTS" << EOF
# Key Insights - $(date +"%Y-%m-%d")
## Project: $PROJECT

## Session Summary
- Session Date: $(date +"%Y-%m-%d")
- Working Directory: $(pwd)
- Decision Tree: $(basename $DECISION_TREE)

## Important Decisions
EOF

    # Extract key markers with better formatting
    MARKERS=$(grep -E "(Decision:|Important:|TODO:|NEXT:|KEY:|CRITICAL:)" "$DECISION_TREE" 2>/dev/null)
    if [ -n "$MARKERS" ]; then
        echo "$MARKERS" | while IFS= read -r line; do
            echo "- $line" >> "$KEY_INSIGHTS"
        done
    else
        echo "- No specific decisions marked" >> "$KEY_INSIGHTS"
    fi

    # Add session statistics
    echo "" >> "$KEY_INSIGHTS"
    echo "## Session Statistics" >> "$KEY_INSIGHTS"
    echo "- Total nodes: $(grep -c "^### Node" "$DECISION_TREE" 2>/dev/null || echo "0")" >> "$KEY_INSIGHTS"
    echo "- TODOs: $(grep -c "TODO:" "$DECISION_TREE" 2>/dev/null || echo "0")" >> "$KEY_INSIGHTS"

    echo "   ✓ Created: $(basename $KEY_INSIGHTS)"
fi

# Create tomorrow's prompt with better context
echo ""
echo "📅 Creating tomorrow's prompt..."
cat > "$NEXT_PROMPT" << EOF
# Claude Session Prompt
## Date: $(date -v+1d +"%Y-%m-%d")
## Project: $PROJECT

### Previous Session Context
- Last session: $(date +"%Y-%m-%d")
- Decision tree: $(basename $DECISION_TREE)
- Key insights: $(basename $KEY_INSIGHTS)
- Project directory: $PROJECT_DIR

### Session Objectives
1. Review previous decision tree
2. Continue work on outstanding tasks
3. Address any TODOs from previous session

### Outstanding Items
EOF

# Add TODOs if any exist
if [ -f "$DECISION_TREE" ]; then
    TODOS=$(grep "TODO:" "$DECISION_TREE" 2>/dev/null)
    if [ -n "$TODOS" ]; then
        echo "$TODOS" | while IFS= read -r line; do
            echo "- $line" >> "$NEXT_PROMPT"
        done
    else
        echo "- No outstanding TODOs" >> "$NEXT_PROMPT"
    fi
fi

cat >> "$NEXT_PROMPT" << EOF

### Context to Load
Please load and review:
- Previous decision tree: \`$PROJECT_DIR/trees/$(basename $DECISION_TREE)\`
- Key insights: \`$PROJECT_DIR/insights/$(basename $KEY_INSIGHTS)\`
- Any relevant project files mentioned in previous session

### Initial Actions
1. Run \`cd /Volumes/workplace/DecisionTreeTool/scripts && ./activate_claude_v2.sh $PROJECT\`
2. Review previous work and decisions
3. Continue with planned tasks

### Remember
- Update decision tree throughout session
- Document important decisions with markers (Decision:, Important:, TODO:, KEY:)
- Run \`./bye_claude_v2.sh $PROJECT\` at session end

### Project Notes
- Working directory: /Volumes/workplace
- Tool directory: /Volumes/workplace/DecisionTreeTool
- Project: $PROJECT
EOF

echo "   ✓ Created: $(basename $NEXT_PROMPT)"

# Save session (if save_session.sh exists)
SAVE_SCRIPT="$TOOL_DIR/scripts/save_session.sh"
if [ -f "$SAVE_SCRIPT" ]; then
    echo ""
    echo "💾 Running save_session.sh..."
    bash "$SAVE_SCRIPT" "$PROJECT"
fi

# Archive today's files
echo ""
echo "📦 Archiving session files..."
ARCHIVE_DIR="$TOOL_DIR/archive/$(date +%Y%m)"
mkdir -p "$ARCHIVE_DIR"

# Copy files to archive with timestamp
if [ -f "$DECISION_TREE" ]; then
    cp "$DECISION_TREE" "$ARCHIVE_DIR/"
    echo "   ✓ Archived decision tree"
fi
if [ -f "$KEY_INSIGHTS" ]; then
    cp "$KEY_INSIGHTS" "$ARCHIVE_DIR/"
    echo "   ✓ Archived insights"
fi

# For OpsBrain, sync to legacy location
if [ "$PROJECT" = "OpsBrain" ]; then
    LEGACY_DIR="/Volumes/workplace/OpsBrainMemory/daily_trees"
    if [ -f "$DECISION_TREE" ]; then
        cp "$DECISION_TREE" "$LEGACY_DIR/"
        echo "   ✓ Synced to OpsBrainMemory"
    fi
fi

echo ""
echo "✅ SESSION WRAP-UP COMPLETE"
echo "=========================="
echo ""
echo "📋 Summary:"
echo "   • Project: $PROJECT"
echo "   • Decision tree: $(basename $DECISION_TREE)"
echo "   • Key insights: $(basename $KEY_INSIGHTS)"
echo "   • Tomorrow's prompt: $(basename $NEXT_PROMPT)"
echo "   • Files archived: $ARCHIVE_DIR"
echo ""
echo "👋 Goodbye! See you tomorrow!"
echo "   Next session: ./activate_claude_v2.sh $PROJECT"