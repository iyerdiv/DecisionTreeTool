#!/bin/bash
# Smart Project Activation Script
# Detects project from command name (activate_ProjectName)

# Get the command that was used to call this script
COMMAND_NAME=$(basename "$0")

# Extract project name from command
# activate_OpsBrain -> OpsBrain
# activate_MyProject -> MyProject
# activate_claude -> OpsBrain (default)
if [[ "$COMMAND_NAME" =~ activate_(.+) ]]; then
    PROJECT="${BASH_REMATCH[1]}"

    # Handle special cases
    if [ "$PROJECT" = "claude" ]; then
        PROJECT="OpsBrain"  # Default claude activation goes to OpsBrain
    fi
else
    # Fallback to parameter or default
    PROJECT="${1:-OpsBrain}"
fi

# Normalize project name (handle case variations)
PROJECT_LOWER=$(echo "$PROJECT" | tr '[:upper:]' '[:lower:]')
case "$PROJECT_LOWER" in
    opsbrain|brain|ops)
        PROJECT="OpsBrain"
        PROJECT_DESC="Perfect Mile Sci Ops Brain"
        ;;
    decisiontree|tree|dt)
        PROJECT="DecisionTree"
        PROJECT_DESC="Decision Tree Development"
        ;;
    claude|ai|assistant)
        PROJECT="OpsBrain"
        PROJECT_DESC="Claude AI Assistant (OpsBrain)"
        ;;
    *)
        # Keep original capitalization for new projects
        PROJECT_DESC="$PROJECT Project"
        ;;
esac

echo "🚀 ACTIVATING PROJECT: $PROJECT"
echo "=================================="
echo "$PROJECT_DESC"
echo ""

# Get dates
TODAY=$(date '+%Y%m%d')
TODAY_FULL=$(date '+%Y-%m-%d')
YESTERDAY=$(date -v-1d '+%Y%m%d')
NOW=$(date '+%H:%M:%S')

# Set directories
TOOL_DIR="/Volumes/workplace/DecisionTreeTool"
PROJECT_DIR="$TOOL_DIR/$PROJECT"

# Create project structure if new
if [ ! -d "$PROJECT_DIR" ]; then
    echo "🆕 Creating new project: $PROJECT"
    mkdir -p "$PROJECT_DIR/trees"
    mkdir -p "$PROJECT_DIR/prompts"
    mkdir -p "$PROJECT_DIR/insights"
    mkdir -p "$PROJECT_DIR/docs"

    # Create project README
    cat > "$PROJECT_DIR/README.md" << EOF
# $PROJECT Project

## Created: $TODAY_FULL
## Description: $PROJECT_DESC

