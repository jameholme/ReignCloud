#!/bin/bash

source ~/.bashrc

# Define input parameters
TARGET_DOMAINS="$1"
WORDLIST="$2"

# Ensure required parameters are provided
if [[ -z "$TARGET_DOMAINS" || -z "$WORDLIST" ]]; then
    echo "Usage: $0 <target-domains.txt> <wordlist.txt>"
    exit 1
fi

# Generate filenames with date
DATE=$(date +%F)
OUTPUT_DIR="$HOME/reigncloud_results"  # Output directory for consistent results

mkdir -p "$OUTPUT_DIR"  # Ensure the output directory exists

TARGET_HOSTS="${OUTPUT_DIR}/${DATE}-target-hosts.txt"
TARGET_IPS="${OUTPUT_DIR}/${DATE}-target-ips.txt"
FILTERED_IPS="${OUTPUT_DIR}/${DATE}-target-ips-for-port-scanning.txt"
DNSX_RESULTS="${OUTPUT_DIR}/${DATE}-dnsx-results.json"
RESULTS_TABLE="${OUTPUT_DIR}/${DATE}-results-table.csv"
EDGE_IP_RESULTS="${OUTPUT_DIR}/${DATE}-edge-ip-results.txt"  
MASS_SCAN_BIN="${OUTPUT_DIR}/${DATE}-masscan-results.bin"
MASS_SCAN_RESULTS="${OUTPUT_DIR}/${DATE}-masscan-results.txt"
PORT_LIST="${OUTPUT_DIR}/${DATE}-port-list.txt"
NMAP_SCAN_OUTPUT="${OUTPUT_DIR}/${DATE}-scan"

# Subdomain discovery using subfinder
subfinder -dL "$TARGET_DOMAINS" -o "$TARGET_HOSTS" -stats

# DNS Enumeration using dnsx
dnsx -d "$TARGET_DOMAINS" -w "$WORDLIST" -a -aaaa -cname -txt -mx -json -o "$DNSX_RESULTS" -r 8.8.8.8 -re -stats

# Filter and extract target hosts
cat "$TARGET_HOSTS" | anew "$TARGET_HOSTS"
cat "$DNSX_RESULTS" | jq -r '.host' | anew "$TARGET_HOSTS"

# Extract IP addresses and filter unwanted entries
cat "$DNSX_RESULTS" | jq -r '. | "\(.host) \(.a[]?)"' | grep -Ev "mail|MX|heroku|office|s3-website|files|www-dev|www|images" \
| awk '{ print $2 }' | anew "$TARGET_IPS"

# Filter IPs for port scanning and save to FILTERED_IPS
cat "$DNSX_RESULTS" | jq -r '. | "Hostname: \(.host) A Record: \(.a[]?)"' \
| grep -Ev "mail|MX|heroku|office|s3-website|files|www-dev|www|images" \
| awk '{ print $5 }' | anew "$FILTERED_IPS"

# Run cloud edge to perform recon and save results
/opt/edge/edge -ip "$FILTERED_IPS" -prefix >> "$EDGE_IP_RESULTS"

# Start masscan port scanning using FILTERED_IPS
sudo /opt/masscan/bin/masscan --open-only --source-port 40000-41023 -p 1-1024,3000,5000,6379,27017 -oB $MASS_SCAN_BIN  -iL $FILTERED_IPS
/opt/masscan/bin/masscan --readscan $MASS_SCAN_BIN | awk -F\/ '{ print $1 }' | sort -u | awk '{ print $4 }' | tr "\n" "," > $PORT_LIST

# Start nmap port scanning using FILTERED_IPS and PORT_LIST
sudo nmap -iL $FILTERED_IPS -p `echo $(cat $PORT_LIST)` -n -O -sV --script redis-info,mongodb-databases,http-git,http-methods,http-passwd --open --reason -Pn -oA $NMAP_SCAN_OUTPUT

# Create structured CSV results table for asset inventory (reference purposes only)
echo "Hostname,Record Type,Value" > "$RESULTS_TABLE"
cat "$DNSX_RESULTS" | jq -r '.all[] | select(test("IN"))' \
| awk -F'\t' '{print $1 "," $4 "," $5}' \
| grep -v "www-dev" | grep -v "mail" >> "$RESULTS_TABLE"

# Display result locations
echo "Check script results here:"
echo "  - Target Hosts (from subfinder): $TARGET_HOSTS"
echo "  - Target IPs (from subfinder + dnsx): $TARGET_IPS"
echo "  - Filtered IPs (used for port scanning): $FILTERED_IPS"
echo "  - Edge IP Recon Results: $EDGE_IP_RESULTS"
echo "  - DNS Enumeration Results: $DNSX_RESULTS"
echo "  - Structured Results Table: $RESULTS_TABLE"
echo "  - Masscan Results bin file: $MASS_SCAN_BIN"
echo "  - Masscan Results Port list: $PORT_LIST"
echo "  - NMAP Output: $NMAP_SCAN_OUTPUT"
