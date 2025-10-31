#!/bin/bash

set -euo pipefail

# Docker Monitoring Stack GPNC - Unified Management Script
# This script handles installation, management, uninstallation, and troubleshooting
# Author: Generated for docker-monitoring-stack-gpnc
# Date: $(date +"%Y-%m-%d")

# Script version
SCRIPT_VERSION="1.0.0"

# Default values
INSTALL_DIR="/opt/docker-monitoring-stack"
DATA_DIR=""
ALERTMANAGER_CONFIG="alertmanager-fallback-config.yml"
SERVICE_USER="monitoring"
REPO_URL="https://github.com/angelbarrera92/docker-monitoring-stack-gpnc.git"
SYSTEMD_SERVICE_NAME="docker-monitoring-stack"

# Systemd timeout values (in seconds) - Increase these for slower systems
TIMEOUT_START_SEC=600    # 10 minutes for service start
TIMEOUT_STOP_SEC=300     # 5 minutes for service stop

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

log_header() {
    echo -e "${PURPLE}=== $1 ===${NC}"
}

# Show script header
show_header() {
    echo -e "${CYAN}"
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════╗
║              Docker Monitoring Stack GPNC                   ║
║                 Unified Management Script                    ║
║                                                              ║
║  Grafana • Prometheus • Loki • Alertmanager • cAdvisor      ║
╚══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
    echo "Version: $SCRIPT_VERSION"
    echo ""
}

# Usage function
usage() {
    show_header
    cat << EOF
${BLUE}USAGE:${NC}
    $0 COMMAND [OPTIONS]

${BLUE}INSTALLATION COMMANDS:${NC}
    install              Install the monitoring stack
    uninstall            Remove the monitoring stack

${BLUE}MANAGEMENT COMMANDS:${NC}
    start                Start the monitoring stack
    stop                 Stop the monitoring stack
    restart              Restart the monitoring stack
    status               Show detailed status
    logs                 Show real-time logs
    ps                   Show container status

${BLUE}MAINTENANCE COMMANDS:${NC}
    update               Update stack (git pull + restart)
    fix-permissions      Fix data directory and configuration file permissions
    health               Check health of all services
    backup               Create backup of data and config
    update-timeouts      Update systemd service timeout values
    restore              Restore from backup

${BLUE}UTILITY COMMANDS:${NC}
    urls                 Show access URLs
    config               Show current configuration
    version              Show script version
    help                 Show this help message

${BLUE}INSTALLATION OPTIONS:${NC}
    -d, --data-dir PATH          Persistent volume path (required for install)
    -a, --alertmanager CONFIG    Alertmanager configuration file
    -i, --install-dir PATH       Installation directory (default: $INSTALL_DIR)
    -u, --user USERNAME          Service user (default: $SERVICE_USER)
    -r, --repo URL               Repository URL
    --timeout-start SECONDS     Service start timeout (default: $TIMEOUT_START_SEC)
    --timeout-stop SECONDS      Service stop timeout (default: $TIMEOUT_STOP_SEC)
    --remove-data               Remove data during uninstall
    --remove-user               Remove service user during uninstall

${BLUE}AVAILABLE ALERTMANAGER CONFIGS:${NC}
    • alertmanager-fallback-config.yml (default)
    • alertmanager-email-config.yml
    • alertmanager-slack-config.yml
    • alertmanager-opsgenie-config.yml
    • alertmanager-pushover-config.yml

${BLUE}EXAMPLES:${NC}
    # Installation
    $0 install -d /mnt/monitoring-data
    $0 install -d /var/lib/monitoring -a alertmanager-slack-config.yml
    $0 install -d /mnt/data --timeout-start 900 --timeout-stop 450

    # Management
    $0 start
    $0 logs
    $0 fix-permissions
    $0 health
    $0 update-timeouts 900 450      # Set start timeout to 15min, stop to 7.5min

    # Uninstallation
    $0 uninstall
    $0 uninstall --remove-data --remove-user

${BLUE}ACCESS URLS (after installation):${NC}
    Grafana:      http://your-server:3000
    Prometheus:   http://your-server:9090
    Alertmanager: http://your-server:9093
    Loki:         http://your-server:3100

EOF
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This operation requires root privileges. Please run with sudo."
    fi
}

# Check if service exists
check_service_exists() {
    if ! systemctl list-unit-files | grep -q "$SYSTEMD_SERVICE_NAME.service"; then
        log_error "Service $SYSTEMD_SERVICE_NAME not found. Is the monitoring stack installed?"
    fi
}

