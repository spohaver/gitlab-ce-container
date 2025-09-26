# GitLab CE Docker Server

This repository contains configuration and setup files for deploying GitLab Community Edition using Docker.

## Features

- Complete GitLab CE installation with Docker Compose
- Persistent data storage with Docker volumes
- Automated backup and restore scripts
- HTTPS/SSL support
- Update automation
- Extensible configuration

## Prerequisites

- Docker Engine 20.10+
- Docker Compose v2+
- 8GB+ RAM
- 50GB+ storage space
- A domain name pointed to your server (for production use)

## Quick Start

1. Clone this repository:
   ```bash
   git clone https://github.com/yourusername/gitlab-server.git
   cd gitlab-server
   ```

2. Create environment configuration:
   ```bash
   cp .env.example .env
   ```
   
3. Edit `.env` file with your specific settings:
   ```bash
   nano .env
   ```
   
4. Create necessary directories:
   ```bash
   mkdir -p config/ssl data logs backups
   ```
   
5. For SSL support, place your certificates in the `config/ssl` directory:
   ```bash
   # Example for self-signed certificates (for testing only)
   openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
     -keyout config/ssl/gitlab.key -out config/ssl/gitlab.crt
   ```

6. Make scripts executable:
   ```bash
   chmod +x scripts/*.sh
   ```

7. Start GitLab:
   ```bash
   docker-compose up -d
   ```

8. Monitor the startup process (this may take several minutes):
   ```bash
   docker logs -f gitlab
   ```

9. Access GitLab at https://your-domain.com

## Initial Login

When you first access GitLab, you'll need to set a password for the `root` user.
The initial root password can be found in the logs:

```bash
docker exec -it gitlab grep 'Password:' /etc/gitlab/initial_root_password
```

## Directory Structure

- `docker-compose.yml`: Docker Compose configuration
- `.env`: Environment variables for configuration
- `config/`: GitLab configuration files
  - `gitlab.rb.template`: Template for GitLab configuration
  - `ssl/`: SSL certificates
- `scripts/`: Utility scripts
  - `backup.sh`: Backup automation
  - `restore.sh`: Restore from backup
  - `update.sh`: Safe update script
- `data/`: Persistent data (Docker volumes mount here)
- `logs/`: GitLab and script logs
- `backups/`: GitLab backups

## Regular Maintenance

### Creating Backups

```bash
./scripts/backup.sh
```

### Restoring from a Backup

```bash
./scripts/restore.sh <backup_filename>
```

### Updating GitLab

```bash
./scripts/update.sh
```

## Security Recommendations

1. Use strong passwords for all accounts
2. Use proper SSL certificates (not self-signed) in production
3. Enable 2FA for all users
4. Regularly update GitLab to the latest version
5. Configure firewall to allow only necessary ports
6. Set up regular automated backups

## Customization

To customize GitLab configuration, edit the `.env` file and restart GitLab:

```bash
docker-compose down
docker-compose up -d
```

For more advanced customization, edit `config/gitlab.rb.template` and rebuild the configuration.

## Troubleshooting

### GitLab is slow or unresponsive

Check system resources:
```bash
docker stats gitlab
```

### Can't access GitLab web interface

Check if the container is running:
```bash
docker ps | grep gitlab
```

Check logs for errors:
```bash
docker logs gitlab
```

### Backup/restore issues

Check the log files in the `logs/` directory for detailed error messages.

## Resources

- [GitLab Docker Official Documentation](https://docs.gitlab.com/omnibus/docker/)
- [GitLab Configuration Options](https://docs.gitlab.com/omnibus/settings/configuration.html)
- [GitLab Backup and Restore](https://docs.gitlab.com/ee/raketasks/backup_restore.html)

## License

This project is licensed under the MIT License - see the LICENSE file for details.
