#!/bin/bash
echo VPS Automated Setup Script
echo Description: Configures Ubuntu server with Docker, firewall, and basic security

set -e # Exit immediately on error

# Execution lock to prevent reruns
LOCK_FILE="/etc/vps-setup.lock"
if [ -f "$LOCK_FILE" ]; then
    echo "Setup already completed. Remove $LOCK_FILE to rerun."
    exit 0
fi

# Output formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_section() {
    echo -e "\n${YELLOW}### ${1} ${NC}"
}

# Validate root execution
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}Error: Root privileges required${NC}" >&2
    exit 1
fi

# Main execution block
{
    print_section "System Initialization"
    apt-get update
    apt-get upgrade -y
    apt-get install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        software-properties-common

    print_section "Firewall Configuration"
    apt-get install -y ufw
    ufw --force reset
    ufw allow ssh     # Allow default SSH port
    ufw allow 80/tcp  # HTTP
    ufw allow 443/tcp # HTTPS
    ufw default deny incoming
    ufw default allow outgoing
    ufw --force enable
    systemctl enable ufw

    print_section "Docker Installation"
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
    https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    tee /etc/apt/sources.list.d/docker.list > /dev/null

    # Install Docker components
    apt-get update
    apt-get install -y \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin

    print_section "Security Setup"
    apt-get install -y fail2ban
    systemctl enable fail2ban

    print_section "Cleanup"
    apt-get autoremove -y
    apt-get clean

    # Create lock file
    touch $LOCK_FILE
    chmod 400 $LOCK_FILE

    echo -e "\n${GREEN}=== Setup Completed Successfully ===${NC}"
    echo -e "${YELLOW}Next steps:"
    echo -e "- Configure application-specific firewall rules"
    echo -e "- Set up monitoring and logging"
    echo -e "- Review Fail2Ban configuration${NC}"

} || {
    echo -e "${RED}!!! Setup Failed - Removing Lock File !!!${NC}"
    rm -f $LOCK_FILE
    exit 1
}