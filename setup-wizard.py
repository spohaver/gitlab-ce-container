#!/usr/bin/env python3
"""
GitLab Setup Wizard
Interactive and non-interactive configuration for GitLab deployments.

Requirements:
    - Python 3.6 or higher

Usage:
    # Interactive mode
    ./setup-wizard.py

    # Non-interactive mode
    ./setup-wizard.py --deployment-type production \
                      --domain gitlab.example.com \
                      --ssh-port 2222 \
                      --smtp-address smtp.gmail.com \
                      --smtp-user user@gmail.com \
                      --smtp-password 'secret' \
                      --email-from gitlab@example.com
"""

import argparse
import os
import sys
import secrets
import string
import subprocess
from pathlib import Path
from typing import Dict

# Colors for output
class Colors:
    RED = '\033[0;31m'
    GREEN = '\033[0;32m'
    YELLOW = '\033[1;33m'
    BLUE = '\033[0;34m'
    CYAN = '\033[0;36m'
    NC = '\033[0m'  # No Color

def print_header(text: str):
    print(f"\n{Colors.CYAN}{'=' * 76}{Colors.NC}")
    print(f"{Colors.CYAN}{text}{Colors.NC}")
    print(f"{Colors.CYAN}{'=' * 76}{Colors.NC}\n")

def print_info(text: str):
    print(f"{Colors.BLUE}ℹ{Colors.NC} {text}")

def print_success(text: str):
    print(f"{Colors.GREEN}✓{Colors.NC} {text}")

def print_warning(text: str):
    print(f"{Colors.YELLOW}⚠{Colors.NC} {text}")

def print_error(text: str):
    print(f"{Colors.RED}✗{Colors.NC} {text}")

def generate_password(length: int = 25) -> str:
    """Generate a secure random password."""
    # Exclude shell metacharacters and quotes — they break shell and .env parsing
    alphabet = string.ascii_letters + string.digits + "!@#%^&*()-_=+[]{}:,.?"
    return ''.join(secrets.choice(alphabet) for _ in range(length))

def prompt_input(prompt: str, default: str = "") -> str:
    """Prompt for input with optional default."""
    if default:
        response = input(f"{prompt} [{default}]: ").strip()
        return response if response else default
    return input(f"{prompt}: ").strip()

def prompt_password(prompt: str) -> str:
    """Prompt for password (hidden input)."""
    import getpass
    return getpass.getpass(f"{prompt}: ")

def prompt_yes_no(prompt: str, default: str = "no") -> bool:
    """Prompt for yes/no question."""
    response = prompt_input(prompt, default).lower()
    return response in ['yes', 'y']

