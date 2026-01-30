#!/bin/bash
# ============================================================================
# GitLab Deployment Validation Script
# ============================================================================
# Checks for common misconfigurations, security issues, and missing
# requirements before deployment.
#
# Usage: ./validate-deployment.sh [sandbox|staging|production]
# 
# Exit codes:
#   0 - All checks passed
#   1 - Warnings found (can proceed with caution)
#   2 - Errors found (should not deploy)
# ============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Counters
ERRORS=0
WARNINGS=0
PASSED=0

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Get deployment type from argument or detect
DEPLOYMENT_TYPE="${1:-}"

# Functions
print_header() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo ""
}

print_check() {
    echo -e "${BLUE}[CHECK]${NC} $1"
}

print_pass() {
    echo -e "${GREEN}  ✓${NC} $1"
    ((PASSED++))
}

print_warn() {
    echo -e "${YELLOW}  ⚠${NC} $1"
    ((WARNINGS++))
}

print_error() {
    echo -e "${RED}  ✗${NC} $1"
    ((ERRORS++))
}

print_info() {
    echo -e "${BLUE}    ℹ${NC} $1"
}

# ============================================================================
# Detect deployment type if not specified
# ============================================================================
detect_deployment_type() {
    if [ -z "$DEPLOYMENT_TYPE" ]; then
        print_info "Auto-detecting deployment type..."
        
        if [ -f "$SCRIPT_DIR/.env" ]; then
            if grep -q "sandbox" "$SCRIPT_DIR/.env"; then
                DEPLOYMENT_TYPE="sandbox"
            elif grep -q "staging" "$SCRIPT_DIR/.env"; then
                DEPLOYMENT_TYPE="staging"
            elif grep -q "production" "$SCRIPT_DIR/.env"; then
                DEPLOYMENT_TYPE="production"
            fi
        fi
        
        # Default to sandbox if can't detect
        DEPLOYMENT_TYPE="${DEPLOYMENT_TYPE:-sandbox}"
        print_info "Detected: $DEPLOYMENT_TYPE"
    fi
}

# ============================================================================
# Check functions
# ============================================================================

check_docker() {
    print_check "Docker installation"
    
    if command -v docker &> /dev/null; then
        DOCKER_VERSION=$(docker --version | grep -oP '\d+\.\d+\.\d+' | head -1)
        print_pass "Docker installed: $DOCKER_VERSION"
        
        # Check Docker is running
        if docker ps &> /dev/null; then
            print_pass "Docker daemon is running"
        else
            print_error "Docker daemon is not running"
            print_info "Start Docker: sudo systemctl start docker"
        fi
    else
        print_error "Docker is not installed"
        print_info "Install Docker: https://docs.docker.com/engine/install/"
    fi
}

check_docker_compose() {
    print_check "Docker Compose installation"
    
    if docker compose version &> /dev/null 2>&1; then
        COMPOSE_VERSION=$(docker compose version | grep -oP '\d+\.\d+\.\d+' | head -1)
        print_pass "Docker Compose installed: $COMPOSE_VERSION"
    elif command -v docker-compose &> /dev/null; then
        COMPOSE_VERSION=$(docker-compose --version | grep -oP '\d+\.\d+\.\d+' | head -1)
        print_pass "Docker Compose (standalone) installed: $COMPOSE_VERSION"
    else
        print_error "Docker Compose is not installed"
        print_info "Install Docker Compose: https://docs.docker.com/compose/install/"
    fi
}

