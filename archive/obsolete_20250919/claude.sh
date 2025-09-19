#!/bin/bash
# Master Claude Session Management Script
# Central control for all Claude session operations

SCRIPT_DIR="/Volumes/workplace/DecisionTreeTool/scripts"
PROJECT="${2:-OpsBrain}"  # Default to OpsBrain if not specified

case "$1" in
    start|activate)
        echo "🚀 Starting Claude session for project: $PROJECT"
        bash "$SCRIPT_DIR/activate_claude_v2.sh" "$PROJECT"
        ;;

    stop|bye|end)
        echo "👋 Ending Claude session for project: $PROJECT"
        bash "$SCRIPT_DIR/bye_claude_v2.sh" "$PROJECT"
        ;;

    save)
        echo "💾 Saving current session for project: $PROJECT"
        bash "$SCRIPT_DIR/save_session.sh" "$PROJECT"
        ;;

    sync)
        echo "☁️  Syncing decision trees to OneDrive"
        bash "$SCRIPT_DIR/sync_decision_trees_to_onedrive.sh"
        ;;

    status)
        echo "📊 CLAUDE SESSION STATUS"
        echo "========================"
        TODAY=$(date +"%Y%m%d")

        # Check for active session
        if [ -n "$CURRENT_PROJECT" ]; then
            echo "Active Project: $CURRENT_PROJECT"
        else
            echo "Active Project: None (use 'claude start [project]')"
        fi

        # Check for today's tree
        TREE_CHECK="/Volumes/workplace/DecisionTreeTool/$PROJECT/trees/decision_tree_${TODAY}_session.md"
        if [ -f "$TREE_CHECK" ]; then
            echo "Today's Tree: ✓ Active"
            echo "Location: $TREE_CHECK"
            echo "Nodes: $(grep -c "^### Node" "$TREE_CHECK" 2>/dev/null || echo "0")"
            echo "TODOs: $(grep -c "TODO:" "$TREE_CHECK" 2>/dev/null || echo "0")"
        else
            echo "Today's Tree: ✗ Not found"
        fi

        # List available projects
        echo ""
        echo "Available Projects:"
        for dir in /Volumes/workplace/DecisionTreeTool/*/; do
            if [[ -d "$dir" && ! "$dir" =~ (scripts|archive|templates) ]]; then
                echo "  - $(basename "$dir")"
            fi
        done
        ;;

    list|ls)
        echo "📂 DECISION TREE TOOL STRUCTURE"
        echo "================================"
        echo ""
        echo "Projects:"
        ls -la /Volumes/workplace/DecisionTreeTool/ | grep "^d" | grep -v "\.$" | awk '{print "  "$9}'
        echo ""
        echo "Recent Trees:"
        ls -lt /Volumes/workplace/DecisionTreeTool/*/trees/*.md 2>/dev/null | head -5 | awk '{print "  "$9}'
        echo ""
        echo "Scripts:"
        ls -1 "$SCRIPT_DIR"/*.sh | xargs -n1 basename | awk '{print "  "$1}'
        ;;

    archive)
        echo "📦 Archiving old files..."
        ARCHIVE_DIR="/Volumes/workplace/DecisionTreeTool/archive/$(date +%Y%m)"
        mkdir -p "$ARCHIVE_DIR"

        # Archive files older than 7 days
        find /Volumes/workplace/DecisionTreeTool/*/trees -name "*.md" -mtime +7 -exec mv {} "$ARCHIVE_DIR/" \; 2>/dev/null
        find /Volumes/workplace/DecisionTreeTool/*/insights -name "*.md" -mtime +7 -exec mv {} "$ARCHIVE_DIR/" \; 2>/dev/null

        echo "✓ Archived old files to: $ARCHIVE_DIR"
        ;;

    clean)
        echo "🧹 Cleaning temporary files..."
        # Remove empty directories
        find /Volumes/workplace/DecisionTreeTool -type d -empty -delete 2>/dev/null
        # Remove .DS_Store files
        find /Volumes/workplace/DecisionTreeTool -name ".DS_Store" -delete 2>/dev/null
        echo "✓ Cleanup complete"
        ;;

    help|--help|-h|*)
        echo "🤖 CLAUDE SESSION MANAGER"
        echo "========================="
        echo ""
        echo "Usage: claude [command] [project]"
        echo ""
        echo "Commands:"
        echo "  start, activate [project]  - Start a new Claude session"
        echo "  stop, bye, end [project]   - End current Claude session"
        echo "  save [project]             - Save current session"
        echo "  sync                       - Sync to OneDrive"
        echo "  status                     - Show session status"
        echo "  list, ls                   - List projects and files"
        echo "  archive                    - Archive old files"
        echo "  clean                      - Clean temporary files"
        echo "  help                       - Show this help"
        echo ""
        echo "Projects:"
        echo "  Default: OpsBrain"
        echo "  Specify any project name to create/use different project"
        echo ""
        echo "Examples:"
        echo "  claude start             # Start OpsBrain session"
        echo "  claude start MyProject   # Start MyProject session"
        echo "  claude bye              # End current session"
        echo "  claude status           # Check current status"
        ;;
esac