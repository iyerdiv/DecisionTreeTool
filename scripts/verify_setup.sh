#!/bin/bash
# Verification script to check and fix all dependencies

echo "🔍 DECISION TREE TOOL VERIFICATION"
echo "==================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Base directories
TOOL_DIR="/Volumes/workplace/DecisionTreeTool"
WORKSPACE="/Volumes/workplace"
PROJECT="OpsBrain"

# Check function
check_item() {
    local item="$1"
    local path="$2"
    local required="$3"

    if [ -e "$path" ]; then
        echo -e "${GREEN}✓${NC} $item: Found"
        return 0
    else
        if [ "$required" = "required" ]; then
            echo -e "${RED}✗${NC} $item: Missing (REQUIRED)"
        else
            echo -e "${YELLOW}⚠${NC} $item: Missing (optional)"
        fi
        return 1
    fi
}

# Fix function
fix_item() {
    local item="$1"
    local path="$2"
    local action="$3"

    echo "  Fixing: $item"
    eval "$action"
    if [ $? -eq 0 ]; then
        echo -e "  ${GREEN}✓${NC} Fixed"
    else
        echo -e "  ${RED}✗${NC} Failed to fix"
    fi
}

echo "📁 DIRECTORY STRUCTURE"
echo "----------------------"

# Check main directories
check_item "DecisionTreeTool" "$TOOL_DIR" "required"
check_item "Scripts directory" "$TOOL_DIR/scripts" "required"
check_item "OpsBrain project" "$TOOL_DIR/OpsBrain" "optional"
check_item "Archive directory" "$TOOL_DIR/archive" "optional"
check_item "Templates directory" "$TOOL_DIR/templates" "optional"

# Create missing directories
if [ ! -d "$TOOL_DIR/OpsBrain/trees" ]; then
    fix_item "OpsBrain tree directory" "$TOOL_DIR/OpsBrain/trees" "mkdir -p $TOOL_DIR/OpsBrain/trees"
fi
if [ ! -d "$TOOL_DIR/OpsBrain/prompts" ]; then
    fix_item "OpsBrain prompts directory" "$TOOL_DIR/OpsBrain/prompts" "mkdir -p $TOOL_DIR/OpsBrain/prompts"
fi
if [ ! -d "$TOOL_DIR/OpsBrain/insights" ]; then
    fix_item "OpsBrain insights directory" "$TOOL_DIR/OpsBrain/insights" "mkdir -p $TOOL_DIR/OpsBrain/insights"
fi

echo ""
echo "📜 SCRIPT FILES"
echo "---------------"

# Check scripts
SCRIPTS=(
    "activate_claude.sh"
    "activate_claude_v2.sh"
    "activate_claude_v3.sh"
    "bye_claude.sh"
    "bye_claude_v2.sh"
    "save_session.sh"
    "sync_decision_trees_to_onedrive.sh"
    "migrate_trees.sh"
    "verify_setup.sh"
)

for script in "${SCRIPTS[@]}"; do
    check_item "$script" "$TOOL_DIR/scripts/$script" "optional"
done

# Check master script
check_item "Master claude.sh" "$TOOL_DIR/claude.sh" "required"
if [ ! -f "$TOOL_DIR/claude.sh" ]; then
    fix_item "Master claude.sh" "$TOOL_DIR/claude.sh" "cp $TOOL_DIR/scripts/claude.sh $TOOL_DIR/ 2>/dev/null || echo '#!/bin/bash' > $TOOL_DIR/claude.sh"
fi

echo ""
echo "🌳 CURRENT TREES"
echo "----------------"

# Find today's tree
TODAY=$(date '+%Y%m%d')
TODAY_TREE="$TOOL_DIR/OpsBrain/trees/decision_tree_${TODAY}.md"

if [ -f "$TODAY_TREE" ]; then
    echo -e "${GREEN}✓${NC} Today's tree exists: $(basename $TODAY_TREE)"
else
    # Check alternative locations
    ALT_LOCATIONS=(
        "/Volumes/workplace/OpsBrainMemory/daily_trees/decision_tree_${TODAY}_session.md"
        "/Volumes/workplace/decision_tree_${TODAY}_V*.md"
        "/Volumes/workplace/OpsBrainDecisionTrees/decision_tree_${TODAY}*.md"
    )

    FOUND=false
    for loc in "${ALT_LOCATIONS[@]}"; do
        for file in $loc; do
            if [ -f "$file" ]; then
                echo -e "${YELLOW}⚠${NC} Found tree in alternative location: $file"
                FOUND=true

                # Copy to correct location
                read -p "Copy to standard location? (y/n) " -n 1 -r
                echo ""
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    cp "$file" "$TODAY_TREE"
                    echo -e "${GREEN}✓${NC} Copied to: $TODAY_TREE"
                fi
                break
            fi
        done
        if [ "$FOUND" = true ]; then break; fi
    done

    if [ "$FOUND" = false ]; then
        echo -e "${YELLOW}⚠${NC} No tree found for today"
    fi
fi

echo ""
echo "📊 VERSION TRACKING"
echo "-------------------"