# Get data directory from existing installation
get_data_dir() {
    if [[ -f "$INSTALL_DIR/docker-compose.override.yml" ]]; then
        DATA_DIR=$(grep -oP '(?<=- )[^:]+(?=/(grafana|prometheus|alertmanager|loki|redis):)' "$INSTALL_DIR/docker-compose.override.yml" | head -1)
    fi

    if [[ -z "$DATA_DIR" ]]; then
        log_error "Could not determine data directory. Please specify with -d option."
    fi
}

# Parse command line arguments for installation
parse_install_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -d|--data-dir)
                DATA_DIR="$2"
                shift 2
                ;;
            -a|--alertmanager)
                ALERTMANAGER_CONFIG="$2"
                shift 2
                ;;
            -i|--install-dir)
                INSTALL_DIR="$2"
                shift 2
                ;;
            -u|--user)
                SERVICE_USER="$2"
                shift 2
                ;;
            -r|--repo)
                REPO_URL="$2"
                shift 2
                ;;
            --timeout-start)
                TIMEOUT_START_SEC="$2"
                shift 2
                ;;
            --timeout-stop)
                TIMEOUT_STOP_SEC="$2"
                shift 2
                ;;
            *)
                log_error "Unknown installation option: $1"
                ;;
        esac
    done
}

# Parse command line arguments for uninstall
parse_uninstall_args() {
    REMOVE_DATA=false
    REMOVE_USER=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            --remove-data)
                REMOVE_DATA=true
                shift
                ;;
            --remove-user)
                REMOVE_USER=true
                shift
                ;;
            -i|--install-dir)
                INSTALL_DIR="$2"
                shift 2
                ;;
            -u|--user)
                SERVICE_USER="$2"
                shift 2
                ;;
            *)
                log_error "Unknown uninstall option: $1"
                ;;
        esac
    done
}

# Validate alertmanager config
validate_alertmanager_config() {
    local valid_configs=(
        "alertmanager-email-config.yml"
        "alertmanager-fallback-config.yml"
        "alertmanager-opsgenie-config.yml"
        "alertmanager-pushover-config.yml"
        "alertmanager-slack-config.yml"
    )

    if [[ ! " ${valid_configs[*]} " =~ " ${ALERTMANAGER_CONFIG} " ]]; then
        log_error "Invalid alertmanager configuration: $ALERTMANAGER_CONFIG. Valid options: ${valid_configs[*]}"
    fi
}

# ============================================================================
# INSTALLATION FUNCTIONS
# ============================================================================

# Check system requirements
check_requirements() {
    log_info "Checking system requirements..."

    # Check if git is installed
    if ! command -v git &> /dev/null; then
        log_info "Installing git..."
        apt-get update && apt-get install -y git
    fi

    # Check if docker is installed
    if ! command -v docker &> /dev/null; then
        log_info "Installing Docker..."
        curl -fsSL https://get.docker.com -o get-docker.sh
        sh get-docker.sh
        rm get-docker.sh
        systemctl enable docker
        systemctl start docker
    fi

    # Check if docker compose is available
    if ! docker compose version &> /dev/null && ! docker-compose --version &> /dev/null; then
        log_info "Installing Docker Compose..."
        apt-get update && apt-get install -y docker-compose-plugin
    fi

    log_success "System requirements satisfied"
}

# Create service user
create_service_user() {
    log_info "Creating service user: $SERVICE_USER"

    if id "$SERVICE_USER" &>/dev/null; then
        log_warning "User $SERVICE_USER already exists"
    else
        useradd --system --shell /bin/false --home-dir "$INSTALL_DIR" --create-home "$SERVICE_USER"
        usermod -aG docker "$SERVICE_USER"
        log_success "Created service user: $SERVICE_USER"
    fi
}

# Prepare directories
prepare_directories() {
    log_info "Preparing directories..."

    # Create data directory
    mkdir -p "$DATA_DIR"

    # Create install directory
    mkdir -p "$INSTALL_DIR"
    chown "$SERVICE_USER:$SERVICE_USER" "$INSTALL_DIR"

    log_success "Directories prepared"
}

# Clone repository
clone_repository() {
    log_info "Cloning repository..."

    if [[ -d "$INSTALL_DIR/.git" ]]; then
        log_info "Repository already exists, updating..."
        cd "$INSTALL_DIR"
        sudo -u "$SERVICE_USER" git pull
    else
        sudo -u "$SERVICE_USER" git clone "$REPO_URL" "$INSTALL_DIR"
    fi

    cd "$INSTALL_DIR"
    chown -R "$SERVICE_USER:$SERVICE_USER" "$INSTALL_DIR"

    log_success "Repository cloned/updated"
}

