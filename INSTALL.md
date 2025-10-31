# VM Installation Guide

This guide explains how to install and manage the Docker Monitoring Stack GPNC on a VM instance using the unified management script.

## Overview

The unified script (`stack.sh`) provides a complete solution for:

- ✅ **Installation**: Automated setup with system dependencies and configuration
- ✅ **Management**: Start, stop, restart, and monitor services
- ✅ **Maintenance**: Updates, permission fixes, backups, and health checks
- ✅ **Uninstallation**: Clean removal with optional data preservation

## Prerequisites

- Ubuntu/Debian-based VM (tested on Ubuntu 20.04+)
- Root or sudo access
- Internet connectivity
- Sufficient disk space for monitoring data

## Quick Start

### Download and Install

```bash
# Download the unified script
curl -sSL https://raw.githubusercontent.com/angelbarrera92/docker-monitoring-stack-gpnc/main/stack.sh -o stack.sh
chmod +x stack.sh

# Install with persistent data directory
sudo ./stack.sh install -d /mnt/monitoring-data
```

### Installation with Custom Alertmanager

```bash
# Install with Slack notifications
sudo ./stack.sh install -d /var/lib/monitoring -a alertmanager-slack-config.yml

# Install with email notifications  
sudo ./stack.sh install -d /backup/monitoring -a alertmanager-email-config.yml
```

## Available Commands

### Installation Commands
```bash
./stack.sh install [OPTIONS]     # Install the monitoring stack
./stack.sh uninstall [OPTIONS]   # Remove the monitoring stack
```

### Management Commands
```bash
./stack.sh start                 # Start the monitoring stack
./stack.sh stop                  # Stop the monitoring stack
./stack.sh restart               # Restart the monitoring stack
./stack.sh status                # Show detailed status
./stack.sh logs                  # Show real-time logs
./stack.sh ps                    # Show container status
```

### Maintenance Commands
```bash
./stack.sh update                # Update stack (git pull + restart)
./stack.sh fix-permissions       # Fix data directory permissions
./stack.sh health                # Check health of all services
./stack.sh backup                # Create backup of data and config
```

### Utility Commands
```bash
./stack.sh urls                  # Show access URLs
./stack.sh config                # Show current configuration
./stack.sh version               # Show script version
./stack.sh help                  # Show detailed help
```

## Installation Options

```bash
Usage: ./stack.sh install [OPTIONS]

OPTIONS:
    -d, --data-dir PATH          Persistent volume path for data storage (required)
    -a, --alertmanager CONFIG    Alertmanager configuration file to use
    -i, --install-dir PATH       Installation directory (default: /opt/docker-monitoring-stack)
    -u, --user USERNAME          Service user (default: monitoring)
    -r, --repo URL               Repository URL
    -h, --help                   Show help message
```

### Available Alertmanager Configurations

- `alertmanager-fallback-config.yml` (default) - Basic configuration
- `alertmanager-email-config.yml` - Email notifications
- `alertmanager-slack-config.yml` - Slack notifications  
- `alertmanager-opsgenie-config.yml` - OpsGenie integration
- `alertmanager-pushover-config.yml` - Pushover notifications

## Post-Installation

### Service Management

After installation, you can manage the monitoring stack using the unified script:

```bash
# Basic management
./stack.sh start               # Start the stack
./stack.sh stop                # Stop the stack  
./stack.sh restart             # Restart the stack
./stack.sh status              # Show detailed status

# Monitoring and logs
./stack.sh logs                # View real-time logs
./stack.sh health              # Check service health
./stack.sh ps                  # Show container status

# Maintenance
./stack.sh update              # Update and restart
./stack.sh fix-permissions     # Fix data permissions
./stack.sh backup              # Create backup
```

You can also use traditional systemd commands:

```bash
# Systemd service management
sudo systemctl status docker-monitoring-stack
sudo systemctl start docker-monitoring-stack
sudo systemctl stop docker-monitoring-stack  
sudo systemctl restart docker-monitoring-stack

# View logs
sudo journalctl -u docker-monitoring-stack -f
```

### Access URLs

After successful installation, access the monitoring services:

- **Grafana**: http://your-vm-ip:3000 (anonymous access enabled)
- **Prometheus**: http://your-vm-ip:9090
- **Alertmanager**: http://your-vm-ip:9093
- **Alert Receiver**: http://your-vm-ip:9094
- **Loki**: http://your-vm-ip:3100

### Management Script

The unified script provides all functionality in one place:

```bash
# Show all available commands
./stack.sh help

# Common operations
./stack.sh start              # Start the stack
./stack.sh logs               # View real-time logs
./stack.sh health             # Check service health
./stack.sh urls               # Show access URLs
./stack.sh config             # Show current configuration
```

## Data Persistence

The installation creates persistent storage for:

- **Grafana**: Dashboards, users, and configuration
- **Prometheus**: Time-series metrics data  
- **Alertmanager**: Alert state and configuration
- **Loki**: Log data and indices
- **Redis**: Cache data

Data is stored in the directory specified with `-d` option:
```
/your-data-dir/
├── grafana/
├── prometheus/
├── alertmanager/
├── loki/
└── redis/
```

## Configuration Customization

### Alertmanager Configuration

