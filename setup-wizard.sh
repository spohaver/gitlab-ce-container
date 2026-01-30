#!/bin/bash
# ============================================================================
# GitLab Setup Wizard
# ============================================================================
# Interactive script to configure GitLab for different deployment types.
# 
# This wizard will:
# 1. Ask about your deployment type (sandbox, staging, or production)
# 2. Generate appropriate .env configuration file
# 3. Create docker-compose.override.yml if needed
# 4. Validate your configuration
# 5. Provide next steps and warnings
#
# Usage: ./setup-wizard.sh
# ============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Functions
print_header() {
    echo ""
    echo -e "${CYAN}============================================================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}============================================================================${NC}"
    echo ""
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

prompt_input() {
    local prompt="$1"
    local default="$2"
    local var_name="$3"
    
    if [ -n "$default" ]; then
        read -p "$prompt [$default]: " input
        eval "$var_name=\"${input:-$default}\""
    else
        read -p "$prompt: " input
        eval "$var_name=\"$input\""
    fi
}

prompt_password() {
    local prompt="$1"
    local var_name="$2"
    
    read -s -p "$prompt: " password
    echo ""
    eval "$var_name=\"$password\""
}

generate_password() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-25
}

# ============================================================================
# Welcome Screen
# ============================================================================
clear
print_header "GitLab CE Setup Wizard"

echo "Welcome! This wizard will help you configure GitLab for your environment."
echo ""
echo "Deployment types:"
echo "  • sandbox    - Local development and testing (minimal security)"
echo "  • staging    - Pre-production environment (production-like security)"
echo "  • production - Live production server (maximum security)"
echo ""

# Check if .env already exists
if [ -f "$SCRIPT_DIR/.env" ]; then
    print_warning ".env file already exists!"
    read -p "Do you want to overwrite it? (yes/no) [no]: " overwrite
    if [ "$overwrite" != "yes" ]; then
        print_info "Setup cancelled. Existing .env file preserved."
        exit 0
    fi
fi

# ============================================================================
# Select Deployment Type
# ============================================================================
print_header "Step 1: Select Deployment Type"

echo "Which type of deployment are you setting up?"
echo "  1) Sandbox/Development (quick local testing)"
echo "  2) Staging (pre-production testing)"
echo "  3) Production (live server)"
echo ""

while true; do
    read -p "Enter choice (1-3): " choice
    case $choice in
        1) DEPLOYMENT_TYPE="sandbox"; break ;;
        2) DEPLOYMENT_TYPE="staging"; break ;;
        3) DEPLOYMENT_TYPE="production"; break ;;
        *) print_error "Invalid choice. Please enter 1, 2, or 3." ;;
    esac
done

print_success "Deployment type: $DEPLOYMENT_TYPE"

# ============================================================================
# Deployment-specific Configuration
# ============================================================================

if [ "$DEPLOYMENT_TYPE" = "sandbox" ]; then
    print_header "Sandbox Configuration"
    
    print_info "Sandbox mode uses sensible defaults for local testing."
    print_info "Most settings will be auto-configured."
    echo ""
    
    GITLAB_DOMAIN="gitlab.sandbox.local"
    GITLAB_SSH_PORT="2224"
    GITLAB_HTTP_PORT="8080"
    GITLAB_HTTPS_PORT="8443"
    GITLAB_SMTP_ENABLE="false"
    USE_SSL="false"
    
    print_success "Using domain: $GITLAB_DOMAIN"
    print_success "Ports: HTTP=$GITLAB_HTTP_PORT, HTTPS=$GITLAB_HTTPS_PORT, SSH=$GITLAB_SSH_PORT"
    print_info "Email disabled for sandbox mode"
    