# Configure monitoring stack
configure_stack() {
    log_info "Configuring monitoring stack..."

    cd "$INSTALL_DIR"

    # Create custom docker-compose override for persistent storage
    cat > docker-compose.override.yml << EOF
version: '3.8'

services:
  grafana:
    volumes:
      - $DATA_DIR/grafana:/var/lib/grafana

  prometheus:
    volumes:
      - $DATA_DIR/prometheus:/prometheus

  alertmanager:
    volumes:
      - ./configs/alertmanager/$ALERTMANAGER_CONFIG:/etc/alertmanager/config.yml
      - $DATA_DIR/alertmanager:/alertmanager

  loki:
    volumes:
      - $DATA_DIR/loki:/loki

  redis:
    volumes:
      - $DATA_DIR/redis:/data
EOF

    # Fix permissions for data directories
    fix_data_permissions_internal

    # Fix permissions for configuration files
    fix_config_permissions_internal

    # Set ownership for installation directory (but preserve config file permissions)
    chown -R "$SERVICE_USER:$SERVICE_USER" "$INSTALL_DIR"

    # Re-apply config permissions after chown
    fix_config_permissions_internal

    log_success "Monitoring stack configured with proper permissions"
}

# Fix data directory permissions (internal function)
fix_data_permissions_internal() {
    log_info "Setting up data directory permissions for containers..."

    # Create data subdirectories
    mkdir -p "$DATA_DIR"/{grafana,prometheus,alertmanager,loki,redis}
    log_info "Created data subdirectories"

    # Set proper ownership and permissions for each service
    log_info "Setting Grafana permissions (uid=472, gid=0)..."
    chown -R 472:0 "$DATA_DIR/grafana"
    chmod -R 755 "$DATA_DIR/grafana"

    log_info "Setting Prometheus permissions (uid=65534, gid=65534)..."
    chown -R 65534:65534 "$DATA_DIR/prometheus"
    chmod -R 755 "$DATA_DIR/prometheus"

    log_info "Setting Alertmanager permissions (uid=65534, gid=65534)..."
    chown -R 65534:65534 "$DATA_DIR/alertmanager"
    chmod -R 755 "$DATA_DIR/alertmanager"

    log_info "Setting Loki permissions (uid=10001, gid=10001)..."
    chown -R 10001:10001 "$DATA_DIR/loki"
    chmod -R 755 "$DATA_DIR/loki"

    log_info "Setting Redis permissions (uid=0, gid=0)..."
    chown -R 0:0 "$DATA_DIR/redis"
    chmod -R 755 "$DATA_DIR/redis"

    log_success "Container permissions configured correctly"

    # Verify permissions were set correctly
    verify_permissions_internal
}