To customize alerting after installation:

1. Edit the configuration file:
   ```bash
   sudo nano /opt/docker-monitoring-stack/configs/alertmanager/your-config.yml
   ```

2. Restart the service:
   ```bash
   sudo systemctl restart docker-monitoring-stack
   ```

### Adding Custom Dashboards

1. Place JSON dashboard files in:
   ```bash
   /opt/docker-monitoring-stack/dashboards/
   ```

2. Update Grafana provisioning if needed:
   ```bash
   /opt/docker-monitoring-stack/configs/grafana/provisioning/
   ```

3. Restart to reload:
   ```bash
   sudo systemctl restart docker-monitoring-stack
   ```

## Backup and Recovery

### Backup Data

```bash
# Create backup of monitoring data
sudo tar -czf monitoring-backup-$(date +%Y%m%d).tar.gz -C /path/to/data .

# Backup configuration
sudo tar -czf monitoring-config-$(date +%Y%m%d).tar.gz -C /opt/docker-monitoring-stack .
```

### Restore Data

```bash
# Stop services
sudo systemctl stop docker-monitoring-stack

# Restore data
sudo tar -xzf monitoring-backup-YYYYMMDD.tar.gz -C /path/to/data

# Fix permissions
sudo chown -R monitoring:monitoring /path/to/data

# Start services
sudo systemctl start docker-monitoring-stack
```

## Troubleshooting

### Service Won't Start

1. Check service status:
   ```bash
   ./stack.sh status
   # or
   sudo systemctl status docker-monitoring-stack
   ```

2. Check Docker status:
   ```bash
   sudo systemctl status docker
   ```

3. Check container logs:
   ```bash
   ./stack.sh logs
   # or
   ./stack.sh ps
   ```

### Systemd Service Timeouts

If the service times out on slower systems, you can increase the timeout values:

**During installation:**
```bash
# Install with custom timeouts (15 minutes start, 7.5 minutes stop)
sudo ./stack.sh install -d /mnt/data --timeout-start 900 --timeout-stop 450
```

**For existing installations:**
```bash
# Update timeout values (arguments: start_timeout stop_timeout)
sudo ./stack.sh update-timeouts 900 450

# Restart service to apply changes
./stack.sh restart
```

**Check current timeout values:**
```bash
./stack.sh config
```

### Common Permission Errors

**Grafana fails to start with "permission denied":**
```bash
# Check Grafana logs
sudo -u monitoring docker compose logs grafana

# Fix Grafana permissions (uid=472)
sudo chown -R 472:0 /path/to/data/grafana
sudo chmod -R 755 /path/to/data/grafana
```

**Prometheus can't write to data directory:**
```bash
# Check Prometheus logs
sudo -u monitoring docker compose logs prometheus

# Fix Prometheus permissions (uid=65534)
sudo chown -R 65534:65534 /path/to/data/prometheus
sudo chmod -R 755 /path/to/data/prometheus
```

**Quick fix for all permission issues:**
```bash
# Use the automated fix
./stack.sh fix-permissions
```

### Port Conflicts

If ports are already in use, modify `docker-compose.yml`:

```bash
sudo nano /opt/docker-monitoring-stack/docker-compose.yml
# Change port mappings as needed
sudo systemctl restart docker-monitoring-stack
```

### Permission Issues

Docker containers run with specific user IDs, and data directories need correct permissions:

- **Grafana**: uid=472, gid=0
- **Prometheus**: uid=65534, gid=65534 (nobody)
- **Alertmanager**: uid=65534, gid=65534 (nobody)  
- **Loki**: uid=10001, gid=10001
- **Redis**: uid=0, gid=0 (root)

Fix permissions using the unified script:

```bash
# Fix all permissions automatically
./stack.sh fix-permissions
```

If you encounter permission errors in logs:
```bash
# Check container logs for permission errors
./stack.sh logs
./stack.sh ps
```

### Disk Space Issues

Monitor disk usage:

```bash
# Check data directory size
sudo du -sh /path/to/data/*

# Clean old Docker images
sudo docker system prune -f

# Configure data retention in Prometheus config
sudo nano /opt/docker-monitoring-stack/configs/prometheus/prometheus.yml
```

## Uninstallation

Use the unified script to remove the monitoring stack:

```bash
# Basic uninstall (preserves data and user)
sudo ./stack.sh uninstall

# Complete removal including data
sudo ./stack.sh uninstall --remove-data --remove-user
```

### Uninstall Options

```bash
Usage: ./stack.sh uninstall [OPTIONS]

OPTIONS:
    --remove-data               Remove data directory (WARNING: Deletes all data!)
    --remove-user               Remove service user
    -i, --install-dir PATH      Installation directory
    -u, --user USERNAME         Service user name
    -h, --help                  Show help message
```

## Security Considerations

- Grafana runs with anonymous access enabled by default
- Consider setting up authentication for production use
- Configure firewall rules to restrict access
- Regularly update the stack using `monitor update`
- Review alertmanager configurations for sensitive data

## Support

For issues specific to the installation scripts:
1. Check the installation and service logs
2. Verify system requirements are met
3. Ensure proper permissions on data directories
4. Review the troubleshooting section above

For application-specific issues, refer to the main project documentation.