check_system_resources() {
    print_check "System resources"
    
    # Check available memory
    if command -v free &> /dev/null; then
        TOTAL_MEM_GB=$(free -g | awk '/^Mem:/{print $2}')
        if [ "$TOTAL_MEM_GB" -ge 8 ]; then
            print_pass "Sufficient RAM: ${TOTAL_MEM_GB}GB"
        elif [ "$TOTAL_MEM_GB" -ge 4 ]; then
            print_warn "Low RAM: ${TOTAL_MEM_GB}GB (8GB+ recommended)"
            print_info "GitLab may run slowly or experience issues"
        else
            print_error "Insufficient RAM: ${TOTAL_MEM_GB}GB (minimum 4GB)"
        fi
    fi
    
    # Check available disk space
    AVAILABLE_SPACE_GB=$(df -BG "$SCRIPT_DIR" | awk 'NR==2 {print $4}' | tr -d 'G')
    if [ "$AVAILABLE_SPACE_GB" -ge 50 ]; then
        print_pass "Sufficient disk space: ${AVAILABLE_SPACE_GB}GB available"
    elif [ "$AVAILABLE_SPACE_GB" -ge 20 ]; then
        print_warn "Low disk space: ${AVAILABLE_SPACE_GB}GB available (50GB+ recommended)"
    else
        print_error "Insufficient disk space: ${AVAILABLE_SPACE_GB}GB (minimum 20GB)"
    fi
}

check_env_file() {
    print_check "Environment configuration (.env file)"
    
    if [ ! -f "$SCRIPT_DIR/.env" ]; then
        print_error ".env file not found"
        print_info "Run ./setup-wizard.sh to generate configuration"
        return
    fi
    
    print_pass ".env file exists"
    
    # Check file permissions
    ENV_PERMS=$(stat -c "%a" "$SCRIPT_DIR/.env")
    if [ "$ENV_PERMS" = "600" ]; then
        print_pass "Secure permissions (600)"
    else
        print_warn "Insecure permissions: $ENV_PERMS (should be 600)"
        print_info "Fix with: chmod 600 .env"
    fi
    
    # Check for example/placeholder values
    if grep -q "example.com" "$SCRIPT_DIR/.env" 2>/dev/null; then
        print_warn "Contains example.com domain"
        print_info "Update GITLAB_DOMAIN in .env file"
    fi
    
    if grep -q "password" "$SCRIPT_DIR/.env" 2>/dev/null; then
        print_warn "May contain placeholder passwords"
        print_info "Verify all passwords are properly configured"
    fi
    
    # Check required variables
    source "$SCRIPT_DIR/.env"
    
    if [ -z "$GITLAB_DOMAIN" ]; then
        print_error "GITLAB_DOMAIN not set"
    else
        print_pass "GITLAB_DOMAIN: $GITLAB_DOMAIN"
    fi
    
    if [ -z "$GITLAB_SSH_PORT" ]; then
        print_warn "GITLAB_SSH_PORT not set (will use default: 22)"
    fi
}

check_ssl_certificates() {
    print_check "SSL/TLS certificates"
    
    if [ "$DEPLOYMENT_TYPE" = "sandbox" ]; then
        print_info "SSL checks skipped for sandbox deployment"
        return
    fi
    
    source "$SCRIPT_DIR/.env" 2>/dev/null || true
    DOMAIN="${GITLAB_DOMAIN:-gitlab.example.com}"
    
    SSL_DIR="$SCRIPT_DIR/config/ssl"
    
    if [ ! -d "$SSL_DIR" ]; then
        print_error "SSL directory not found: $SSL_DIR"
        print_info "Create with: mkdir -p config/ssl"
        return
    fi
    
    # Check for certificate files
    CERT_FILE="$SSL_DIR/$DOMAIN.crt"
    KEY_FILE="$SSL_DIR/$DOMAIN.key"
    
    if [ -f "$CERT_FILE" ]; then
        print_pass "Certificate file found: $DOMAIN.crt"
        
        # Check certificate expiration
        if command -v openssl &> /dev/null; then
            EXPIRY=$(openssl x509 -enddate -noout -in "$CERT_FILE" | cut -d= -f2)
            EXPIRY_EPOCH=$(date -d "$EXPIRY" +%s)
            NOW_EPOCH=$(date +%s)
            DAYS_LEFT=$(( ($EXPIRY_EPOCH - $NOW_EPOCH) / 86400 ))
            
            if [ $DAYS_LEFT -gt 30 ]; then
                print_pass "Certificate valid for $DAYS_LEFT days"
            elif [ $DAYS_LEFT -gt 0 ]; then
                print_warn "Certificate expires in $DAYS_LEFT days"
                print_info "Renew certificate soon"
            else
                print_error "Certificate has expired"
            fi
        fi
    else
        print_error "Certificate file not found: $CERT_FILE"
        print_info "Obtain certificate from Let's Encrypt or commercial CA"
    fi
    
    if [ -f "$KEY_FILE" ]; then
        print_pass "Private key file found: $DOMAIN.key"
        
        # Check key permissions
        KEY_PERMS=$(stat -c "%a" "$KEY_FILE")
        if [ "$KEY_PERMS" = "600" ]; then
            print_pass "Secure key permissions (600)"
        else
            print_error "Insecure key permissions: $KEY_PERMS (should be 600)"
            print_info "Fix with: chmod 600 $KEY_FILE"
        fi
    else
        print_error "Private key file not found: $KEY_FILE"
    fi
}

