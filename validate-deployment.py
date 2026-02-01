#!/usr/bin/env python3
"""
GitLab Deployment Validation Script
Checks configuration, security, and system requirements before deployment.

Usage:
    # Interactive validation (auto-detect type)
    ./validate-deployment.py
    
    # Validate specific deployment type
    ./validate-deployment.py --deployment-type production
    
    # Non-interactive mode (for CI/CD)
    ./validate-deployment.py --deployment-type production --non-interactive
    
    # Skip specific checks
    ./validate-deployment.py --skip-checks docker,firewall
"""

import argparse
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path
from typing import List, Optional, Tuple

# Exit codes
EXIT_SUCCESS = 0
EXIT_WARNING = 1
EXIT_ERROR = 2

class Colors:
    RED = '\033[0;31m'
    GREEN = '\033[0;32m'
    YELLOW = '\033[1;33m'
    BLUE = '\033[0;34m'
    CYAN = '\033[0;36m'
    NC = '\033[0m'

class ValidationStats:
    def __init__(self):
        self.passed = 0
        self.warnings = 0
        self.errors = 0

class Validator:
    def __init__(self, script_dir: Path, deployment_type: Optional[str], skip_checks: List[str]):
        self.script_dir = script_dir
        self.deployment_type = deployment_type or self.detect_deployment_type()
        self.skip_checks = skip_checks
        self.stats = ValidationStats()
        
    def detect_deployment_type(self) -> str:
        """Auto-detect deployment type from .env file."""
        env_file = self.script_dir / '.env'
        if env_file.exists():
            content = env_file.read_text()
            if 'sandbox' in content.lower():
                return 'sandbox'
            elif 'staging' in content.lower():
                return 'staging'
            elif 'production' in content.lower():
                return 'production'
        return 'sandbox'  # Default
    
    def print_header(self, text: str):
        print(f"\n{Colors.CYAN}{'═' * 63}{Colors.NC}")
        print(f"{Colors.CYAN}{text}{Colors.NC}")
        print(f"{Colors.CYAN}{'═' * 63}{Colors.NC}\n")
    
    def print_check(self, text: str):
        print(f"{Colors.BLUE}[CHECK]{Colors.NC} {text}")
    
    def print_pass(self, text: str):
        print(f"{Colors.GREEN}  ✓{Colors.NC} {text}")
        self.stats.passed += 1
    
    def print_warn(self, text: str):
        print(f"{Colors.YELLOW}  ⚠{Colors.NC} {text}")
        self.stats.warnings += 1
    
    def print_error(self, text: str):
        print(f"{Colors.RED}  ✗{Colors.NC} {text}")
        self.stats.errors += 1
    
    def print_info(self, text: str):
        print(f"{Colors.BLUE}    ℹ{Colors.NC} {text}")
    
    def run_command(self, cmd: List[str], capture=True) -> Tuple[int, str]:
        """Run a command and return exit code and output."""
        try:
            if capture:
                result = subprocess.run(cmd, capture_output=True, text=True, timeout=5)
                return result.returncode, result.stdout
            else:
                return subprocess.run(cmd, timeout=5).returncode, ""
        except (subprocess.TimeoutExpired, FileNotFoundError):
            return 1, ""
    
    def should_skip(self, check_name: str) -> bool:
        """Check if a specific check should be skipped."""
        return check_name in self.skip_checks
    
    def check_docker(self):
        """Check Docker installation and status."""
        if self.should_skip('docker'):
            return
            
        self.print_check("Docker installation")
        
        if shutil.which('docker'):
            returncode, output = self.run_command(['docker', '--version'])
            if returncode == 0:
                version = output.split()[2].rstrip(',')
                self.print_pass(f"Docker installed: {version}")
                
                # Check if Docker daemon is running
                returncode, _ = self.run_command(['docker', 'ps'])
                if returncode == 0:
                    self.print_pass("Docker daemon is running")
                else:
                    self.print_error("Docker daemon is not running")
                    self.print_info("Start Docker: sudo systemctl start docker")
            else:
                self.print_error("Docker command failed")
        else:
            self.print_error("Docker is not installed")
            self.print_info("Install Docker: https://docs.docker.com/engine/install/")
    
    def check_docker_compose(self):
        """Check Docker Compose installation."""
        if self.should_skip('docker-compose'):
            return
            
        self.print_check("Docker Compose installation")
        
        # Check for docker compose (v2)
        returncode, output = self.run_command(['docker', 'compose', 'version'])
        if returncode == 0:
            version = output.split()[3] if len(output.split()) > 3 else "unknown"
            self.print_pass(f"Docker Compose installed: {version}")
        elif shutil.which('docker-compose'):
            # Check for standalone docker-compose
            returncode, output = self.run_command(['docker-compose', '--version'])
            if returncode == 0:
                version = output.split()[2].rstrip(',')
                self.print_pass(f"Docker Compose (standalone) installed: {version}")
        else:
            self.print_error("Docker Compose is not installed")
            self.print_info("Install: https://docs.docker.com/compose/install/")
    
    def check_system_resources(self):
        """Check system resources (RAM, disk space)."""
        if self.should_skip('resources'):
            return
            
        self.print_check("System resources")
        
        # Check RAM
        try:
            with open('/proc/meminfo', 'r') as f:
                for line in f:
                    if line.startswith('MemTotal:'):
                        total_kb = int(line.split()[1])
                        total_gb = total_kb // (1024 * 1024)
                        if total_gb >= 8:
                            self.print_pass(f"Sufficient RAM: {total_gb}GB")
                        elif total_gb >= 4:
                            self.print_warn(f"Low RAM: {total_gb}GB (8GB+ recommended)")
                            self.print_info("GitLab may run slowly or experience issues")
                        else:
                            self.print_error(f"Insufficient RAM: {total_gb}GB (minimum 4GB)")
                        break
        except FileNotFoundError:
            self.print_info("Cannot check RAM (not on Linux)")
        
        # Check disk space
        stat = os.statvfs(self.script_dir)
        available_gb = (stat.f_bavail * stat.f_frsize) // (1024**3)
        if available_gb >= 50:
            self.print_pass(f"Sufficient disk space: {available_gb}GB available")
        elif available_gb >= 20:
            self.print_warn(f"Low disk space: {available_gb}GB available (50GB+ recommended)")
        else:
            self.print_error(f"Insufficient disk space: {available_gb}GB (minimum 20GB)")
    
    def check_env_file(self):
        """Check .env file exists and has correct permissions."""
        if self.should_skip('env'):
            return
            
        self.print_check("Environment configuration (.env file)")
        
        env_file = self.script_dir / '.env'
        if not env_file.exists():
            self.print_error(".env file not found")
            self.print_info("Run ./setup-wizard.py to generate configuration")
            return
        
        self.print_pass(".env file exists")
        
        # Check file permissions
        perms = oct(env_file.stat().st_mode)[-3:]
        if perms == '600':
            self.print_pass("Secure permissions (600)")
        else:
            self.print_warn(f"Insecure permissions: {perms} (should be 600)")
            self.print_info("Fix with: chmod 600 .env")
        
        # Check for example/placeholder values
        content = env_file.read_text()
        if 'example.com' in content:
            self.print_warn("Contains example.com domain")
            self.print_info("Update GITLAB_DOMAIN in .env file")
        
        if re.search(r'PASSWORD=password\b', content, re.IGNORECASE):
            self.print_warn("May contain placeholder passwords")
            self.print_info("Verify all passwords are properly configured")
        
        # Check required variables
        if 'GITLAB_DOMAIN=' in content:
            domain = re.search(r'GITLAB_DOMAIN=(.+)', content)
            if domain:
                self.print_pass(f"GITLAB_DOMAIN: {domain.group(1)}")
        else:
            self.print_error("GITLAB_DOMAIN not set")
    
    def check_ssl_certificates(self):
        """Check SSL certificates exist and are valid."""
        if self.should_skip('ssl'):
            return
            
        self.print_check("SSL/TLS certificates")
        
        if self.deployment_type == 'sandbox':
            self.print_info("SSL checks skipped for sandbox deployment")
            return
        
        # Read domain from .env
        env_file = self.script_dir / '.env'
        domain = 'gitlab.example.com'
        if env_file.exists():
            content = env_file.read_text()
            match = re.search(r'GITLAB_DOMAIN=(.+)', content)
            if match:
                domain = match.group(1).strip()
        
        ssl_dir = self.script_dir / 'config' / 'ssl'
        if not ssl_dir.exists():
            self.print_error(f"SSL directory not found: {ssl_dir}")
            self.print_info("Create with: mkdir -p config/ssl")
            return
        
        cert_file = ssl_dir / f"{domain}.crt"
        key_file = ssl_dir / f"{domain}.key"
        
        if cert_file.exists():
            self.print_pass(f"Certificate file found: {domain}.crt")
            
            # Check certificate expiration
            if shutil.which('openssl'):
                returncode, output = self.run_command([
                    'openssl', 'x509', '-enddate', '-noout', '-in', str(cert_file)
                ])
                if returncode == 0 and 'notAfter=' in output:
                    self.print_info(f"Certificate: {output.strip()}")
        else:
            self.print_error(f"Certificate file not found: {cert_file}")
            self.print_info("Obtain certificate from Let's Encrypt or commercial CA")
        
        if key_file.exists():
            self.print_pass(f"Private key file found: {domain}.key")
            
            # Check key permissions
            perms = oct(key_file.stat().st_mode)[-3:]
            if perms == '600':
                self.print_pass("Secure key permissions (600)")
            else:
                self.print_error(f"Insecure key permissions: {perms} (should be 600)")
                self.print_info(f"Fix with: chmod 600 {key_file}")
        else:
            self.print_error(f"Private key file not found: {key_file}")
    
    def check_compose_file(self):
        """Check Docker Compose file exists and configuration."""
        if self.should_skip('compose'):
            return
            
        self.print_check("Docker Compose configuration")
        
        compose_files = {
            'sandbox': 'docker-compose.sandbox.yml',
            'staging': 'docker-compose.staging.yml',
            'production': 'docker-compose.production.yml'
        }
        
        compose_file = self.script_dir / compose_files.get(self.deployment_type, 'docker-compose.yml')
        
        if not compose_file.exists():
            self.print_error(f"Compose file not found: {compose_file}")
            return
        
        self.print_pass(f"Compose file found: {compose_file.name}")
        
        # Check for :latest tag in production/staging
        if self.deployment_type in ['production', 'staging']:
            content = compose_file.read_text()
            if 'gitlab-ce:latest' in content:
                self.print_error(f"Using :latest tag in {self.deployment_type} (use pinned version)")
                self.print_info("Update image to specific version like gitlab/gitlab-ce:18.8.2-ce.0")
            else:
                self.print_pass("Using pinned version (not :latest)")
        
        # Check for port 22 conflicts
        if compose_file.exists():
            content = compose_file.read_text()
            if "'22:22'" in content or '"22:22"' in content:
                self.print_warn("Port 22 mapped (may conflict with host SSH)")
                self.print_info("Consider using alternate port like 2222:22")
    
    def check_port_availability(self):
        """Check if required ports are available."""
        if self.should_skip('ports'):
            return

        self.print_check("Port availability")

        if self.deployment_type == 'sandbox':
            ports = [8080, 8443, 2224]
        else:
            ports = [80, 443, 2222]

        # Parse /proc/net/tcp for listening ports (Linux-specific)
        listening_ports = set()
        try:
            with open('/proc/net/tcp', 'r') as f:
                next(f)  # skip header line
                for line in f:
                    fields = line.split()
                    if len(fields) < 4:
                        continue
                    state = fields[3]
                    if state != '0A':  # 0A = LISTEN
                        continue
                    hex_port = fields[1].split(':')[1]
                    listening_ports.add(int(hex_port, 16))
        except FileNotFoundError:
            self.print_info("Cannot check ports (/proc/net/tcp not available)")
            return

        for port in ports:
            if port in listening_ports:
                self.print_error(f"Port {port} is already in use")
            else:
                self.print_pass(f"Port {port} is available")
    
    def check_gitignore(self):
        """Check .gitignore has security entries."""
        if self.should_skip('gitignore'):
            return
            
        self.print_check(".gitignore security")
        
        gitignore = self.script_dir / '.gitignore'
        if not gitignore.exists():
            self.print_error(".gitignore file not found")
            return
        
        content = gitignore.read_text()
        
        # Check for critical entries
        if re.search(r'^\.env$', content, re.MULTILINE):
            self.print_pass(".env excluded from Git")
        else:
            self.print_error(".env NOT excluded from Git (will commit secrets!)")
            self.print_info("Uncomment .env in .gitignore immediately")
        
        if re.search(r'^backups/', content, re.MULTILINE):
            self.print_pass("backups/ excluded from Git")
        else:
            self.print_warn("backups/ not excluded (may commit sensitive data)")
        
        if re.search(r'^config/gitlab\.rb$', content, re.MULTILINE):
            self.print_pass("gitlab.rb excluded from Git")
        else:
            self.print_warn("gitlab.rb not excluded (may commit secrets)")
    
    def run_all_checks(self):
        """Run all validation checks."""
        os.system('clear' if os.name == 'posix' else 'cls')
        self.print_header("GitLab Deployment Validation")
        
        print(f"Validating configuration for: {self.deployment_type} deployment\n")
        
        # System checks
        self.check_docker()
        self.check_docker_compose()
        self.check_system_resources()
        print()
        
        # Configuration checks
        self.check_env_file()
        self.check_ssl_certificates()
        self.check_compose_file()
        self.check_gitignore()
        print()
        
        # Security checks
        self.check_port_availability()
        print()
    
    def print_summary(self) -> int:
        """Print validation summary and return exit code."""
        self.print_header("Validation Summary")
        
        print(f"{Colors.GREEN}Passed:  {Colors.NC} {self.stats.passed} checks")
        print(f"{Colors.YELLOW}Warnings:{Colors.NC} {self.stats.warnings} issues")
        print(f"{Colors.RED}Errors:  {Colors.NC} {self.stats.errors} critical issues")
        print()
        
        if self.stats.errors > 0:
            self.print_error("VALIDATION FAILED")
            print()
            print("Critical issues found that must be fixed before deployment.")
            print("Review the errors above and address each issue.")
            print()
            return EXIT_ERROR
        elif self.stats.warnings > 0:
            self.print_warn("VALIDATION PASSED WITH WARNINGS")
            print()
            print("Deployment can proceed, but warnings should be addressed.")
            
            if self.deployment_type == 'production':
                print()
                self.print_error("For PRODUCTION deployments, all warnings should be resolved!")
            print()
            return EXIT_WARNING
        else:
            self.print_pass("VALIDATION PASSED")
            print()
            print("All checks passed! Ready to deploy.")
            print()
            return EXIT_SUCCESS