# Fix configuration file permissions (internal function)
fix_config_permissions_internal() {
    log_info "Setting up configuration file permissions for containers..."

    # Prometheus configuration files (runs as uid=65534:65534)
    if [[ -d "$INSTALL_DIR/configs/prometheus" ]]; then
        log_info "Setting Prometheus config permissions (readable by uid=65534)..."
        chmod -R 644 "$INSTALL_DIR/configs/prometheus"/*.yml
        # Ensure directory is accessible
        chmod 755 "$INSTALL_DIR/configs/prometheus"
        chmod 755 "$INSTALL_DIR/configs"
    fi

    # Alertmanager configuration files (runs as uid=65534:65534)
    if [[ -d "$INSTALL_DIR/configs/alertmanager" ]]; then
        log_info "Setting Alertmanager config permissions (readable by uid=65534)..."
        chmod -R 644 "$INSTALL_DIR/configs/alertmanager"/*.yml
        # Ensure directory is accessible
        chmod 755 "$INSTALL_DIR/configs/alertmanager"
    fi

    # Loki configuration files (runs as uid=10001:10001)
    if [[ -d "$INSTALL_DIR/configs/loki" ]]; then
        log_info "Setting Loki config permissions (readable by uid=10001)..."
        chmod -R 644 "$INSTALL_DIR/configs/loki"/*.yaml
        # Ensure directory is accessible
        chmod 755 "$INSTALL_DIR/configs/loki"
    fi

    # Promtail configuration files (runs as root, but should be readable)
    if [[ -d "$INSTALL_DIR/configs/promtail" ]]; then
        log_info "Setting Promtail config permissions..."
        chmod -R 644 "$INSTALL_DIR/configs/promtail"/*.yaml
        # Ensure directory is accessible
        chmod 755 "$INSTALL_DIR/configs/promtail"
    fi

    # Grafana configuration files (runs as uid=472)
    if [[ -d "$INSTALL_DIR/configs/grafana" ]]; then
        log_info "Setting Grafana config permissions (readable by uid=472)..."
        find "$INSTALL_DIR/configs/grafana" -type f -name "*.yml" -exec chmod 644 {} \;
        find "$INSTALL_DIR/configs/grafana" -type d -exec chmod 755 {} \;
    fi

    # Ensure dashboards are readable
    if [[ -d "$INSTALL_DIR/dashboards" ]]; then
        log_info "Setting dashboard permissions..."
        chmod -R 644 "$INSTALL_DIR/dashboards"/*.json
        chmod 755 "$INSTALL_DIR/dashboards"
    fi

    log_success "Configuration file permissions set correctly"
}

# Verify data directory permissions (internal function)
verify_permissions_internal() {
    log_info "Verifying data directory permissions..."

    local errors=0

    # Check each directory exists and has correct ownership
    for subdir in grafana prometheus alertmanager loki redis; do
        if [[ ! -d "$DATA_DIR/$subdir" ]]; then
            log_warning "Directory missing: $DATA_DIR/$subdir"
            ((errors++))
        fi
    done

    # Check specific ownership (basic verification)
    if [[ -d "$DATA_DIR/grafana" ]]; then
        local grafana_owner=$(stat -c "%u:%g" "$DATA_DIR/grafana" 2>/dev/null || echo "")
        if [[ "$grafana_owner" != "472:0" ]]; then
            log_warning "Grafana directory ownership issue (expected 472:0, got $grafana_owner)"
            ((errors++))
        fi
    fi

    if [[ -d "$DATA_DIR/prometheus" ]]; then
        local prometheus_owner=$(stat -c "%u:%g" "$DATA_DIR/prometheus" 2>/dev/null || echo "")
        if [[ "$prometheus_owner" != "65534:65534" ]]; then
            log_warning "Prometheus directory ownership issue (expected 65534:65534, got $prometheus_owner)"
            ((errors++))
        fi
    fi

    if [[ $errors -eq 0 ]]; then
        log_success "Permission verification passed"
    else
        log_warning "Found $errors permission issues - containers may have startup problems"
        log_info "You can fix permissions later with: ./stack.sh fix-permissions"
    fi
}

# Create systemd service
create_systemd_service() {
    log_info "Creating systemd service..."

    # Detect docker compose command
    if command -v docker-compose &> /dev/null; then
        DOCKER_COMPOSE_CMD="docker-compose"
    else
        DOCKER_COMPOSE_CMD="docker compose"
    fi

    cat > "/etc/systemd/system/${SYSTEMD_SERVICE_NAME}.service" << EOF
[Unit]
Description=Docker Monitoring Stack GPNC
Documentation=https://github.com/angelbarrera92/docker-monitoring-stack-gpnc
Requires=docker.service
After=docker.service
RequiresMountsFor=$DATA_DIR

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=$INSTALL_DIR
User=$SERVICE_USER
Group=$SERVICE_USER

# Environment
Environment=COMPOSE_PROJECT_NAME=monitoring-stack

# Start command
ExecStart=/usr/bin/$DOCKER_COMPOSE_CMD up -d
ExecStop=/usr/bin/$DOCKER_COMPOSE_CMD down
ExecReload=/usr/bin/$DOCKER_COMPOSE_CMD restart

# Restart policy
Restart=on-failure
RestartSec=30

# Security settings
NoNewPrivileges=yes
PrivateTmp=yes
ProtectSystem=strict
ProtectHome=yes
ReadWritePaths=$DATA_DIR $INSTALL_DIR

# Resource limits - Increased timeouts for slower systems
TimeoutStartSec=$TIMEOUT_START_SEC
TimeoutStopSec=$TIMEOUT_STOP_SEC

[Install]
WantedBy=multi-user.target
EOF

    # Reload systemd and enable service
    systemctl daemon-reload
    systemctl enable "$SYSTEMD_SERVICE_NAME"

    log_success "Systemd service created and enabled"
}

# Start services
start_services() {
    log_info "Starting monitoring stack..."

    # Final permission check before starting services
    log_info "Performing final permission check before service start..."
    fix_data_permissions_internal
    fix_config_permissions_internal

    systemctl start "$SYSTEMD_SERVICE_NAME"

    # Wait a moment for services to start
    sleep 10

    # Check service status
    if systemctl is-active --quiet "$SYSTEMD_SERVICE_NAME"; then
        log_success "Monitoring stack started successfully"
    else
        log_error "Failed to start monitoring stack. Check: systemctl status $SYSTEMD_SERVICE_NAME"
    fi
}

# Display installation summary
display_installation_summary() {
    log_success "Installation completed successfully!"

    cat << EOF

${GREEN}=== Installation Summary ===${NC}

Installation Directory: $INSTALL_DIR
Data Directory: $DATA_DIR
Service User: $SERVICE_USER
Alertmanager Config: $ALERTMANAGER_CONFIG
Systemd Service: $SYSTEMD_SERVICE_NAME

${BLUE}=== Quick Commands ===${NC}

Start Stack:      $0 start
Stop Stack:       $0 stop
View Logs:        $0 logs
Check Health:     $0 health
Fix Permissions:  $0 fix-permissions

${BLUE}=== Container & Configuration Permissions ===${NC}

✓ Grafana data permissions (uid=472) configured
✓ Prometheus data permissions (uid=65534) configured
✓ Alertmanager data permissions (uid=65534) configured
✓ Loki data permissions (uid=10001) configured
✓ Redis data permissions (uid=0) configured
✓ Configuration file permissions set (readable by containers)
✓ Dashboard file permissions configured

${BLUE}=== Access URLs ===${NC}

Grafana:          http://$(hostname -I | awk '{print $1}'):3000
Prometheus:       http://$(hostname -I | awk '{print $1}'):9090
Alertmanager:     http://$(hostname -I | awk '{print $1}'):9093
Alert Receiver:   http://$(hostname -I | awk '{print $1}'):9094
Loki:             http://$(hostname -I | awk '{print $1}'):3100

${YELLOW}Note: Grafana is configured with anonymous access (Admin role)${NC}

EOF
}

# ============================================================================
# MANAGEMENT FUNCTIONS
# ============================================================================

# Start service
start_service() {
    check_service_exists
    log_info "Starting monitoring stack..."

    # Ensure permissions are correct before starting
    if [[ -n "$DATA_DIR" ]] || get_data_dir 2>/dev/null; then
        log_info "Checking data directory permissions..."
        fix_data_permissions_internal
        log_info "Checking configuration file permissions..."
        fix_config_permissions_internal
    fi

    systemctl start "$SYSTEMD_SERVICE_NAME"
    sleep 5
    if systemctl is-active --quiet "$SYSTEMD_SERVICE_NAME"; then
        log_success "Monitoring stack started"
    else
        log_error "Failed to start monitoring stack"
        systemctl status "$SYSTEMD_SERVICE_NAME" --no-pager
    fi
}

# Stop service
stop_service() {
    check_service_exists
    log_info "Stopping monitoring stack..."
    systemctl stop "$SYSTEMD_SERVICE_NAME"
    log_success "Monitoring stack stopped"
}

# Restart service
restart_service() {
    check_service_exists
    log_info "Restarting monitoring stack..."

    # Ensure permissions are correct before restarting
    if [[ -n "$DATA_DIR" ]] || get_data_dir 2>/dev/null; then
        log_info "Checking data directory permissions..."
        fix_data_permissions_internal
        log_info "Checking configuration file permissions..."
        fix_config_permissions_internal
    fi

    systemctl restart "$SYSTEMD_SERVICE_NAME"
    sleep 5
    if systemctl is-active --quiet "$SYSTEMD_SERVICE_NAME"; then
        log_success "Monitoring stack restarted"
    else
        log_error "Failed to restart monitoring stack"
        systemctl status "$SYSTEMD_SERVICE_NAME" --no-pager
    fi
}

# Show status
show_status() {
    check_service_exists
    log_header "Service Status"
    systemctl status "$SYSTEMD_SERVICE_NAME" --no-pager
    echo ""
    log_header "Container Status"
    show_containers
}

# Show logs
show_logs() {
    check_service_exists
    log_info "Showing service logs (Ctrl+C to exit)..."
    journalctl -u "$SYSTEMD_SERVICE_NAME" -f
}

# Show containers
show_containers() {
    if [[ -d "$INSTALL_DIR" ]]; then
        cd "$INSTALL_DIR"

        # Detect docker compose command
        if command -v docker-compose &> /dev/null; then
            DOCKER_COMPOSE_CMD="docker-compose"
        else
            DOCKER_COMPOSE_CMD="docker compose"
        fi

        $DOCKER_COMPOSE_CMD ps
    else
        log_error "Installation directory not found: $INSTALL_DIR"
    fi
}

# Update service
update_service() {
    check_service_exists
    log_info "Updating monitoring stack..."

    if [[ ! -d "$INSTALL_DIR" ]]; then
        log_error "Installation directory not found: $INSTALL_DIR"
    fi

    # Stop service
    systemctl stop "$SYSTEMD_SERVICE_NAME"

    # Update repository
    cd "$INSTALL_DIR"
    sudo -u "$SERVICE_USER" git pull

    # Restart service
    systemctl start "$SYSTEMD_SERVICE_NAME"

    sleep 5
    if systemctl is-active --quiet "$SYSTEMD_SERVICE_NAME"; then
        log_success "Monitoring stack updated and restarted"
    else
        log_error "Failed to restart after update"
        systemctl status "$SYSTEMD_SERVICE_NAME" --no-pager
    fi
}

# Show URLs
show_urls() {
    local ip=$(hostname -I | awk '{print $1}')

    log_header "Access URLs"
    cat << EOF

${BLUE}Grafana Dashboard:${NC}           http://$ip:3000
${BLUE}Prometheus:${NC}                  http://$ip:9090
${BLUE}Alertmanager:${NC}               http://$ip:9093
${BLUE}Uncomplicated Alert Receiver:${NC} http://$ip:9094
${BLUE}Loki:${NC}                       http://$ip:3100

${YELLOW}Note: Grafana has anonymous access enabled with Admin role.${NC}

EOF
}

# Check health
check_health() {
    log_header "Health Check"

    local ip=$(hostname -I | awk '{print $1}')
    local services=(
        "Grafana:3000"
        "Prometheus:9090"
        "Alertmanager:9093"
        "Alert Receiver:9094"
        "Loki:3100"
    )

    echo "Service Health:"

    for service in "${services[@]}"; do
        local name=$(echo "$service" | cut -d: -f1)
        local port=$(echo "$service" | cut -d: -f2)

        if curl -s -f "http://$ip:$port" >/dev/null 2>&1; then
            echo -e "${GREEN}✓${NC} $name (port $port) - OK"
        else
            echo -e "${RED}✗${NC} $name (port $port) - FAILED"
        fi
    done

    echo ""
    echo "System Status:"
    if systemctl is-active "$SYSTEMD_SERVICE_NAME" >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} Systemd service - Running"
    else
        echo -e "${RED}✗${NC} Systemd service - Not running"
    fi
}

# Fix permissions
fix_permissions() {
    check_root
    get_data_dir

    log_info "Fixing data directory and configuration file permissions..."
    log_info "Data directory: $DATA_DIR"

    if [[ ! -d "$DATA_DIR" ]]; then
        log_error "Data directory not found: $DATA_DIR"
    fi

    # Stop service temporarily
    log_info "Stopping service temporarily..."
    systemctl stop "$SYSTEMD_SERVICE_NAME" 2>/dev/null || true

    # Fix permissions for both data and config files
    DATA_DIR="$DATA_DIR" fix_data_permissions_internal
    fix_config_permissions_internal

    # Start service again
    log_info "Starting service..."
    systemctl start "$SYSTEMD_SERVICE_NAME"

    sleep 5
    if systemctl is-active --quiet "$SYSTEMD_SERVICE_NAME"; then
        log_success "Permissions fixed and service restarted"
    else
        log_error "Permissions fixed but service failed to start"
        systemctl status "$SYSTEMD_SERVICE_NAME" --no-pager
    fi
}

# Show configuration
show_config() {
    if [[ ! -f "$INSTALL_DIR/docker-compose.override.yml" ]]; then
        log_error "Monitoring stack not installed or configuration not found"
    fi

    get_data_dir

    log_header "Current Configuration"
    cat << EOF

${BLUE}Installation Directory:${NC} $INSTALL_DIR
${BLUE}Data Directory:${NC}         $DATA_DIR
${BLUE}Service User:${NC}           $SERVICE_USER
${BLUE}Systemd Service:${NC}        $SYSTEMD_SERVICE_NAME

${BLUE}Alertmanager Config:${NC}
$(grep -A1 "alertmanager-.*-config.yml" "$INSTALL_DIR/docker-compose.override.yml" | grep -o "alertmanager-.*-config.yml" || echo "Not found")

${BLUE}Systemd Timeout Values:${NC}
$(if [[ -f "/etc/systemd/system/${SYSTEMD_SERVICE_NAME}.service" ]]; then
    echo "Start Timeout: $(grep "^TimeoutStartSec=" "/etc/systemd/system/${SYSTEMD_SERVICE_NAME}.service" | cut -d= -f2)s"
    echo "Stop Timeout: $(grep "^TimeoutStopSec=" "/etc/systemd/system/${SYSTEMD_SERVICE_NAME}.service" | cut -d= -f2)s"
else
    echo "Service file not found"
fi)

${BLUE}Data Directories:${NC}
EOF

    for subdir in grafana prometheus alertmanager loki redis; do
        if [[ -d "$DATA_DIR/$subdir" ]]; then
            echo "  ✓ $DATA_DIR/$subdir"
        else
            echo "  ✗ $DATA_DIR/$subdir (missing)"
        fi
    done

    echo ""
}

# Create backup
create_backup() {
    get_data_dir

    local backup_name="monitoring-backup-$(date +%Y%m%d-%H%M%S)"
    local backup_dir="/tmp/$backup_name"

    log_info "Creating backup: $backup_name"

    # Stop service
    log_info "Stopping service for backup..."
    systemctl stop "$SYSTEMD_SERVICE_NAME"

    # Create backup directory
    mkdir -p "$backup_dir"

    # Backup data
    log_info "Backing up data directory..."
    cp -r "$DATA_DIR" "$backup_dir/data"

    # Backup configuration
    log_info "Backing up configuration..."
    cp -r "$INSTALL_DIR" "$backup_dir/config"

    # Create archive
    cd /tmp
    tar -czf "${backup_name}.tar.gz" "$backup_name"
    rm -rf "$backup_dir"

    # Start service
    log_info "Starting service..."
    systemctl start "$SYSTEMD_SERVICE_NAME"

    log_success "Backup created: /tmp/${backup_name}.tar.gz"
}

# Update systemd timeout values
update_timeouts() {
    check_root
    check_service_exists

    local start_timeout="${1:-$TIMEOUT_START_SEC}"
    local stop_timeout="${2:-$TIMEOUT_STOP_SEC}"

    log_info "Updating systemd service timeout values..."
    log_info "Start timeout: ${start_timeout}s, Stop timeout: ${stop_timeout}s"

    # Check if service file exists
    if [[ ! -f "/etc/systemd/system/${SYSTEMD_SERVICE_NAME}.service" ]]; then
        log_error "Systemd service file not found. Is the monitoring stack installed?"
    fi

    # Update timeout values in the service file
    sed -i "s/^TimeoutStartSec=.*/TimeoutStartSec=${start_timeout}/" "/etc/systemd/system/${SYSTEMD_SERVICE_NAME}.service"
    sed -i "s/^TimeoutStopSec=.*/TimeoutStopSec=${stop_timeout}/" "/etc/systemd/system/${SYSTEMD_SERVICE_NAME}.service"

    # Reload systemd
    systemctl daemon-reload

    log_success "Systemd service timeout values updated"
    log_info "Changes will take effect on next service restart"
}

