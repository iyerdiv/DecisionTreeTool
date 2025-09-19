#!/bin/bash
# Sync Decision Trees to OneDrive
# Created: 2025-09-15

# Define paths
SOURCE_DIR="/Volumes/workplace/OpsBrainDecisionTrees"
ONEDRIVE_DIR="$HOME/OneDrive - amazon.com/OpsBrainDecisionTrees"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔄 Starting Decision Tree Sync to OneDrive...${NC}"

# Create OneDrive directory if not exists
mkdir -p "$ONEDRIVE_DIR"

# Sync all markdown files from consolidated directory
echo -e "${BLUE}Syncing all decision trees and documentation...${NC}"

# Use rsync for efficient sync
rsync -av --delete "$SOURCE_DIR/" "$ONEDRIVE_DIR/" --include="*.md" --include="*/" --exclude="*"

# Count synced files
count=$(ls -1 "$ONEDRIVE_DIR"/*.md 2>/dev/null | wc -l)

# Summary
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ Sync complete!${NC}"
echo -e "📁 Files available in: $ONEDRIVE_DIR"
echo -e "🌐 Access via: https://amazon-my.sharepoint.com"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# List files in OneDrive folder
echo -e "\n${BLUE}Files in OneDrive:${NC}"
ls -la "$ONEDRIVE_DIR" | grep ".md" | awk '{print "  📄 " $NF}'