### Directory Structure
- \`trees/\` - Decision trees
- \`prompts/\` - Session prompts
- \`insights/\` - Key insights and summaries
- \`docs/\` - Project documentation

### Usage
Activate with: \`activate_$PROJECT\`
End session with: \`bye_$PROJECT\`
EOF

    echo "✓ Project structure created"
    echo ""
fi

# Version tracking
VERSION_FILE="$PROJECT_DIR/.version"
GLOBAL_VERSION_FILE="$TOOL_DIR/.global_version"

# Get project version
if [ -f "$VERSION_FILE" ]; then
    PROJECT_VERSION=$(cat "$VERSION_FILE")
else
    PROJECT_VERSION=1
    echo "$PROJECT_VERSION" > "$VERSION_FILE"
fi

# Get global version
if [ -f "$GLOBAL_VERSION_FILE" ]; then
    GLOBAL_VERSION=$(cat "$GLOBAL_VERSION_FILE")
else
    # Count all existing trees
    GLOBAL_VERSION=$(find "$TOOL_DIR" -name "decision_tree*.md" 2>/dev/null | wc -l | tr -d ' ')
    if [ "$GLOBAL_VERSION" -eq 0 ]; then
        GLOBAL_VERSION=1
    fi
    echo "$GLOBAL_VERSION" > "$GLOBAL_VERSION_FILE"
fi

echo "📊 Version Management"
echo "--------------------"
echo "Project Version: V$PROJECT_VERSION"
echo "Global Version: V$GLOBAL_VERSION"
echo ""

# Today's tree file
TODAY_TREE="$PROJECT_DIR/trees/decision_tree_${TODAY}.md"

# Check if today's tree exists
if [ -f "$TODAY_TREE" ]; then
    echo "✓ Continuing today's tree"

    # Add session marker
    echo "" >> "$TODAY_TREE"
    echo "---" >> "$TODAY_TREE"
    echo "## Session Resumed: $(date '+%Y-%m-%d %H:%M:%S')" >> "$TODAY_TREE"
    echo "### Command: activate_$PROJECT" >> "$TODAY_TREE"
    echo "" >> "$TODAY_TREE"
else
    echo "📝 Creating new daily tree"

    # Find yesterday's tree
    YESTERDAY_TREE="$PROJECT_DIR/trees/decision_tree_${YESTERDAY}.md"
    if [ ! -f "$YESTERDAY_TREE" ]; then
        YESTERDAY_TREE=$(ls -t "$PROJECT_DIR/trees/"decision_tree_*.md 2>/dev/null | head -1)
    fi

    # Increment versions
    PROJECT_VERSION=$((PROJECT_VERSION + 1))
    GLOBAL_VERSION=$((GLOBAL_VERSION + 1))
    echo "$PROJECT_VERSION" > "$VERSION_FILE"
    echo "$GLOBAL_VERSION" > "$GLOBAL_VERSION_FILE"

    # Create tree header
    cat > "$TODAY_TREE" << EOF
# Decision Tree - ${TODAY_FULL}
## Project: $PROJECT
## Description: $PROJECT_DESC
## Project Version: V$PROJECT_VERSION | Global Version: V$GLOBAL_VERSION
## Session Start: $(date '+%Y-%m-%d %H:%M:%S')

---

## Tree Chain
EOF

    # Link to previous tree
    if [ -f "$YESTERDAY_TREE" ]; then
        echo "**Previous**: [$(basename "$YESTERDAY_TREE")]($YESTERDAY_TREE)" >> "$TODAY_TREE"
        echo "" >> "$TODAY_TREE"
        echo "### Context from Previous Session" >> "$TODAY_TREE"

        # Extract TODOs
        TODOS=$(grep "TODO:" "$YESTERDAY_TREE" 2>/dev/null | tail -3)
        if [ -n "$TODOS" ]; then
            echo "#### Outstanding TODOs:" >> "$TODAY_TREE"
            echo "$TODOS" | while IFS= read -r line; do
                echo "- $line" >> "$TODAY_TREE"
            done
        fi
    else
        echo "**Previous**: None (First tree for this project)" >> "$TODAY_TREE"
    fi

    cat >> "$TODAY_TREE" << EOF

---

## Session Log

### Node 1 - Initialization [$NOW]
- **Status**: Project activated
- **Context**: $PROJECT_DESC
- **Ready**: Awaiting objectives

EOF

    echo "✓ Created: decision_tree_${TODAY}.md"
fi

# Load previous insights and prompts
echo ""
echo "📖 Loading context..."

LATEST_PROMPT=$(ls -t "$PROJECT_DIR/prompts/"*.md 2>/dev/null | head -1)
if [ -f "$LATEST_PROMPT" ]; then
    echo "✓ Prompt: $(basename "$LATEST_PROMPT")"
fi

LATEST_INSIGHTS=$(ls -t "$PROJECT_DIR/insights/"*.md 2>/dev/null | head -1)
if [ -f "$LATEST_INSIGHTS" ]; then
    echo "✓ Insights: $(basename "$LATEST_INSIGHTS")"
    echo ""
    echo "💡 Previous Insights:"
    head -10 "$LATEST_INSIGHTS" | sed 's/^/  /'
fi

# Set environment
export CURRENT_PROJECT="$PROJECT"
export CURRENT_PROJECT_DIR="$PROJECT_DIR"
export CURRENT_TREE="$TODAY_TREE"

# Create context file
cat > "$PROJECT_DIR/.context" << EOF
PROJECT=$PROJECT
PROJECT_DESC=$PROJECT_DESC
PROJECT_DIR=$PROJECT_DIR
TODAY_TREE=$TODAY_TREE
PROJECT_VERSION=$PROJECT_VERSION
GLOBAL_VERSION=$GLOBAL_VERSION
ACTIVATED=$(date '+%Y-%m-%d %H:%M:%S')
EOF

# Create bye command for this project
BYE_SCRIPT="/Volumes/workplace/bye_$PROJECT"
cat > "$BYE_SCRIPT" << EOF
#!/bin/bash
# Auto-generated bye script for $PROJECT
bash $TOOL_DIR/scripts/bye_claude_v2.sh "$PROJECT"
EOF
chmod +x "$BYE_SCRIPT"

echo ""
echo "📍 SESSION INFO"
echo "---------------"
echo "Project: $PROJECT"
echo "Location: $PROJECT_DIR"
echo "Today's Tree: decision_tree_${TODAY}.md"
echo "End Command: bye_$PROJECT"

# Special handling for OpsBrain
if [ "$PROJECT" = "OpsBrain" ]; then
    echo ""
    echo "🔗 OpsBrain Compatibility"
    # Create legacy links
    LEGACY_DIR="/Volumes/workplace/OpsBrainMemory/daily_trees"
    if [ -d "$LEGACY_DIR" ]; then
        ln -sf "$TODAY_TREE" "$LEGACY_DIR/decision_tree_${TODAY}_session.md" 2>/dev/null
        echo "✓ Legacy link created"
    fi
fi

echo ""
echo "✅ $PROJECT ACTIVATED"
echo "===================="
echo "Session ready. Tree will be appended throughout the day."
echo "Use 'bye_$PROJECT' to end session and prepare tomorrow."
echo ""