# ============================================================================
# UNINSTALLATION FUNCTIONS
# ============================================================================

# Confirm destructive action
confirm_action() {
    local message="$1"
    echo -e "${YELLOW}$message${NC}"
    read -p "Are you sure? (yes/no): " -r
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        log_info "Operation cancelled"
        exit 0
    fi
}

# Stop and disable service
stop_and_disable_service() {
    log_info "Stopping and disabling systemd service..."

    if systemctl is-active --quiet "$SYSTEMD_SERVICE_NAME"; then
        systemctl stop "$SYSTEMD_SERVICE_NAME"
        log_info "Service stopped"
    fi

    if systemctl is-enabled --quiet "$SYSTEMD_SERVICE_NAME" 2>/dev/null; then
        systemctl disable "$SYSTEMD_SERVICE_NAME"
        log_info "Service disabled"
    fi
}

# Remove containers and images
remove_containers() {
    log_info "Removing Docker containers..."

    if [[ -d "$INSTALL_DIR" ]]; then
        cd "$INSTALL_DIR"

        # Detect docker compose command
        if command -v docker-compose &> /dev/null; then
            DOCKER_COMPOSE_CMD="docker-compose"
        else
            DOCKER_COMPOSE_CMD="docker compose"
        fi

        # Stop and remove containers
        if [[ -f "docker-compose.yml" ]]; then
            sudo -u "$SERVICE_USER" $DOCKER_COMPOSE_CMD down --volumes --remove-orphans 2>/dev/null || true
        fi

        # Remove monitoring network if it exists
        docker network rm monitoring 2>/dev/null || true

        log_success "Containers removed"
    fi
}