check_compose_file() {
    print_check "Docker Compose configuration"
    
    COMPOSE_FILE=""
    case "$DEPLOYMENT_TYPE" in
        sandbox)
            COMPOSE_FILE="$SCRIPT_DIR/docker-compose.sandbox.yml"
            ;;
        staging)
            COMPOSE_FILE="$SCRIPT_DIR/docker-compose.staging.yml"
            ;;
        production)
            COMPOSE_FILE="$SCRIPT_DIR/docker-compose.production.yml"
            ;;
        *)
            COMPOSE_FILE="$SCRIPT_DIR/docker-compose.yml"
            ;;
    esac
    
    if [ ! -f "$COMPOSE_FILE" ]; then
        print_error "Compose file not found: $COMPOSE_FILE"
        return
    fi
    
    print_pass "Compose file found: $(basename $COMPOSE_FILE)"
    
    # Check for :latest tag (bad for production)
    if [ "$DEPLOYMENT_TYPE" = "production" ] || [ "$DEPLOYMENT_TYPE" = "staging" ]; then
        if grep -q "gitlab-ce:latest" "$COMPOSE_FILE"; then
            print_error "Using :latest tag in $DEPLOYMENT_TYPE (use pinned version)"
            print_info "Update image to specific version like gitlab/gitlab-ce:18.4.0"
        else
            print_pass "Using pinned version (not :latest)"
        fi
    fi
    
    # Check for port conflicts
    if grep -q "'22:22'" "$COMPOSE_FILE" || grep -q '"22:22"' "$COMPOSE_FILE"; then
        print_warn "Port 22 mapped (may conflict with host SSH)"
        print_info "Consider using alternate port like 2222:22"
    fi
}

check_directories() {
    print_check "Required directories"
    
    if [ "$DEPLOYMENT_TYPE" = "sandbox" ]; then
        DIRS=("gitlab-local" "gitlab-local/data" "gitlab-local/config" "gitlab-local/logs" "gitlab-local/ssl")
    else
        DIRS=("config" "config/ssl" "backups")
    fi
    
    for dir in "${DIRS[@]}"; do
        if [ -d "$SCRIPT_DIR/$dir" ]; then
            print_pass "$dir/ exists"
        else
            print_warn "$dir/ not found"
            print_info "Will be created automatically on first run"
        fi
    done
}

check_gitignore() {
    print_check ".gitignore security"
    
    if [ ! -f "$SCRIPT_DIR/.gitignore" ]; then
        print_error ".gitignore file not found"
        return
    fi
    
    # Check if security entries are uncommented
    if grep -q "^\.env$" "$SCRIPT_DIR/.gitignore"; then
        print_pass ".env excluded from Git"
    else
        print_error ".env NOT excluded from Git (will commit secrets!)"
        print_info "Uncomment .env in .gitignore immediately"
    fi
    
    if grep -q "^backups/" "$SCRIPT_DIR/.gitignore"; then
        print_pass "backups/ excluded from Git"
    else
        print_warn "backups/ not excluded (may commit sensitive data)"
    fi
    
    if grep -q "^config/gitlab.rb$" "$SCRIPT_DIR/.gitignore"; then
        print_pass "gitlab.rb excluded from Git"
    else
        print_warn "gitlab.rb not excluded (may commit secrets)"
    fi
}

