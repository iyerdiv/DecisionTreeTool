#!/bin/bash
# Migration script to consolidate versioned trees into daily trees

echo "🔄 TREE MIGRATION TOOL"
echo "======================"
echo ""

# Find all existing decision trees
echo "📊 Analyzing existing trees..."

TOOL_DIR="/Volumes/workplace/DecisionTreeTool"
ARCHIVE_DIR="$TOOL_DIR/archive/pre_migration"
mkdir -p "$ARCHIVE_DIR"

# Count existing trees
TREE_COUNT=$(find /Volumes/workplace -name "*decision_tree*.md" 2>/dev/null | wc -l | tr -d ' ')
echo "Found $TREE_COUNT decision trees"
echo ""

# Group trees by date
echo "📅 Grouping trees by date..."

declare -A date_trees
declare -A date_versions

# Process each tree
for tree in $(find /Volumes/workplace -name "decision_tree*.md" 2>/dev/null | sort); do
    # Extract date from filename (YYYYMMDD format)
    if [[ $tree =~ decision_tree_([0-9]{8}) ]]; then
        date="${BASH_REMATCH[1]}"

        # Extract version if present
        if [[ $tree =~ V([0-9]+) ]]; then
            version="${BASH_REMATCH[1]}"
        else
            version="0"
        fi

        # Store tree path and version
        if [ -z "${date_trees[$date]}" ]; then
            date_trees[$date]="$tree"
            date_versions[$date]="$version"
        else
            # Keep the highest version for each date
            if [ "$version" -gt "${date_versions[$date]}" ]; then
                date_trees[$date]="$tree"
                date_versions[$date]="$version"
            fi
        fi
    fi
done

echo "Found trees for ${#date_trees[@]} unique dates"
echo ""

# Show migration plan
echo "📋 Migration Plan:"
echo "------------------"

for date in "${!date_trees[@]}"; do
    echo "Date: $date"
    echo "  Latest tree: $(basename ${date_trees[$date]})"
    echo "  Version: V${date_versions[$date]}"
done

echo ""
read -p "Proceed with migration? (y/n) " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Migration cancelled."
    exit 0
fi

# Perform migration
echo ""
echo "🚀 Starting migration..."

PROJECT="OpsBrain"  # Default project
PROJECT_DIR="$TOOL_DIR/$PROJECT/trees"
mkdir -p "$PROJECT_DIR"

# Create consolidated daily trees
for date in $(echo "${!date_trees[@]}" | tr ' ' '\n' | sort); do
    source_tree="${date_trees[$date]}"
    target_tree="$PROJECT_DIR/decision_tree_${date}.md"

    echo "Processing $date..."

    if [ -f "$source_tree" ]; then
        # Copy the latest version to the new structure
        cp "$source_tree" "$target_tree"

        # Add version tag to the file
        version="${date_versions[$date]}"
        sed -i '' "1s/^/<!-- Global Version: V$version -->\n/" "$target_tree" 2>/dev/null

        # Archive the original
        cp "$source_tree" "$ARCHIVE_DIR/"

        echo "  ✓ Migrated V$version to $(basename $target_tree)"
    fi
done

# Update version file with the highest version
highest_version=0
for version in "${date_versions[@]}"; do
    if [ "$version" -gt "$highest_version" ]; then
        highest_version="$version"
    fi
done

echo "$highest_version" > "$TOOL_DIR/$PROJECT/.version"
echo ""
echo "✓ Set global version to V$highest_version"

# Archive all old versioned trees
echo ""
echo "📦 Archiving old versioned trees..."

for pattern in "V*_V*.md" "*_V[0-9]*.md"; do
    for file in $(find /Volumes/workplace -name "$pattern" 2>/dev/null); do
        if [[ ! "$file" =~ "$ARCHIVE_DIR" ]]; then
            mv "$file" "$ARCHIVE_DIR/" 2>/dev/null
            echo "  Archived: $(basename $file)"
        fi
    done
done

# Create index of migrated trees
echo ""
echo "📝 Creating migration index..."

cat > "$ARCHIVE_DIR/MIGRATION_INDEX.md" << EOF
# Tree Migration Index
## Migration Date: $(date '+%Y-%m-%d %H:%M:%S')

### Summary
- Trees migrated: ${#date_trees[@]}
- Highest version: V$highest_version
- New structure: Single tree per day

### Migrated Trees
EOF

for date in $(echo "${!date_trees[@]}" | tr ' ' '\n' | sort); do
    echo "- $date: V${date_versions[$date]} -> decision_tree_${date}.md" >> "$ARCHIVE_DIR/MIGRATION_INDEX.md"
done

echo ""
echo "✅ MIGRATION COMPLETE"
echo "===================="
echo ""
echo "Results:"
echo "  • Consolidated ${#date_trees[@]} dates of trees"
echo "  • Current global version: V$highest_version"
echo "  • New location: $PROJECT_DIR"
echo "  • Archives: $ARCHIVE_DIR"
echo ""
echo "Next steps:"
echo "  1. Use 'claude start' to begin new sessions"
echo "  2. Trees will continue from V$((highest_version + 1))"
echo "  3. One tree per day going forward"