#!/bin/bash
#
# create-daily-summary.sh
# Creates a new session summary file for today's date
#

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Use current working directory as project root
PROJECT_ROOT="$(pwd)"
OUTPUT_DIR="$PROJECT_ROOT/cascade-logs"

# Get today's date in YYYY-MM-DD format
TODAY=$(date +%Y-%m-%d)
READABLE_DATE=$(date +"%B %d, %Y")  # e.g., "January 06, 2026"
START_TIME=$(date +"%I:%M %p")      # e.g., "09:38 AM"

# Date-based folder for today's documents
DATE_FOLDER="$OUTPUT_DIR/$TODAY"

# Output files
OUTPUT_FILE="$DATE_FOLDER/SESSION_SUMMARY_${TODAY}.md"
NOTES_FILE="$DATE_FOLDER/DailyNotes.md"

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Create date-based folder for today's documents
if [ ! -d "$DATE_FOLDER" ]; then
    mkdir -p "$DATE_FOLDER"
    echo -e "${GREEN}📁 Created folder: $DATE_FOLDER${NC}"
else
    echo -e "${BLUE}📁 Using existing folder: $DATE_FOLDER${NC}"
fi
echo ""

# Check if today's summary already exists
if [ -f "$OUTPUT_FILE" ]; then
    echo -e "${YELLOW}⚠️  Session summary for $TODAY already exists:${NC}"
    echo -e "${BLUE}   $OUTPUT_FILE${NC}"
    echo ""
    read -p "Do you want to overwrite it? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${GREEN}✅ Keeping existing file. Opening it...${NC}"
        # Open in default editor if available
        if command -v code &> /dev/null; then
            code "$OUTPUT_FILE"
        elif command -v vim &> /dev/null; then
            vim "$OUTPUT_FILE"
        else
            echo -e "${BLUE}   File: $OUTPUT_FILE${NC}"
        fi
        exit 0
    fi
fi

# Create session summary — variables are interpolated directly (no sed needed)
echo -e "${BLUE}📝 Creating session summary for $READABLE_DATE...${NC}"

cat > "$OUTPUT_FILE" <<EOF
# Coding Session Summary - $READABLE_DATE

## 📋 **Session Overview**

**Date:** $READABLE_DATE
**Start Time:** $START_TIME
**Duration:** TBD
**Focus Areas:** TBD

---

## 🎯 **Goals for Today**

- [ ] Goal 1
- [ ] Goal 2
- [ ] Goal 3

---

## 🔧 **Changes Made**

### Feature/Fix #1: [Title]
**Commit:** \`[commit-hash]\` - "[commit message]"

**Problem:**
- Describe the issue or requirement

**Solution:**
- What was implemented
- Technical approach

**Files Changed:**
- \`path/to/file1.ext\` - Description of changes

**Testing:**
- How it was tested
- Results

---

## 🐛 **Bugs Fixed**

### Bug: [Description]
- **Issue:** What was broken
- **Root Cause:** Why it was broken
- **Fix:** How it was fixed
- **Files:** \`path/to/file.ext\`
- **Commit:** \`[hash]\`

---

## 📊 **Technical Details**

### Backend Changes
- List significant backend modifications

### Frontend Changes
- UI/UX improvements

### Database Changes
\`\`\`sql
-- Any SQL changes made
\`\`\`

### Configuration Changes
- Environment variables
- Config file updates

---

## 🧪 **Testing Notes**

- [ ] Feature X tested and working
- [ ] Edge case Y verified

---

## 🚀 **Commits Summary**

1. \`[hash]\` - [Commit message]

**Total:** [N] commits

---

## 🔮 **Next Steps**

- [ ] Task 1
- [ ] Task 2
- [ ] Task 3

---

## ✅ **Session Complete**

**End Time:** TBD
**Total Duration:** TBD
**Goals Achieved:** [N]/[N]
**Commits Made:** [N]
**Files Changed:** [N]

**Summary:**
[Brief 2-3 sentence summary of what was accomplished]

---

## 📌 **Remember for Next Session**

- Important note 1
- Important note 2
- Where you left off
EOF

echo -e "${GREEN}✅ Created: $OUTPUT_FILE${NC}"

# Create DailyNotes.md file
echo -e "${BLUE}📝 Creating daily notes file...${NC}"

cat > "$NOTES_FILE" <<EOF
---
**Author:** Hector
**Date:** $READABLE_DATE
**Purpose:** All the notes created during the day will be collected here. The notes could include temporary pieces of information, prompts used during the coding process, and other miscellaneous information about the project.

---

## Daily Notes

### $START_TIME - Note Title
[Note content goes here...]

---

EOF

echo -e "${GREEN}✅ Created: $NOTES_FILE${NC}"
echo ""
echo -e "${BLUE}📋 Next steps:${NC}"
echo "   1. Fill in session goals and focus areas"
echo "   2. Document changes as you make them"
echo "   3. Update at end of day with completion status"
echo ""

# Try to open in editor
if command -v code &> /dev/null; then
    echo -e "${BLUE}📂 Opening in VS Code...${NC}"
    code "$OUTPUT_FILE"
elif command -v vim &> /dev/null; then
    echo -e "${BLUE}📂 Opening in vim...${NC}"
    vim "$OUTPUT_FILE"
else
    echo -e "${YELLOW}💡 Open manually: $OUTPUT_FILE${NC}"
fi

echo ""
echo -e "${GREEN}✨ Ready to start coding!${NC}"