check_port_availability() {
    print_check "Port availability"
    
    source "$SCRIPT_DIR/.env" 2>/dev/null || true
    
    if [ "$DEPLOYMENT_TYPE" = "sandbox" ]; then
        PORTS=(8080 8443 2224)
    else
        PORTS=(80 443 "${GITLAB_SSH_PORT:-2222}")
    fi
    
    for port in "${PORTS[@]}"; do
        if command -v netstat &> /dev/null; then
            if netstat -tuln | grep -q ":$port "; then
                print_warn "Port $port is already in use"
                print_info "Check with: sudo netstat -tulpn | grep :$port"
            else
                print_pass "Port $port is available"
            fi
        elif command -v ss &> /dev/null; then
            if ss -tuln | grep -q ":$port "; then
                print_warn "Port $port is already in use"
                print_info "Check with: sudo ss -tulpn | grep :$port"
            else
                print_pass "Port $port is available"
            fi
        else
            print_info "Cannot check port $port (netstat/ss not available)"
        fi
    done
}

check_firewall() {
    print_check "Firewall configuration"
    
    if [ "$DEPLOYMENT_TYPE" = "sandbox" ]; then
        print_info "Firewall checks skipped for sandbox deployment"
        return
    fi
    
    if command -v ufw &> /dev/null; then
        if ufw status | grep -q "Status: active"; then
            print_pass "UFW firewall is active"
            
            # Check if required ports are allowed
            source "$SCRIPT_DIR/.env" 2>/dev/null || true
            SSH_PORT="${GITLAB_SSH_PORT:-2222}"
            
            if ufw status | grep -q "80/tcp"; then
                print_pass "HTTP port (80) is allowed"
            else
                print_warn "HTTP port (80) not allowed in firewall"
                print_info "Allow with: sudo ufw allow 80/tcp"
            fi
            
            if ufw status | grep -q "443/tcp"; then
                print_pass "HTTPS port (443) is allowed"
            else
                print_warn "HTTPS port (443) not allowed in firewall"
                print_info "Allow with: sudo ufw allow 443/tcp"
            fi
        else
            print_warn "UFW firewall is not active"
            print_info "Enable with: sudo ufw enable"
        fi
    else
        print_info "UFW not installed (firewall check skipped)"
    fi
}

check_fail2ban() {
    print_check "fail2ban installation"
    
    if [ "$DEPLOYMENT_TYPE" = "sandbox" ]; then
        print_info "fail2ban checks skipped for sandbox deployment"
        return
    fi
    
    if command -v fail2ban-client &> /dev/null; then
        print_pass "fail2ban is installed"
        
        if systemctl is-active --quiet fail2ban 2>/dev/null; then
            print_pass "fail2ban service is running"
        else
            print_warn "fail2ban is installed but not running"
            print_info "Start with: sudo systemctl start fail2ban"
        fi
    else
        print_warn "fail2ban is not installed"
        print_info "Install with: sudo apt-get install fail2ban"
        print_info "Provides protection against brute-force attacks"
    fi
}

