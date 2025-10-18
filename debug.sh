#!/bin/bash
# Debug runner for Haste - shows console output

# Colors
BLUE='\033[0;34m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔧 Running Haste in DEBUG mode...${NC}"
echo ""

# Kill any existing instance
pkill -9 Haste 2>/dev/null || true
sleep 0.5

# Build if needed
if [ ! -f "gui/macos/Haste.app/Contents/MacOS/Haste" ]; then
    echo -e "${BLUE}📦 Building first...${NC}"
    make build
fi

echo -e "${GREEN}🚀 Starting Haste...${NC}"
echo -e "${GREEN}Press Cmd+Shift+V to open search window${NC}"
echo -e "${GREEN}Press Ctrl+C to stop${NC}"
echo ""
echo "--- Console Output ---"
echo ""

# Run the app and show output
./gui/macos/Haste.app/Contents/MacOS/Haste