else
    # Staging or Production
    print_header "Step 2: Domain Configuration"
    
    prompt_input "Enter your GitLab domain (e.g., gitlab.example.com)" "" GITLAB_DOMAIN
    
    # Validate domain
    if [[ ! "$GITLAB_DOMAIN" =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]+[a-zA-Z0-9]$ ]]; then
        print_error "Invalid domain name format"
        exit 1
    fi
    
    print_header "Step 3: Port Configuration"
    
    print_info "Standard ports: HTTP=80, HTTPS=443, SSH=22"
    print_warning "If port 22 is used by host SSH, use an alternate port (e.g., 2222)"
    echo ""
    
    prompt_input "HTTP port" "80" GITLAB_HTTP_PORT
    prompt_input "HTTPS port" "443" GITLAB_HTTPS_PORT
    prompt_input "SSH port" "2222" GITLAB_SSH_PORT
    
    print_header "Step 4: SSL/TLS Configuration"
    
    read -p "Do you have valid SSL certificates? (yes/no) [yes]: " has_ssl
    if [ "$has_ssl" = "no" ]; then
        print_warning "SSL certificates are REQUIRED for $DEPLOYMENT_TYPE deployment"
        print_info "You can obtain free certificates from Let's Encrypt"
        print_info "Run: certbot certonly --standalone -d $GITLAB_DOMAIN"
        echo ""
        read -p "Continue without SSL (NOT RECOMMENDED)? (yes/no) [no]: " continue_no_ssl
        if [ "$continue_no_ssl" != "yes" ]; then
            print_error "Setup cancelled. Please obtain SSL certificates first."
            exit 1
        fi
        USE_SSL="false"
    else
        USE_SSL="true"
        print_success "SSL enabled"
        print_info "Ensure certificates are placed in: $SCRIPT_DIR/config/ssl/"
        print_info "Required files:"
        print_info "  - $GITLAB_DOMAIN.crt"
        print_info "  - $GITLAB_DOMAIN.key"
    fi
    
    print_header "Step 5: Email Configuration"
    
    read -p "Configure email (SMTP)? (yes/no) [yes]: " configure_smtp
    if [ "$configure_smtp" != "no" ]; then
        GITLAB_SMTP_ENABLE="true"
        
        prompt_input "SMTP server address (e.g., smtp.gmail.com)" "" GITLAB_SMTP_ADDRESS
        prompt_input "SMTP port" "587" GITLAB_SMTP_PORT
        prompt_input "SMTP username" "" GITLAB_SMTP_USER
        prompt_password "SMTP password" GITLAB_SMTP_PASSWORD
        prompt_input "SMTP domain" "$GITLAB_DOMAIN" GITLAB_SMTP_DOMAIN
        prompt_input "Email 'From' address" "gitlab@$GITLAB_DOMAIN" GITLAB_EMAIL_FROM
        prompt_input "Email 'Reply-To' address" "noreply@$GITLAB_DOMAIN" GITLAB_EMAIL_REPLY_TO
    else
        GITLAB_SMTP_ENABLE="false"
        print_warning "Email disabled. Users won't receive notifications."
    fi
fi

# ============================================================================
# Additional Settings
# ============================================================================

if [ "$DEPLOYMENT_TYPE" = "production" ]; then
    print_header "Step 6: Security Settings"
    
    print_info "Generate secure passwords for internal services..."
    GITLAB_ROOT_PASSWORD=$(generate_password)
    POSTGRES_PASSWORD=$(generate_password)
    
    print_success "Passwords generated"
    print_warning "Save these passwords in a secure location!"
    echo ""
    echo "Root password: $GITLAB_ROOT_PASSWORD"
    echo ""
    read -p "Press Enter to continue..."
fi

# ============================================================================
# Generate .env File
# ============================================================================
print_header "Generating Configuration"

cat > "$SCRIPT_DIR/.env" << EOF
# ============================================================================
# GitLab Configuration - Generated by setup-wizard.sh
# ============================================================================
# Deployment Type: $DEPLOYMENT_TYPE
# Generated: $(date)
# 
# SECURITY WARNING: This file contains sensitive credentials!
# - Never commit this file to version control
# - Set permissions: chmod 600 .env
# - Back up securely in encrypted storage
# ============================================================================

