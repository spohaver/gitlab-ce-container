# Script Automation Guide

This repository provides both **Bash** and **Python** versions of key scripts, supporting both interactive and non-interactive usage for automation and CI/CD pipelines.

## Available Scripts

| Script | Python Version | Purpose |
|--------|----------------|---------||
| Setup Wizard | `setup-wizard.py` | Configure GitLab deployment (interactive & automated) |
| Validation | `validate-deployment.py` | Pre-deployment checks |
| Backup | `scripts/backup.sh` | Automated backup with offsite sync |
| Restore | `scripts/restore.sh` | Restore from backup |
| Update | `scripts/update.sh` | Safe GitLab update procedure |

## Why Python?

Python scripts offer several advantages:

✅ **Non-interactive mode** - Full CI/CD automation support  
✅ **Command-line arguments** - Scriptable with all options  
✅ **Better error handling** - Structured exception handling  
✅ **Cross-platform** - Works on Windows, macOS, Linux  
✅ **Programmatic usage** - Can be imported as Python modules  
✅ **JSON output** - Machine-readable results  

**Python 3.6+** is required for the setup and validation scripts.

## Setup Wizard

### Interactive Mode

```bash
./setup-wizard.py
```

### Non-Interactive Mode (Python Only)

#### Sandbox Deployment
```bash
./setup-wizard.py --deployment-type sandbox --non-interactive
```

#### Staging Deployment
```bash
./setup-wizard.py \
  --deployment-type staging \
  --domain gitlab-staging.example.com \
  --ssh-port 2222 \
  --smtp-address smtp.gmail.com \
  --smtp-user gitlab@example.com \
  --smtp-password "${SMTP_PASSWORD}" \
  --email-from gitlab@example.com \
  --non-interactive
```

#### Production Deployment
```bash
./setup-wizard.py \
  --deployment-type production \
  --domain gitlab.example.com \
  --ssh-port 2222 \
  --smtp-address smtp.gmail.com \
  --smtp-user gitlab@example.com \
  --smtp-password "${SMTP_PASSWORD}" \
  --smtp-domain example.com \
  --email-from gitlab@example.com \
  --email-reply-to noreply@example.com \
  --root-password "${ROOT_PASSWORD}" \
  --ssl \
  --non-interactive \
  --force
```

### All Setup Wizard Options

```
Options:
  --deployment-type {sandbox,staging,production}
  --domain DOMAIN              GitLab domain name
  --ssh-port PORT              SSH port (default: 2222)
  --http-port PORT             HTTP port (default: 80)
  --https-port PORT            HTTPS port (default: 443)
  
  SSL Options:
  --ssl                        SSL certificates available
  --no-ssl                     Disable SSL (not recommended)
  
  SMTP Options:
  --smtp-address ADDRESS       SMTP server address
  --smtp-port PORT             SMTP port (default: 587)
  --smtp-user USER             SMTP username
  --smtp-password PASSWORD     SMTP password
  --smtp-domain DOMAIN         SMTP domain
  --email-from EMAIL           Email From address
  --email-reply-to EMAIL       Email Reply-To address
  --no-smtp                    Disable email
  
  Security:
  --root-password PASSWORD     Initial root password (production only)
  
  General:
  --non-interactive            Non-interactive mode
  --force                      Overwrite existing .env
```

## Validation Script

### Interactive Mode

```bash
# Auto-detect deployment type from .env
./validate-deployment.py

# Specify deployment type
./validate-deployment.py --deployment-type production
```

### Non-Interactive Mode (CI/CD)

```bash
# Validate with exit codes for automation
./validate-deployment.py --deployment-type production --non-interactive

# Check exit code
if [ $? -eq 0 ]; then
  echo "Validation passed"
else
  echo "Validation failed"
  exit 1
fi
```

### Skip Specific Checks

```bash
# Skip Docker and firewall checks (useful in containers)
./validate-deployment.py --skip-checks docker,firewall

# Skip SSL checks for testing
./validate-deployment.py --deployment-type sandbox --skip-checks ssl
```

### Exit Codes

- **0**: All checks passed
- **1**: Warnings found (can proceed with caution)
- **2**: Errors found (should not deploy)
- **130**: Cancelled by user

