#!/bin/bash
#
# create-daily-summary.sh
# Creates a new session summary file from template for today's date
#

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get project root directory (assumes script is in ./scripts/)
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATE_FILE="$PROJECT_ROOT/cascade-logs/SESSION_SUMMARY_TEMPLATE.md"
OUTPUT_DIR="$PROJECT_ROOT/cascade-logs"

# Get today's date in YYYY-MM-DD format
TODAY=$(date +%Y-%m-%d)
READABLE_DATE=$(date +"%B %d, %Y")  # e.g., "January 06, 2026"
START_TIME=$(date +"%I:%M %p")      # e.g., "09:38 AM"

# Output file
OUTPUT_FILE="$OUTPUT_DIR/SESSION_SUMMARY_${TODAY}.md"

# Check if template exists
if [ ! -f "$TEMPLATE_FILE" ]; then
    echo -e "${YELLOW}Error: Template file not found at $TEMPLATE_FILE${NC}"
    exit 1
fi

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

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Copy template and replace placeholders
echo -e "${BLUE}📝 Creating session summary for $READABLE_DATE...${NC}"

# Use sed to replace placeholders
sed -e "s/\[DATE\]/$READABLE_DATE/g" \
    -e "s/\[TIME\]/$START_TIME/g" \
    -e "s/\[DURATION\]/TBD/g" \
    "$TEMPLATE_FILE" > "$OUTPUT_FILE"

echo -e "${GREEN}✅ Created: $OUTPUT_FILE${NC}"
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
echo -e "${GREEN}✨ Ready to start coding! Don't forget:${NC}"
echo "   • gcloud auth application-default login"
echo "   • Start backend: cd backend && python -m uvicorn src.api.server:app --host 0.0.0.0 --port 8000 --reload"
echo "   • Start frontend: cd frontend && npm run dev"