class SetupWizard:
    def __init__(self, script_dir: Path):
        self.script_dir = script_dir
        self.config: Dict[str, str] = {}
        
    def run(self, args: argparse.Namespace):
        """Run the setup wizard."""
        # Welcome screen
        if not args.non_interactive:
            os.system('clear' if os.name == 'posix' else 'cls')
            print_header("GitLab CE Setup Wizard")
            print("Welcome! This wizard will help you configure GitLab for your environment.\n")
            print("Deployment types:")
            print("  • sandbox    - Local development and testing (minimal security)")
            print("  • staging    - Pre-production environment (production-like security)")
            print("  • production - Live production server (maximum security)")
            print()
        
        # Check if .env exists
        env_file = self.script_dir / '.env'
        if env_file.exists() and not args.force:
            print_warning(".env file already exists!")
            if not args.non_interactive:
                if not prompt_yes_no("Do you want to overwrite it?", "no"):
                    print_info("Setup cancelled. Existing .env file preserved.")
                    sys.exit(0)
            else:
                print_error("Use --force to overwrite existing .env file")
                sys.exit(1)
        
        # Get deployment type
        self.config['deployment_type'] = self.get_deployment_type(args)
        print_success(f"Deployment type: {self.config['deployment_type']}")
        
        # Configure based on deployment type
        if self.config['deployment_type'] == 'sandbox':
            self.configure_sandbox(args)
        else:
            self.configure_production(args)
        
        # Generate .env file
        self.generate_env_file()
        
        # Create directories
        self.create_directories()
        
        # Run validation if available
        self.run_validation()
        
        # Show next steps
        self.show_next_steps()
    
    def get_deployment_type(self, args: argparse.Namespace) -> str:
        """Get deployment type from args or prompt."""
        if args.deployment_type:
            if args.deployment_type not in ['sandbox', 'staging', 'production']:
                print_error(f"Invalid deployment type: {args.deployment_type}")
                sys.exit(1)
            return args.deployment_type
        
        # Interactive prompt
        print_header("Step 1: Select Deployment Type")
        print("Which type of deployment are you setting up?")
        print("  1) Sandbox/Development (quick local testing)")
        print("  2) Staging (pre-production testing)")
        print("  3) Production (live server)")
        print()
        
        while True:
            choice = input("Enter choice (1-3): ").strip()
            if choice == '1':
                return 'sandbox'
            elif choice == '2':
                return 'staging'
            elif choice == '3':
                return 'production'
            print_error("Invalid choice. Please enter 1, 2, or 3.")
    
    def configure_sandbox(self, args: argparse.Namespace):
        """Configure sandbox deployment."""
        if not args.non_interactive:
            print_header("Sandbox Configuration")
            print_info("Sandbox mode uses sensible defaults for local testing.")
            print_info("Most settings will be auto-configured.")
            print()
        
        self.config['domain'] = 'gitlab.sandbox.local'
        self.config['ssh_port'] = '2224'
        self.config['http_port'] = '8080'
        self.config['https_port'] = '8443'
        self.config['smtp_enable'] = 'false'
        self.config['use_ssl'] = 'false'
        
        print_success(f"Using domain: {self.config['domain']}")
        print_success(f"Ports: HTTP={self.config['http_port']}, HTTPS={self.config['https_port']}, SSH={self.config['ssh_port']}")
        print_info("Email disabled for sandbox mode")
    
    def configure_production(self, args: argparse.Namespace):
        """Configure staging or production deployment."""
        deployment = self.config['deployment_type']
        
        # Domain configuration
        if not args.non_interactive:
            print_header("Step 2: Domain Configuration")
        
        if args.domain:
            self.config['domain'] = args.domain
        else:
            self.config['domain'] = prompt_input("Enter your GitLab domain (e.g., gitlab.example.com)")
        
        # Port configuration
        if not args.non_interactive:
            print_header("Step 3: Port Configuration")
            print_info("Standard ports: HTTP=80, HTTPS=443, SSH=22")
            print_warning("If port 22 is used by host SSH, use an alternate port (e.g., 2222)")
            print()
        
        self.config['http_port'] = str(args.http_port) if args.http_port else prompt_input("HTTP port", "80")
        self.config['https_port'] = str(args.https_port) if args.https_port else prompt_input("HTTPS port", "443")
        self.config['ssh_port'] = str(args.ssh_port) if args.ssh_port else prompt_input("SSH port", "2222")
        
        # SSL configuration
        if not args.non_interactive:
            print_header("Step 4: SSL/TLS Configuration")
        
        if args.no_ssl:
            self.config['use_ssl'] = 'false'
            print_warning("SSL disabled (NOT RECOMMENDED for production)")
        else:
            has_ssl = args.ssl or (not args.non_interactive and prompt_yes_no("Do you have valid SSL certificates?", "yes"))
            self.config['use_ssl'] = 'true' if has_ssl else 'false'
            
            if not has_ssl and not args.non_interactive:
                print_warning(f"SSL certificates are REQUIRED for {deployment} deployment")
                if not prompt_yes_no("Continue without SSL (NOT RECOMMENDED)?", "no"):
                    print_error("Setup cancelled. Please obtain SSL certificates first.")
                    sys.exit(1)
        
        # Email configuration
        if not args.non_interactive:
            print_header("Step 5: Email Configuration")
        
        if args.no_smtp:
            self.config['smtp_enable'] = 'false'
            print_warning("Email disabled. Users won't receive notifications.")
        else:
            configure_smtp = args.smtp_address or (not args.non_interactive and prompt_yes_no("Configure email (SMTP)?", "yes"))
            
            if configure_smtp:
                self.config['smtp_enable'] = 'true'
                self.config['smtp_address'] = args.smtp_address or prompt_input("SMTP server address (e.g., smtp.gmail.com)")
                self.config['smtp_port'] = str(args.smtp_port) if args.smtp_port else prompt_input("SMTP port", "587")
                self.config['smtp_user'] = args.smtp_user or prompt_input("SMTP username")
                if args.smtp_password:
                    self.config['smtp_password'] = args.smtp_password
                elif not args.non_interactive:
                    self.config['smtp_password'] = prompt_password("SMTP password")
                else:
                    print_error("--smtp-password is required when configuring SMTP in non-interactive mode")
                    sys.exit(1)
                self.config['smtp_domain'] = args.smtp_domain or prompt_input("SMTP domain", self.config['domain'])
                self.config['email_from'] = args.email_from or prompt_input("Email 'From' address", f"gitlab@{self.config['domain']}")
                self.config['email_reply_to'] = args.email_reply_to or prompt_input("Email 'Reply-To' address", f"noreply@{self.config['domain']}")
            else:
                self.config['smtp_enable'] = 'false'
        
        # Generate secure passwords for production
        if deployment == 'production':
            if not args.non_interactive:
                print_header("Step 6: Security Settings")
                print_info("Generate secure passwords for internal services...")
            
            self.config['root_password'] = args.root_password or generate_password()
            
            if not args.non_interactive and not args.root_password:
                print_success("Passwords generated")
                print_warning("Save these passwords in a secure location!")
                print()
                print(f"Root password: {self.config['root_password']}")
                print()
                input("Press Enter to continue...")
    
    def generate_env_file(self):
        """Generate .env file with configuration."""
        print_header("Generating Configuration")
        
        env_file = self.script_dir / '.env'
        
        with open(env_file, 'w') as f:
            f.write("# " + "=" * 76 + "\n")
            f.write("# GitLab Configuration - Generated by setup-wizard.py\n")
            f.write("# " + "=" * 76 + "\n")
            f.write(f"# Deployment Type: {self.config['deployment_type']}\n")
            from datetime import datetime
            f.write(f"# Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
            f.write("# \n")
            f.write("# SECURITY WARNING: This file contains sensitive credentials!\n")
            f.write("# - Never commit this file to version control\n")
            f.write("# - Set permissions: chmod 600 .env\n")
            f.write("# - Back up securely in encrypted storage\n")
            f.write("# " + "=" * 76 + "\n\n")
            
            f.write("# " + "-" * 76 + "\n")
            f.write("# Basic Configuration\n")
            f.write("# " + "-" * 76 + "\n")
            f.write(f"GITLAB_DOMAIN=\"{self.config['domain']}\"\n")
            f.write(f"GITLAB_SSH_PORT={self.config['ssh_port']}\n\n")
            
            f.write("# " + "-" * 76 + "\n")
            f.write("# Email Configuration\n")
            f.write("# " + "-" * 76 + "\n")
            f.write(f"GITLAB_SMTP_ENABLE={self.config['smtp_enable']}\n")
            
            if self.config['smtp_enable'] == 'true':
                f.write(f"GITLAB_SMTP_ADDRESS=\"{self.config.get('smtp_address', '')}\"\n")
                f.write(f"GITLAB_SMTP_PORT={self.config.get('smtp_port', '587')}\n")
                f.write(f"GITLAB_SMTP_USER=\"{self.config.get('smtp_user', '')}\"\n")
                f.write(f"GITLAB_SMTP_PASSWORD=\"{self.config.get('smtp_password', '')}\"\n")
                f.write(f"GITLAB_SMTP_DOMAIN=\"{self.config.get('smtp_domain', '')}\"\n")
                f.write(f"GITLAB_EMAIL_FROM=\"{self.config.get('email_from', '')}\"\n")
                f.write(f"GITLAB_EMAIL_REPLY_TO=\"{self.config.get('email_reply_to', '')}\"\n")
            
            if self.config['deployment_type'] == 'production':
                f.write("\n# " + "-" * 76 + "\n")
                f.write("# Security (Production)\n")
                f.write("# " + "-" * 76 + "\n")
                f.write("# Initial root password - CHANGE THIS after first login!\n")
                f.write(f"GITLAB_ROOT_PASSWORD=\"{self.config.get('root_password', '')}\"\n")
            
            f.write("\n# " + "-" * 76 + "\n")
            f.write("# Backup Configuration (Configure after deployment)\n")
            f.write("# " + "-" * 76 + "\n")
            f.write("# BACKUP_ENCRYPTION_KEY=\n")
            f.write("# BACKUP_S3_BUCKET=\n")
            f.write("# BACKUP_S3_REGION=\n")
            f.write("# BACKUP_S3_ACCESS_KEY=\n")
            f.write("# BACKUP_S3_SECRET_KEY=\n\n")
            
            f.write("# " + "-" * 76 + "\n")
            f.write("# Monitoring (Optional)\n")
            f.write("# " + "-" * 76 + "\n")
            f.write("# GRAFANA_PASSWORD=\n")
            f.write("# PROMETHEUS_RETENTION=15d\n")
        
        # Set secure permissions
        env_file.chmod(0o600)
        print_success(".env file created with secure permissions (600)")
    
    def create_directories(self):
        """Create necessary directories."""
        print_info("Creating required directories...")
        
        if self.config['deployment_type'] == 'sandbox':
            dirs = ['gitlab-local/data', 'gitlab-local/config', 'gitlab-local/logs', 'gitlab-local/ssl']
        else:
            dirs = ['config/ssl', 'backups']
        
        for dir_path in dirs:
            full_path = self.script_dir / dir_path
            full_path.mkdir(parents=True, exist_ok=True)
        
        print_success("Directories created")
    
    def run_validation(self):
        """Run validation script if available."""
        print_header("Validating Configuration")
        
        validate_script = self.script_dir / 'validate-deployment.py'
        if validate_script.exists():
            print_info("Running validation script...")
            try:
                subprocess.run([str(validate_script), self.config['deployment_type']], 
                             cwd=self.script_dir, check=False)
            except Exception as e:
                print_warning(f"Validation script failed: {e}")
        else:
            print_warning("Validation script not found. Skipping validation.")
    
    def show_next_steps(self):
        """Show next steps based on deployment type."""
        print_header("Setup Complete!")
        
        print("Configuration files created:")
        print_success(".env (chmod 600)")
        
        if self.config['deployment_type'] == 'sandbox':
            print()
            print_header("Next Steps")
            print("1. Start GitLab:")
            print(f"   {Colors.GREEN}docker-compose -f docker-compose.sandbox.yml up -d{Colors.NC}")
            print()
            print("2. Wait for GitLab to start (5-10 minutes first time)")
            print()
            print("3. Access GitLab:")
            print(f"   {Colors.GREEN}http://localhost:8080{Colors.NC}")
            print()
            print_info("See QUICKSTART-SANDBOX.md for detailed instructions")
        
        elif self.config['deployment_type'] == 'staging':
            print()
            print_header("Next Steps")
            print("1. Verify SSL certificates are in place:")
            print(f"   {Colors.YELLOW}ls -l config/ssl/{self.config['domain']}.*{Colors.NC}")
            print()
            print("2. Start GitLab:")
            print(f"   {Colors.GREEN}docker-compose -f docker-compose.staging.yml up -d{Colors.NC}")
            print()
            print("3. Access GitLab:")
            print(f"   {Colors.GREEN}https://{self.config['domain']}{Colors.NC}")
        
        else:  # production
            print()
            print_warning("IMPORTANT: Production deployment requires additional steps!")
            print()
            print("Before starting GitLab:")
            print()
            print("1. ✓ Verify SSL certificates")
            print("2. ✓ Configure firewall")
            print("3. ✓ Install fail2ban")
            print("4. ✓ Review SECURITY.md checklist")
            print()
            print("Then start GitLab:")
            print(f"   {Colors.GREEN}docker-compose -f docker-compose.production.yml up -d{Colors.NC}")
            print()
            print_info("See QUICKSTART-PRODUCTION.md for complete checklist")
        
        print()
        print_success("Setup wizard completed successfully!")
        print()

def main():
    parser = argparse.ArgumentParser(
        description='GitLab Setup Wizard - Interactive and non-interactive configuration',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Interactive mode
  ./setup-wizard.py
  
  # Non-interactive sandbox
  ./setup-wizard.py --deployment-type sandbox --non-interactive
  
  # Non-interactive production with full config
  ./setup-wizard.py --deployment-type production \\
                    --domain gitlab.example.com \\
                    --ssh-port 2222 \\
                    --smtp-address smtp.gmail.com \\
                    --smtp-user gitlab@example.com \\
                    --smtp-password 'secret' \\
                    --email-from gitlab@example.com \\
                    --non-interactive
        """
    )
    
    parser.add_argument('--deployment-type', choices=['sandbox', 'staging', 'production'],
                       help='Deployment type')
    parser.add_argument('--domain', help='GitLab domain name')
    parser.add_argument('--ssh-port', type=int, default=2222, help='SSH port (default: 2222)')
    parser.add_argument('--http-port', type=int, default=80, help='HTTP port (default: 80)')
    parser.add_argument('--https-port', type=int, default=443, help='HTTPS port (default: 443)')
    
    # SSL options
    parser.add_argument('--ssl', action='store_true', help='SSL certificates available')
    parser.add_argument('--no-ssl', action='store_true', help='Disable SSL (not recommended)')
    
    # SMTP options
    parser.add_argument('--smtp-address', help='SMTP server address')
    parser.add_argument('--smtp-port', type=int, default=587, help='SMTP port (default: 587)')
    parser.add_argument('--smtp-user', help='SMTP username')
    parser.add_argument('--smtp-password', help='SMTP password')
    parser.add_argument('--smtp-domain', help='SMTP domain')
    parser.add_argument('--email-from', help='Email From address')
    parser.add_argument('--email-reply-to', help='Email Reply-To address')
    parser.add_argument('--no-smtp', action='store_true', help='Disable email')
    
    # Security options
    parser.add_argument('--root-password', help='Initial root password (production only)')
    
    # General options
    parser.add_argument('--non-interactive', action='store_true',
                       help='Non-interactive mode (requires all necessary arguments)')
    parser.add_argument('--force', action='store_true',
                       help='Overwrite existing .env file without prompting')
    
    args = parser.parse_args()
    
    # Validate non-interactive mode requirements
    if args.non_interactive and not args.deployment_type:
        parser.error("--deployment-type is required in non-interactive mode")
    
    if args.non_interactive and args.deployment_type in ['staging', 'production'] and not args.domain:
        parser.error("--domain is required for staging/production in non-interactive mode")
    
    # Get script directory
    script_dir = Path(__file__).parent.absolute()
    
    # Run wizard
    wizard = SetupWizard(script_dir)
    try:
        wizard.run(args)
    except KeyboardInterrupt:
        print()
        print_warning("Setup cancelled by user")
        sys.exit(130)
    except Exception as e:
        print_error(f"Setup failed: {e}")
        if '--debug' in sys.argv:
            raise
        sys.exit(1)

if __name__ == '__main__':
    main()