def main():
    parser = argparse.ArgumentParser(
        description='GitLab Deployment Validation - Check configuration and requirements',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Auto-detect deployment type
  ./validate-deployment.py
  
  # Validate specific type
  ./validate-deployment.py --deployment-type production
  
  # Non-interactive (for CI/CD)
  ./validate-deployment.py --deployment-type production --non-interactive
  
  # Skip specific checks
  ./validate-deployment.py --skip-checks docker,firewall
        """
    )
    
    parser.add_argument('deployment_type', nargs='?', 
                       choices=['sandbox', 'staging', 'production'],
                       help='Deployment type to validate')
    parser.add_argument('--deployment-type', dest='deployment_type_flag',
                       choices=['sandbox', 'staging', 'production'],
                       help='Deployment type (alternative syntax)')
    parser.add_argument('--non-interactive', action='store_true',
                       help='Non-interactive mode (no prompts)')
    parser.add_argument('--skip-checks',
                       help='Comma-separated list of checks to skip')
    
    args = parser.parse_args()
    
    # Determine deployment type
    deployment_type = args.deployment_type or args.deployment_type_flag
    
    # Parse skip checks
    skip_checks = []
    if args.skip_checks:
        skip_checks = [c.strip() for c in args.skip_checks.split(',')]
    
    # Get script directory
    script_dir = Path(__file__).parent.absolute()
    
    # Run validation
    validator = Validator(script_dir, deployment_type, skip_checks)
    
    try:
        validator.run_all_checks()
        exit_code = validator.print_summary()
        
        # For production in non-interactive mode, treat warnings as errors
        if args.non_interactive and deployment_type == 'production' and exit_code == EXIT_WARNING:
            exit_code = EXIT_ERROR
        
        sys.exit(exit_code)
        
    except KeyboardInterrupt:
        print()
        print(f"{Colors.YELLOW}⚠{Colors.NC} Validation cancelled by user")
        sys.exit(130)
    except Exception as e:
        print(f"{Colors.RED}✗{Colors.NC} Validation failed: {e}")
        if '--debug' in sys.argv:
            raise
        sys.exit(EXIT_ERROR)

if __name__ == '__main__':
    main()
