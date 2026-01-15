#!/bin/bash

# Flutter Web Rebuild and Serve Script
# Usage: ./scripts/rebuild_and_serve.sh

set -e  # Exit on error

# Color definitions
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Project root directory
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

echo -e "${GREEN}=== Flutter Web Rebuild and Serve ===${NC}\n"

# 1. Stop old server
echo -e "${YELLOW}Step 1: Stopping old server...${NC}"

# Method 1: Stop by process name
pkill -f 'python3 -m http.server' 2>/dev/null && echo "Stopped old server (by process name)" || true

# Method 2: Stop by port (more reliable)
PORT_PID=$(lsof -ti:8080 2>/dev/null || true)
if [ -n "$PORT_PID" ]; then
    kill -9 $PORT_PID 2>/dev/null && echo "Stopped process using port 8080 (PID: $PORT_PID)" || true
fi

# Wait for port to be released
for i in {1..5}; do
    if ! lsof -ti:8080 > /dev/null 2>&1; then
        break
    fi
    sleep 1
done

# Final check
if lsof -ti:8080 > /dev/null 2>&1; then
    echo -e "${RED}⚠️  Warning: Port 8080 is still in use, server may fail to start${NC}"
else
    echo "✅ Port 8080 is released"
fi
sleep 1

# 2. Clean old build files (optional)
# echo -e "${YELLOW}Step 2: Cleaning old build files...${NC}"
# rm -rf build/web
# echo "Cleaned"

# 3. Flutter build
echo -e "\n${YELLOW}Step 2: Flutter Web build...${NC}"
flutter build web --release

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Flutter build failed!${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Flutter build completed${NC}"

# 4. Run optimization script
echo -e "\n${YELLOW}Step 3: Running optimization script...${NC}"
node scripts/optimize_web_build.js

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Optimization script failed!${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Optimization completed${NC}"

# 5. Start server
echo -e "\n${YELLOW}Step 4: Starting server...${NC}"
cd build/web

# Check if port is available
if lsof -ti:8080 > /dev/null 2>&1; then
    echo -e "${RED}❌ Error: Port 8080 is still in use, cannot start server${NC}"
    echo -e "${YELLOW}💡 Tip: Please manually stop the process using the port:${NC}"
    lsof -ti:8080 | xargs -I {} echo "   kill -9 {}"
    exit 1
fi

# Start server
python3 -m http.server 8080 > /tmp/flutter_http_server.log 2>&1 &
SERVER_PID=$!
sleep 3

# Check if server started successfully
if ps -p $SERVER_PID > /dev/null 2>&1; then
    # Check again if port is in use (confirm server is actually listening)
    if lsof -ti:8080 > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Server started${NC}"
        echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${GREEN}🌐 Access URL: http://localhost:8080${NC}"
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "\n${YELLOW}📝 Tips:${NC}"
        echo -e "   - Server PID: $SERVER_PID"
        echo -e "   - Stop server: pkill -f 'python3 -m http.server'"
        echo -e "   - Or use: kill $SERVER_PID"
        echo -e "   - Log file: /tmp/flutter_http_server.log"
        echo ""
    else
        echo -e "${RED}❌ Server process exists but port is not listening, may have failed to start${NC}"
        cat /tmp/flutter_http_server.log 2>/dev/null || true
        kill $SERVER_PID 2>/dev/null || true
        exit 1
    fi
else
    echo -e "${RED}❌ Server failed to start!${NC}"
    echo -e "${YELLOW}Error log:${NC}"
    cat /tmp/flutter_http_server.log 2>/dev/null || true
    exit 1
fi
