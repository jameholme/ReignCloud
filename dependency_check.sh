#!/bin/bash

# List of required tools
REQUIRED_TOOLS=("nmap" "subfinder" "dnsx" "/opt/edge/edge" "/opt/masscan/bin/masscan" "jq" "anew")

# Function to check if a command exists
check_tool() {
    if command -v "$1" &> /dev/null; then
        echo "[✔] $1 is installed."
    else
        echo "[✘] $1 is NOT installed. Please install it before running the script."
        MISSING_TOOLS+=("$1")
    fi
}

# Check each tool
MISSING_TOOLS=()
for tool in "${REQUIRED_TOOLS[@]}"; do
    check_tool "$tool"
done

# Display result
if [ ${#MISSING_TOOLS[@]} -eq 0 ]; then
    echo "All required tools appear to be installed. You should be able to run the main script: ./reigncloud.sh"
    exit 0
else
    echo "Missing tools: ${MISSING_TOOLS[*]}"
    exit 1
fi