# -----------------------------------------------------------------------------
# Basic Configuration
# -----------------------------------------------------------------------------
GITLAB_DOMAIN=$GITLAB_DOMAIN
GITLAB_SSH_PORT=$GITLAB_SSH_PORT

# -----------------------------------------------------------------------------
# Email Configuration
# -----------------------------------------------------------------------------
GITLAB_SMTP_ENABLE=$GITLAB_SMTP_ENABLE
EOF

if [ "$GITLAB_SMTP_ENABLE" = "true" ]; then
    cat >> "$SCRIPT_DIR/.env" << EOF
GITLAB_SMTP_ADDRESS=$GITLAB_SMTP_ADDRESS
GITLAB_SMTP_PORT=$GITLAB_SMTP_PORT
GITLAB_SMTP_USER=$GITLAB_SMTP_USER
GITLAB_SMTP_PASSWORD=$GITLAB_SMTP_PASSWORD
GITLAB_SMTP_DOMAIN=$GITLAB_SMTP_DOMAIN
GITLAB_EMAIL_FROM=$GITLAB_EMAIL_FROM
GITLAB_EMAIL_REPLY_TO=$GITLAB_EMAIL_REPLY_TO
EOF
fi

if [ "$DEPLOYMENT_TYPE" = "production" ]; then
    cat >> "$SCRIPT_DIR/.env" << EOF

# -----------------------------------------------------------------------------
# Security (Production)
# -----------------------------------------------------------------------------
# Initial root password - CHANGE THIS after first login!
GITLAB_ROOT_PASSWORD=$GITLAB_ROOT_PASSWORD
EOF
fi

cat >> "$SCRIPT_DIR/.env" << EOF

# -----------------------------------------------------------------------------
# Backup Configuration (Configure after deployment)
# -----------------------------------------------------------------------------
# BACKUP_ENCRYPTION_KEY=
# BACKUP_S3_BUCKET=
# BACKUP_S3_REGION=
# BACKUP_S3_ACCESS_KEY=
# BACKUP_S3_SECRET_KEY=

# -----------------------------------------------------------------------------
# Monitoring (Optional)
# -----------------------------------------------------------------------------
# GRAFANA_PASSWORD=
# PROMETHEUS_RETENTION=15d
EOF

chmod 600 "$SCRIPT_DIR/.env"
print_success ".env file created with secure permissions (600)"

# ============================================================================
# Create docker-compose.override.yml if needed
# ============================================================================

if [ "$DEPLOYMENT_TYPE" = "sandbox" ]; then
    print_info "Creating symbolic link to sandbox compose file..."
    
    # Create a simple script to use the sandbox profile
    cat > "$SCRIPT_DIR/start-gitlab.sh" << 'EOFSTART'
#!/bin/bash
# Start GitLab using sandbox profile
docker-compose -f docker-compose.sandbox.yml up -d
EOFSTART
    chmod +x "$SCRIPT_DIR/start-gitlab.sh"
    
    print_success "Created start-gitlab.sh script"
fi

# ============================================================================
# Create necessary directories
# ============================================================================
print_info "Creating required directories..."

if [ "$DEPLOYMENT_TYPE" = "sandbox" ]; then
    mkdir -p "$SCRIPT_DIR/gitlab-local"/{data,config,logs,ssl}
else
    mkdir -p "$SCRIPT_DIR/config/ssl"
    mkdir -p "$SCRIPT_DIR/backups"
fi

print_success "Directories created"

# ============================================================================
# Run validation
# ============================================================================
print_header "Validating Configuration"

if [ -f "$SCRIPT_DIR/validate-deployment.sh" ]; then
    print_info "Running validation script..."
    bash "$SCRIPT_DIR/validate-deployment.sh" "$DEPLOYMENT_TYPE"
else
    print_warning "Validation script not found. Skipping validation."
fi

