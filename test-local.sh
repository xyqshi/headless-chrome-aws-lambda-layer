#!/bin/bash
# Local SAM testing script for headless-chrome Lambda layer

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}=== Headless Chrome Lambda Layer - Local Test ===${NC}"

# Check if SAM CLI is installed
if ! command -v sam &> /dev/null; then
    echo -e "${RED}Error: AWS SAM CLI is not installed.${NC}"
    echo "Install it with: brew install aws-sam-cli"
    exit 1
fi

# Check if Docker is running
if ! docker info &> /dev/null; then
    echo -e "${RED}Error: Docker is not running. Please start Docker.${NC}"
    exit 1
fi

# Check if layer zip exists
if [ ! -f "layer/layer-headless_chrome-dev.zip" ]; then
    echo -e "${YELLOW}Layer zip not found. Building layer first...${NC}"
    make build
fi

# Build SAM application
echo -e "${YELLOW}Building SAM application...${NC}"
sam build --use-container

# Run test
echo -e "${YELLOW}Invoking Lambda function locally...${NC}"
echo ""

if [ -n "$1" ]; then
    # Use custom event file if provided
    sam local invoke TestFunction --event "$1"
else
    # Use default test event
    sam local invoke TestFunction --event events/test.json
fi

echo ""
echo -e "${GREEN}=== Test completed ===${NC}"