# Remove systemd service
remove_systemd_service() {
    log_info "Removing systemd service..."

    if [[ -f "/etc/systemd/system/${SYSTEMD_SERVICE_NAME}.service" ]]; then
        rm -f "/etc/systemd/system/${SYSTEMD_SERVICE_NAME}.service"
        systemctl daemon-reload
        log_success "Systemd service removed"
    else
        log_info "Systemd service file not found"
    fi
}

# Remove installation directory
remove_installation() {
    log_info "Removing installation directory..."

    if [[ -d "$INSTALL_DIR" ]]; then
        rm -rf "$INSTALL_DIR"
        log_success "Installation directory removed: $INSTALL_DIR"
    else
        log_info "Installation directory not found: $INSTALL_DIR"
    fi
}

# Remove data directory
remove_data_directory() {
    if [[ "$REMOVE_DATA" == "true" ]]; then
        confirm_action "This will permanently delete ALL monitoring data!"

        get_data_dir

        if [[ -n "$DATA_DIR" && -d "$DATA_DIR" ]]; then
            log_info "Removing data directory: $DATA_DIR"
            rm -rf "$DATA_DIR"
            log_success "Data directory removed"
        else
            log_warning "Could not locate data directory"
        fi
    fi
}

# Remove service user
remove_service_user() {
    if [[ "$REMOVE_USER" == "true" ]]; then
        log_info "Removing service user: $SERVICE_USER"

        if id "$SERVICE_USER" &>/dev/null; then
            userdel "$SERVICE_USER" 2>/dev/null || true
            log_success "Service user removed: $SERVICE_USER"
        else
            log_info "Service user not found: $SERVICE_USER"
        fi
    fi
}