check_backup_config() {
    print_check "Backup configuration"
    
    if [ ! -f "$SCRIPT_DIR/scripts/backup.sh" ]; then
        print_warn "Backup script not found"
        return
    fi
    
    print_pass "Backup script exists"
    
    # Check if backup script is executable
    if [ -x "$SCRIPT_DIR/scripts/backup.sh" ]; then
        print_pass "Backup script is executable"
    else
        print_warn "Backup script is not executable"
        print_info "Fix with: chmod +x scripts/backup.sh"
    fi
    
    # Check if backups directory exists
    if [ -d "$SCRIPT_DIR/backups" ]; then
        print_pass "Backups directory exists"
    else
        print_warn "Backups directory not found"
        print_info "Will be created: mkdir -p backups"
    fi
    
    # Check for backup cron job
    if crontab -l 2>/dev/null | grep -q "backup.sh"; then
        print_pass "Backup cron job configured"
    else
        print_warn "No automated backup cron job found"
        print_info "Configure with: crontab -e"
        print_info "Example: 0 2 * * * /path/to/scripts/backup.sh"
    fi
}

check_git_status() {
    print_check "Git repository status"
    
    if [ ! -d "$SCRIPT_DIR/.git" ]; then
        print_info "Not a Git repository (skipping Git checks)"
        return
    fi
    
    # Check if .env is tracked
    if git ls-files --error-unmatch .env &> /dev/null; then
        print_error ".env file is tracked by Git!"
        print_info "Remove with: git rm --cached .env"
        print_info "Then commit: git commit -m 'Remove .env from tracking'"
    else
        print_pass ".env is not tracked by Git"
    fi
    
    # Check if sensitive directories are tracked
    if git ls-files --error-unmatch "config/gitlab.rb" &> /dev/null; then
        print_warn "config/gitlab.rb is tracked (may contain secrets)"
        print_info "Remove with: git rm --cached config/gitlab.rb"
    fi
    
    # Warn if about to commit sensitive files
    if git diff --cached --name-only | grep -E "(\.env|\.key|\.pem|gitlab-local)" > /dev/null; then
        print_error "Sensitive files staged for commit!"
        print_info "Unstage with: git reset HEAD <file>"
    fi
}

# ============================================================================
# Main validation flow
# ============================================================================

clear
print_header "GitLab Deployment Validation"

echo "Validating configuration for: $DEPLOYMENT_TYPE deployment"
echo ""

detect_deployment_type

# System checks
check_docker
check_docker_compose
check_system_resources
echo ""

# Configuration checks
check_env_file
check_ssl_certificates
check_compose_file
check_directories
check_gitignore
echo ""

# Security checks
check_port_availability
check_firewall
check_fail2ban
check_backup_config
echo ""

# Git checks
check_git_status
echo ""

# ============================================================================
# Summary
# ============================================================================
print_header "Validation Summary"

echo -e "${GREEN}Passed:${NC}   $PASSED checks"
echo -e "${YELLOW}Warnings:${NC} $WARNINGS issues"
echo -e "${RED}Errors:${NC}   $ERRORS critical issues"
echo ""

if [ $ERRORS -gt 0 ]; then
    print_error "VALIDATION FAILED"
    echo ""
    echo "Critical issues found that must be fixed before deployment."
    echo "Review the errors above and address each issue."
    echo ""
    exit 2
elif [ $WARNINGS -gt 0 ]; then
    print_warn "VALIDATION PASSED WITH WARNINGS"
    echo ""
    echo "Deployment can proceed, but warnings should be addressed."
    
    if [ "$DEPLOYMENT_TYPE" = "production" ]; then
        echo ""
        print_error "For PRODUCTION deployments, all warnings should be resolved!"
        echo ""
        read -p "Continue anyway? (yes/no) [no]: " continue
        if [ "$continue" != "yes" ]; then
            echo "Deployment cancelled."
            exit 1
        fi
    fi
    echo ""
    exit 1
else
    print_pass "VALIDATION PASSED"
    echo ""
    echo "All checks passed! Ready to deploy."
    echo ""
    
    if [ "$DEPLOYMENT_TYPE" = "production" ]; then
        echo "Production deployment checklist:"
        echo "  ☐ All team members notified"
        echo "  ☐ Maintenance window scheduled"
        echo "  ☐ Backup verified"
        echo "  ☐ Rollback plan documented"
        echo "  ☐ Monitoring alerts configured"
        echo ""
    fi
    
    exit 0
fi