VERSION_FILE="$TOOL_DIR/OpsBrain/.version"
if [ -f "$VERSION_FILE" ]; then
    CURRENT_VERSION=$(cat "$VERSION_FILE")
    echo -e "${GREEN}✓${NC} Current version: V$CURRENT_VERSION"
else
    # Count existing trees to determine version
    echo -e "${YELLOW}⚠${NC} Version file missing, analyzing trees..."

    # Look for highest version number
    HIGHEST=0
    for tree in $(find /Volumes/workplace -name "*V[0-9]*.md" 2>/dev/null); do
        if [[ $tree =~ V([0-9]+) ]]; then
            VERSION="${BASH_REMATCH[1]}"
            if [ "$VERSION" -gt "$HIGHEST" ]; then
                HIGHEST="$VERSION"
            fi
        fi
    done

    if [ "$HIGHEST" -gt 0 ]; then
        echo "$HIGHEST" > "$VERSION_FILE"
        echo -e "${GREEN}✓${NC} Set version to V$HIGHEST based on existing trees"
    else
        echo "1" > "$VERSION_FILE"
        echo -e "${GREEN}✓${NC} Starting fresh at V1"
    fi
fi

echo ""
echo "🔗 CURRENT SESSION"
echo "------------------"

# Check for active context
CONTEXT_FILE="$TOOL_DIR/OpsBrain/.claude_context"
if [ -f "$CONTEXT_FILE" ]; then
    echo -e "${GREEN}✓${NC} Active context file found"
    echo "Contents:"
    cat "$CONTEXT_FILE" | sed 's/^/  /'
else
    echo -e "${YELLOW}⚠${NC} No active context file"
fi

# Check environment
if [ -n "$CURRENT_PROJECT" ]; then
    echo -e "${GREEN}✓${NC} Current project: $CURRENT_PROJECT"
else
    echo -e "${YELLOW}⚠${NC} No project set in environment"
fi

echo ""
echo "🔄 LEGACY COMPATIBILITY"
echo "-----------------------"

# Check OpsBrainMemory
LEGACY_DIR="/Volumes/workplace/OpsBrainMemory"
check_item "OpsBrainMemory directory" "$LEGACY_DIR" "optional"
check_item "OpsBrainMemory/daily_trees" "$LEGACY_DIR/daily_trees" "optional"

# Check for orphaned trees in workspace
echo ""
echo "📝 ORPHANED TREES IN WORKSPACE"
echo "------------------------------"

ORPHANED=$(find /Volumes/workplace -maxdepth 1 -name "decision_tree*.md" 2>/dev/null | wc -l | tr -d ' ')
if [ "$ORPHANED" -gt 0 ]; then
    echo -e "${YELLOW}⚠${NC} Found $ORPHANED decision trees in workspace root"

    read -p "Move to archive? (y/n) " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        ARCHIVE_DIR="$TOOL_DIR/archive/orphaned_$(date +%Y%m%d)"
        mkdir -p "$ARCHIVE_DIR"

        for tree in /Volumes/workplace/decision_tree*.md; do
            if [ -f "$tree" ]; then
                mv "$tree" "$ARCHIVE_DIR/"
                echo "  Moved: $(basename $tree)"
            fi
        done
        echo -e "${GREEN}✓${NC} Moved to: $ARCHIVE_DIR"
    fi
else
    echo -e "${GREEN}✓${NC} No orphaned trees in workspace root"
fi

echo ""
echo "🚀 QUICK START COMMANDS"
echo "-----------------------"

# Create activation shortcut
ACTIVATE_CMD="$WORKSPACE/activate_claude"
cat > "$ACTIVATE_CMD" << 'EOF'
#!/bin/bash
bash /Volumes/workplace/DecisionTreeTool/scripts/activate_claude_v3.sh OpsBrain
EOF
chmod +x "$ACTIVATE_CMD"
echo -e "${GREEN}✓${NC} Created: activate_claude (in workspace root)"

# Create bye shortcut
BYE_CMD="$WORKSPACE/bye_claude"
cat > "$BYE_CMD" << 'EOF'
#!/bin/bash
bash /Volumes/workplace/DecisionTreeTool/scripts/bye_claude_v2.sh OpsBrain
EOF
chmod +x "$BYE_CMD"
echo -e "${GREEN}✓${NC} Created: bye_claude (in workspace root)"

echo ""
echo "✅ VERIFICATION COMPLETE"
echo "========================"
echo ""
echo "Quick commands now available:"
echo "  ./activate_claude  - Start session"
echo "  ./bye_claude       - End session"
echo ""
echo "Or use the master command:"
echo "  $TOOL_DIR/claude.sh [start|stop|status]"
echo ""

# Final status
ERRORS=0
if [ ! -d "$TOOL_DIR" ]; then ((ERRORS++)); fi
if [ ! -d "$TOOL_DIR/scripts" ]; then ((ERRORS++)); fi

if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}✅ All systems operational${NC}"
else
    echo -e "${RED}⚠️  $ERRORS critical issues found${NC}"
fi