# Display uninstallation summary
display_uninstall_summary() {
    log_success "Uninstallation completed!"

    cat << EOF

${GREEN}=== Uninstallation Summary ===${NC}

✓ Service stopped and disabled
✓ Docker containers removed
✓ Systemd service removed
✓ Installation directory removed: $INSTALL_DIR

EOF

    if [[ "$REMOVE_DATA" == "true" ]]; then
        echo "✓ Data directory removed"
    else
        echo "- Data directory preserved"
    fi

    if [[ "$REMOVE_USER" == "true" ]]; then
        echo "✓ Service user removed: $SERVICE_USER"
    else
        echo "- Service user preserved: $SERVICE_USER"
    fi

    echo ""

    if [[ "$REMOVE_DATA" == "false" ]] || [[ "$REMOVE_USER" == "false" ]]; then
        cat << EOF
${YELLOW}Note: Some components were preserved. To completely remove:${NC}
- Run: $0 uninstall --remove-data --remove-user

EOF
    fi
}

# ============================================================================
# MAIN COMMAND DISPATCHER
# ============================================================================

# Main function
main() {
    local command="${1:-}"

    if [[ -z "$command" ]]; then
        usage
        exit 1
    fi

    # Shift past the command
    shift

    case "$command" in
        # Installation commands
        install)
            show_header
            parse_install_args "$@"

            # Validate required parameters
            if [[ -z "$DATA_DIR" ]]; then
                log_error "Data directory is required. Use -d or --data-dir to specify it."
            fi
            validate_alertmanager_config

            log_info "Starting installation..."
            log_info "Data directory: $DATA_DIR"
            log_info "Alertmanager config: $ALERTMANAGER_CONFIG"
            log_info "Install directory: $INSTALL_DIR"

            check_root
            check_requirements
            create_service_user
            prepare_directories
            clone_repository
            configure_stack
            create_systemd_service
            start_services
            display_installation_summary
            ;;

        uninstall)
            show_header
            parse_uninstall_args "$@"

            log_info "Starting uninstallation..."
            check_root
            stop_and_disable_service
            remove_containers
            remove_systemd_service
            remove_installation
            remove_data_directory
            remove_service_user
            display_uninstall_summary
            ;;

        # Management commands
        start)
            start_service
            ;;

        stop)
            stop_service
            ;;

        restart)
            restart_service
            ;;

        status)
            show_status
            ;;

        logs)
            show_logs
            ;;

        ps)
            show_containers
            ;;

        # Maintenance commands
        update)
            update_service
            ;;

        fix-permissions)
            fix_permissions
            ;;

        health)
            check_health
            ;;

        backup)
            create_backup
            ;;

        update-timeouts)
            # Parse optional timeout arguments
            local start_timeout="${1:-$TIMEOUT_START_SEC}"
            local stop_timeout="${2:-$TIMEOUT_STOP_SEC}"
            update_timeouts "$start_timeout" "$stop_timeout"
            ;;

        # Utility commands
        urls)
            show_urls
            ;;

        config)
            show_config
            ;;

        version)
            show_header
            ;;

        help|-h|--help)
            usage
            ;;

        *)
            log_error "Unknown command: $command"
            echo ""
            usage
            exit 1
            ;;
    esac
}

# Trap to handle script interruption
trap 'log_error "Operation interrupted"' INT TERM

# Run main function with all arguments
main "$@"