# ============================================================================
# Final Instructions
# ============================================================================
print_header "Setup Complete!"

echo "Configuration files created:"
print_success ".env (chmod 600)"
if [ "$DEPLOYMENT_TYPE" = "sandbox" ]; then
    print_success "start-gitlab.sh"
fi

echo ""
print_header "Next Steps"

if [ "$DEPLOYMENT_TYPE" = "sandbox" ]; then
    echo "1. Start GitLab:"
    echo -e "   ${GREEN}./start-gitlab.sh${NC}"
    echo ""
    echo "2. Wait for GitLab to start (5-10 minutes first time)"
    echo ""
    echo "3. Access GitLab:"
    echo -e "   ${GREEN}http://localhost:8080${NC}"
    echo ""
    echo "4. Login credentials:"
    echo "   Username: root"
    echo "   Password: (shown on first access)"
    echo ""
    print_info "See QUICKSTART-SANDBOX.md for detailed instructions"
    
elif [ "$DEPLOYMENT_TYPE" = "staging" ]; then
    echo "1. Verify SSL certificates are in place:"
    echo -e "   ${YELLOW}ls -l config/ssl/$GITLAB_DOMAIN.*${NC}"
    echo ""
    echo "2. Start GitLab:"
    echo -e "   ${GREEN}docker-compose -f docker-compose.staging.yml up -d${NC}"
    echo ""
    echo "3. Monitor startup:"
    echo -e "   ${GREEN}docker-compose -f docker-compose.staging.yml logs -f${NC}"
    echo ""
    echo "4. Access GitLab:"
    echo -e "   ${GREEN}https://$GITLAB_DOMAIN${NC}"
    echo ""
    print_info "See DEPLOYMENT.md for detailed instructions"
    
else  # production
    echo ""
    print_warning "IMPORTANT: Production deployment requires additional steps!"
    echo ""
    echo "Before starting GitLab:"
    echo ""
    echo "1. ✓ Verify SSL certificates:"
    echo "   ls -l config/ssl/$GITLAB_DOMAIN.*"
    echo ""
    echo "2. ✓ Configure firewall:"
    echo "   sudo ufw allow 80/tcp"
    echo "   sudo ufw allow 443/tcp"
    echo "   sudo ufw allow $GITLAB_SSH_PORT/tcp"
    echo ""
    echo "3. ✓ Install fail2ban:"
    echo "   sudo apt-get install fail2ban"
    echo ""
    echo "4. ✓ Review SECURITY.md checklist"
    echo ""
    echo "After completing prerequisites:"
    echo ""
    echo "5. Start GitLab:"
    echo -e "   ${GREEN}docker-compose -f docker-compose.production.yml up -d${NC}"
    echo ""
    echo "6. Monitor startup (first boot takes 5-10 minutes):"
    echo -e "   ${GREEN}docker-compose -f docker-compose.production.yml logs -f${NC}"
    echo ""
    echo "7. Access GitLab and change root password immediately:"
    echo -e "   ${GREEN}https://$GITLAB_DOMAIN${NC}"
    echo "   Username: root"
    echo "   Password: $GITLAB_ROOT_PASSWORD"
    echo ""
    echo "8. Enable 2FA for admin accounts"
    echo ""
    echo "9. Configure automated backups (see scripts/backup.sh)"
    echo ""
    echo "10. Set up monitoring and alerting"
    echo ""
    print_info "See QUICKSTART-PRODUCTION.md and SECURITY.md for complete checklist"
fi

echo ""
print_header "Important Security Reminders"

print_warning "The .env file contains sensitive credentials!"
print_info "Keep it secure and never commit to version control"

if [ "$DEPLOYMENT_TYPE" = "production" ]; then
    echo ""
    print_warning "This is a PRODUCTION deployment!"
    print_warning "Complete all security hardening steps before exposing to users"
    print_warning "Test disaster recovery procedures"
fi

echo ""
print_success "Setup wizard completed successfully!"
echo ""
