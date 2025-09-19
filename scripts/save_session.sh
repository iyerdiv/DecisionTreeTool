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