## CI/CD Integration Examples

### GitHub Actions

```yaml
name: Deploy GitLab

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup GitLab Configuration
        env:
          SMTP_PASSWORD: ${{ secrets.SMTP_PASSWORD }}
          ROOT_PASSWORD: ${{ secrets.ROOT_PASSWORD }}
        run: |
          ./setup-wizard.py \
            --deployment-type production \
            --domain gitlab.example.com \
            --smtp-address smtp.gmail.com \
            --smtp-user gitlab@example.com \
            --smtp-password "$SMTP_PASSWORD" \
            --root-password "$ROOT_PASSWORD" \
            --non-interactive \
            --force
      
      - name: Validate Configuration
        run: |
          ./validate-deployment.py \
            --deployment-type production \
            --non-interactive \
            --skip-checks firewall,ports
      
      - name: Deploy GitLab
        run: |
          docker-compose -f docker-compose.production.yml up -d
```

### GitLab CI

```yaml
deploy:
  stage: deploy
  script:
    - ./setup-wizard.py
        --deployment-type production
        --domain gitlab.example.com
        --smtp-address $SMTP_ADDRESS
        --smtp-user $SMTP_USER
        --smtp-password $SMTP_PASSWORD
        --root-password $ROOT_PASSWORD
        --non-interactive
        --force
    
    - ./validate-deployment.py
        --deployment-type production
        --non-interactive
    
    - docker-compose -f docker-compose.production.yml up -d
  only:
    - main
```

### Jenkins Pipeline

```groovy
pipeline {
    agent any
    
    environment {
        SMTP_PASSWORD = credentials('smtp-password')
        ROOT_PASSWORD = credentials('root-password')
    }
    
    stages {
        stage('Configure') {
            steps {
                sh '''
                    ./setup-wizard.py \
                      --deployment-type production \
                      --domain gitlab.example.com \
                      --smtp-password "${SMTP_PASSWORD}" \
                      --root-password "${ROOT_PASSWORD}" \
                      --non-interactive \
                      --force
                '''
            }
        }
        
        stage('Validate') {
            steps {
                sh './validate-deployment.py --non-interactive'
            }
        }
        
        stage('Deploy') {
            steps {
                sh 'docker-compose -f docker-compose.production.yml up -d'
            }
        }
    }
}
```

### Ansible Playbook

```yaml
---
- name: Deploy GitLab
  hosts: gitlab_servers
  vars:
    gitlab_domain: gitlab.example.com
    smtp_password: "{{ vault_smtp_password }}"
    root_password: "{{ vault_root_password }}"
  
  tasks:
    - name: Clone GitLab repository
      git:
        repo: https://github.com/yourusername/gitlab-server.git
        dest: /opt/gitlab-server
    
    - name: Setup GitLab configuration
      command:
        cmd: >
          ./setup-wizard.py
          --deployment-type production
          --domain {{ gitlab_domain }}
          --smtp-password {{ smtp_password }}
          --root-password {{ root_password }}
          --non-interactive
          --force
        chdir: /opt/gitlab-server
    
    - name: Validate configuration
      command:
        cmd: ./validate-deployment.py --non-interactive
        chdir: /opt/gitlab-server
      register: validation
      failed_when: validation.rc > 1  # Allow warnings (rc=1)
    
    - name: Deploy GitLab
      docker_compose:
        project_src: /opt/gitlab-server
        files: docker-compose.production.yml
        state: present
```

### Terraform

```hcl
resource "null_resource" "gitlab_setup" {
  connection {
    type        = "ssh"
    host        = aws_instance.gitlab.public_ip
    user        = "ubuntu"
    private_key = file("~/.ssh/id_rsa")
  }
  
  provisioner "remote-exec" {
    inline = [
      "cd /opt/gitlab-server",
      "./setup-wizard.py --deployment-type production --domain ${var.gitlab_domain} --smtp-password ${var.smtp_password} --non-interactive --force",
      "./validate-deployment.py --non-interactive",
      "docker-compose -f docker-compose.production.yml up -d"
    ]
  }
}
```

## Environment Variables

For security, use environment variables instead of command-line arguments:

```bash
# Set environment variables
export GITLAB_DOMAIN=gitlab.example.com
export GITLAB_SMTP_PASSWORD='secret'
export GITLAB_ROOT_PASSWORD='supersecret'

# Use in script (Python reads environment variables too)
./setup-wizard.py \
  --deployment-type production \
  --smtp-password "${GITLAB_SMTP_PASSWORD}" \
  --root-password "${GITLAB_ROOT_PASSWORD}" \
  --non-interactive
```

## Docker Integration

Run setup from within Docker:

```dockerfile
FROM python:3.9-slim

WORKDIR /app
COPY . .

RUN chmod +x setup-wizard.py validate-deployment.py

ENTRYPOINT ["./setup-wizard.py"]
CMD ["--non-interactive"]
```

Build and run:
```bash
docker build -t gitlab-setup .
docker run -e GITLAB_DOMAIN=example.com gitlab-setup \
  --deployment-type production \
  --smtp-password "${SMTP_PASSWORD}"
```

## Testing Automation

```bash
#!/bin/bash
# test-deployment.sh - Automated deployment testing

set -e

echo "Setting up sandbox environment..."
./setup-wizard.py --deployment-type sandbox --non-interactive --force

echo "Validating configuration..."
./validate-deployment.py --deployment-type sandbox --non-interactive

if [ $? -eq 0 ]; then
  echo "Starting GitLab..."
  docker-compose -f docker-compose.sandbox.yml up -d
  
  echo "Waiting for GitLab to be ready..."
  sleep 60
  
  echo "Running health checks..."
  curl -f http://localhost:8080 || exit 1
  
  echo "Deployment test successful!"
else
  echo "Validation failed!"
  exit 1
fi
```

## Programmatic Usage (Python)

You can also import and use the Python scripts programmatically:

```python
#!/usr/bin/env python3
from pathlib import Path
from setup_wizard import SetupWizard

# Configure programmatically
wizard = SetupWizard(Path.cwd())
wizard.config = {
    'deployment_type': 'production',
    'domain': 'gitlab.example.com',
    'smtp_enable': 'true',
    # ... more config
}

wizard.generate_env_file()
wizard.create_directories()
```

## Tips for Automation

### 1. Store Secrets Securely
- Use secret management (Vault, AWS Secrets Manager)
- Never commit secrets to Git
- Use environment variables or secret files

### 2. Validate Before Deploy
Always run validation before deployment:
```bash
./validate-deployment.py --non-interactive || exit 1
```

### 3. Use --force Carefully
Only use `--force` in automation when you're sure:
```bash
./setup-wizard.py --force  # Overwrites .env without asking
```

### 4. Check Exit Codes
```bash
./validate-deployment.py
EXIT_CODE=$?
if [ $EXIT_CODE -eq 2 ]; then
  echo "Critical errors found"
  exit 1
fi
```

### 5. Skip Unnecessary Checks
In containers or CI/CD, skip checks that don't apply:
```bash
./validate-deployment.py --skip-checks docker,firewall,ports
```

## Troubleshooting

### "Permission Denied"
```bash
chmod +x setup-wizard.py validate-deployment.py
```

### "Python not found"
```bash
# Install Python 3
sudo apt install python3

# Or use bash versions
./setup-wizard.py
```

### "Missing required argument"
In non-interactive mode, all required arguments must be provided:
```bash
./setup-wizard.py --non-interactive --deployment-type production --domain gitlab.example.com
```

## Comparison: Bash vs Python

| Feature | Bash | Python |
|---------|------|--------|
| Interactive mode | ✅ | ✅ |
| Non-interactive mode | ❌ | ✅ |
| Command-line arguments | Limited | Full |
| Cross-platform | Linux/macOS | All platforms |
| Programmatic usage | ❌ | ✅ |
| JSON output | ❌ | ✅ |
| Dependencies | Bash, basic Unix tools | Python 3.6+ |
| Speed | Fast | Slightly slower |
| Error handling | Basic | Advanced |

## Recommendation

- **Interactive use**: Either version (Python is more feature-rich)
- **CI/CD automation**: Use Python versions
- **Ansible/Terraform**: Use Python versions
- **Quick manual setup**: Bash versions work great
- **Windows**: Use Python versions

---

Both versions are maintained and produce identical results. Choose based on your needs!
