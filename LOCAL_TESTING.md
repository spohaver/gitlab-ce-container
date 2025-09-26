# Local GitLab CE Testing Environment

This directory contains scripts and configuration for setting up a local GitLab CE testing environment using Docker.

## Quick Start

### 1. Set up local environment

Run the setup script to create directories, generate SSL certificates, and start GitLab:

```bash
./setup-local-gitlab.sh
```

This script will:
- Create necessary directories
- Generate self-signed SSL certificates
- Add `gitlab.local` to your `/etc/hosts` file
- Start GitLab in Docker containers

### 2. Access GitLab

Once GitLab has started (which may take 5-10 minutes), you can access it at:

- http://gitlab.local:8080
- or using your local IP: http://YOUR_IP:8080

### 3. Get initial root password

To retrieve the initial root password:

```bash
./check-local-gitlab.sh
```

This will display:
- GitLab container status
- Initial root password
- Access URLs
- Resource usage information

### 4. Clean up when done

When you're finished testing, clean up the environment:

```bash
./cleanup-local-gitlab.sh
```

This will stop the containers and optionally:
- Remove all GitLab data
- Remove the gitlab.local entry from your hosts file

## Configuration Details

### Ports

The local testing environment uses different ports to avoid conflicts:
- HTTP: 8080 (instead of 80)
- HTTPS: 8443 (instead of 443)
- SSH: 2224 (instead of 22)

### Resource Usage

The local configuration uses reduced resources:
- Memory limit: 4GB
- CPU limit: 2 cores
- Reduced worker processes

### Data Storage

All data is stored in the `gitlab-local` directory:
- `gitlab-local/data`: GitLab data
- `gitlab-local/config`: Configuration files
- `gitlab-local/logs`: Log files
- `gitlab-local/ssl`: Self-signed SSL certificates

## Customization

You can modify `docker-compose.local.yml` to adjust:
- Resource limits
- Port mappings
- GitLab configuration

## Troubleshooting

### GitLab is slow to start

GitLab can take 5-10 minutes to initialize completely. Check the logs:

```bash
docker logs -f gitlab-local
```

### Cannot access gitlab.local

Ensure the hosts file entry was added correctly:

```bash
grep gitlab.local /etc/hosts
```

### Container fails to start

Check for port conflicts:

```bash
netstat -tuln | grep '8080\|8443\|2224'
```
