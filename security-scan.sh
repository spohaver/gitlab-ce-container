#!/bin/bash
# GitLab Server Security Scanner
# Runs multiple SAST tools to detect vulnerabilities, secrets, and misconfigurations

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║        GitLab Server Security Audit Scanner                 ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    echo -e "${RED}✗ Docker is required but not installed${NC}"
    exit 1
fi

# Create reports directory
REPORT_DIR="$SCRIPT_DIR/security-reports"
mkdir -p "$REPORT_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT_FILE="$REPORT_DIR/security-scan-$TIMESTAMP.txt"

echo -e "${GREEN}Security scan started at: $(date)${NC}" | tee "$REPORT_FILE"
echo "Report will be saved to: $REPORT_FILE"
echo ""

# Function to run scan and capture output
run_scan() {
    local scan_name=$1
    local scan_cmd=$2
    
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}▶ Running: $scan_name${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    echo "========================================" >> "$REPORT_FILE"
    echo "$scan_name" >> "$REPORT_FILE"
    echo "========================================" >> "$REPORT_FILE"
    
    if eval "$scan_cmd" 2>&1 | tee -a "$REPORT_FILE"; then
        echo -e "${GREEN}✓ $scan_name completed${NC}"
    else
        echo -e "${YELLOW}⚠ $scan_name completed with warnings${NC}"
    fi
    echo "" | tee -a "$REPORT_FILE"
}

# 1. Scan for secrets in git-tracked files (excluding gitlab-local)
run_scan "Secret Detection (Trivy)" \
    "docker run --rm -v '$PWD:/src' aquasec/trivy fs --scanners secret --severity HIGH,CRITICAL /src --skip-dirs gitlab-local,node_modules,.git"

# 2. Scan Docker Compose files for misconfigurations
run_scan "Docker Compose Misconfiguration Scan" \
    "docker run --rm -v '$PWD:/src' aquasec/trivy config /src/docker-compose.production.yml || true"

# 3. Scan for CVEs in Docker images referenced
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}▶ Running: Docker Image Vulnerability Scan${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Extract image from docker-compose files
IMAGES=$(grep -h "image:" docker-compose*.yml | awk '{print $2}' | sort -u)

for IMAGE in $IMAGES; do
    echo -e "${YELLOW}Scanning image: $IMAGE${NC}"
    echo "========================================" >> "$REPORT_FILE"
    echo "Image Vulnerability Scan: $IMAGE" >> "$REPORT_FILE"
    echo "========================================" >> "$REPORT_FILE"
    
    docker run --rm aquasec/trivy image --severity HIGH,CRITICAL "$IMAGE" 2>&1 | tee -a "$REPORT_FILE" || echo "Scan completed with warnings"
    echo "" >> "$REPORT_FILE"
done

# 4. Check .gitignore effectiveness
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}▶ Running: .gitignore Security Audit${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo "========================================" >> "$REPORT_FILE"
echo ".gitignore Security Audit" >> "$REPORT_FILE"
echo "========================================" >> "$REPORT_FILE"

# Check for sensitive files that might not be ignored
SENSITIVE_PATTERNS=(
    "*.env"
    "*.key"
    "*.pem"
    "*secret*"
    "*password*"
    "*.sql"
    "*.tar"
    "*.backup"
)

echo "Checking for potentially sensitive files in git..." | tee -a "$REPORT_FILE"
FOUND_ISSUES=0

for PATTERN in "${SENSITIVE_PATTERNS[@]}"; do
    FILES=$(git ls-files | grep -i "$PATTERN" | grep -v ".gitignore\|.example\|.template\|README\|.md" || true)
    if [ -n "$FILES" ]; then
        echo -e "${RED}⚠ Found tracked files matching '$PATTERN':${NC}" | tee -a "$REPORT_FILE"
        echo "$FILES" | tee -a "$REPORT_FILE"
        FOUND_ISSUES=1
    fi
done

if [ $FOUND_ISSUES -eq 0 ]; then
    echo -e "${GREEN}✓ No sensitive files found in git tracking${NC}" | tee -a "$REPORT_FILE"
fi
echo "" >> "$REPORT_FILE"

# 5. Check for common security misconfigurations
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}▶ Running: Configuration Security Checks${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo "========================================" >> "$REPORT_FILE"
echo "Configuration Security Checks" >> "$REPORT_FILE"
echo "========================================" >> "$REPORT_FILE"

# Check for hardcoded IPs/domains
echo "Checking for hardcoded credentials or sensitive values..." | tee -a "$REPORT_FILE"

# Check docker-compose files
if grep -n "password:\|PASSWORD:\|secret:\|SECRET:\|token:\|TOKEN:" docker-compose*.yml 2>/dev/null | grep -v "_FILE\|\${"; then
    echo -e "${RED}⚠ Potential hardcoded credentials found in docker-compose files${NC}" | tee -a "$REPORT_FILE"
else
    echo -e "${GREEN}✓ No hardcoded credentials in docker-compose files${NC}" | tee -a "$REPORT_FILE"
fi

# Check Python scripts
if git ls-files "*.py" | xargs grep -n "password\s*=\s*['\"]" 2>/dev/null | grep -v "your_password\|example\|CHANGE"; then
    echo -e "${RED}⚠ Potential hardcoded passwords in Python scripts${NC}" | tee -a "$REPORT_FILE"
else
    echo -e "${GREEN}✓ No hardcoded passwords in Python scripts${NC}" | tee -a "$REPORT_FILE"
fi

echo "" >> "$REPORT_FILE"

# 6. Summary
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✓ Security scan completed${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Full report saved to: $REPORT_FILE"
echo ""
echo -e "${YELLOW}Recommendations:${NC}"
echo "1. Review the full report for any HIGH or CRITICAL findings"
echo "2. Ensure all .env files are properly gitignored"
echo "3. Regularly update Docker images to patch CVEs"
echo "4. Run this scan before each major release or deployment"
echo "5. Consider integrating this into your CI/CD pipeline"
echo ""
echo -e "${BLUE}For more security guidance, see: ${NC}SECURITY.md"
