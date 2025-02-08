#!/bin/bash
# VPS Initial Setup Script
# Description: Automates Ubuntu server setup with Docker, security hardening, and firewall configuration
# Includes one-time execution lock and SSH key handling for CI/CD pipelines

set -e # Exit immediately if any command fails

# One-time execution lock
LOCK_FILE="/etc/vps-setup.lock"
if [ -f "$LOCK_FILE" ]; then
    echo "Setup already completed. Remove $LOCK_FILE to rerun."
    exit 0
fi

# Configuration handling
CONFIG_FILE=${1:-.env.conf}
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
    echo "Loaded configuration from: $CONFIG_FILE"
else
    echo "Using default configuration (file not found: $CONFIG_FILE)"
fi

# Default configuration values (override in .env.conf)
SSH_PORT=${SSH_PORT:-22}
DISABLE_ROOT_SSH=${DISABLE_ROOT_SSH:-false}
DISABLE_PASSWORD_AUTH=${DISABLE_PASSWORD_AUTH:-false}
CREATE_SUDO_USER=${CREATE_SUDO_USER:-false}
USERNAME=${USERNAME:-admin}
UFW_PORTS_OPEN=${UFW_PORTS_OPEN:-22,80,443}
INSTALL_FAIL2BAN=${INSTALL_FAIL2BAN:-true}
ENABLE_AUTO_UPDATES=${ENABLE_AUTO_UPDATES:-false}
SSH_PUBLIC_KEY=${SSH_PUBLIC_KEY:-""}

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_section() {
    echo -e "\n${YELLOW}### ${1} ${NC}"
}

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}Error: This script must be run as root${NC}" >&2
    exit 1
fi

# Main setup logic
{
    print_section "System Update & Upgrade"
    apt-get update
    apt-get upgrade -y
    apt-get install -y apt-transport-https ca-certificates curl software-properties-common

    if [ "$CREATE_SUDO_USER" = "true" ]; then
        print_section "Create Sudo User"
        if ! id "$USERNAME" &>/dev/null; then
            adduser --gecos "" --disabled-password $USERNAME
            usermod -aG sudo $USERNAME
            echo -e "${GREEN}Created sudo user: $USERNAME ${NC}"

            # SSH key handling
            if [ -n "$SSH_PUBLIC_KEY" ]; then
                mkdir -p /home/$USERNAME/.ssh
                echo "$SSH_PUBLIC_KEY" >> /home/$USERNAME/.ssh/authorized_keys
                chown -R $USERNAME:$USERNAME /home/$USERNAME/.ssh
                chmod 700 /home/$USERNAME/.ssh
                chmod 600 /home/$USERNAME/.ssh/authorized_keys
                echo -e "${GREEN}Added SSH public key to $USERNAME account${NC}"
            fi
        fi
    fi

    print_section "Firewall Configuration"
    apt-get install -y ufw
    ufw --force reset

    IFS=',' read -ra PORTS <<< "$UFW_PORTS_OPEN"
    for port in "${PORTS[@]}"; do
        ufw allow $port/tcp
        echo "Opened port: $port/tcp"
    done

    ufw default deny incoming
    ufw default allow outgoing
    ufw --force enable
    systemctl enable ufw

    print_section "SSH Hardening"
    sed -i "s/#Port 22/Port $SSH_PORT/" /etc/ssh/sshd_config

    if [ "$DISABLE_ROOT_SSH" = "true" ]; then
        sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
        echo -e "${GREEN}Disabled root SSH access${NC}"
    fi

    # Password authentication handling
    if [ "$DISABLE_PASSWORD_AUTH" = "true" ]; then
        if [ -z "$SSH_PUBLIC_KEY" ]; then
            echo -e "${RED}ERROR: Cannot disable password auth without providing SSH public key${NC}"
            exit 1
        fi
        sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
        echo -e "${GREEN}Disabled SSH password authentication${NC}"
    fi

    systemctl restart sshd

    print_section "Docker Installation"
    # Install Docker using official repository
    apt-get update
    apt-get install -y ca-certificates curl
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc

    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
      tee /etc/apt/sources.list.d/docker.list > /dev/null

    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    print_section "Security Enhancements"
    if [ "$INSTALL_FAIL2BAN" = "true" ]; then
        apt-get install -y fail2ban
        systemctl enable fail2ban
        echo -e "${GREEN}Installed Fail2Ban intrusion prevention${NC}"
    fi

    if [ "$ENABLE_AUTO_UPDATES" = "true" ]; then
        apt-get install -y unattended-upgrades
        dpkg-reconfigure -plow unattended-upgrades
        echo -e "${GREEN}Enabled automatic security updates${NC}"
    fi

    print_section "Cleanup"
    apt-get autoremove -y
    apt-get clean

    # Create lock file
    touch $LOCK_FILE
    chmod 400 $LOCK_FILE

    echo -e "\n${GREEN}=== Setup Complete ===${NC}"
    echo -e "${YELLOW}Important reminders:"
    echo -e "1. SSH Port: $SSH_PORT"
    [ "$CREATE_SUDO_USER" = "true" ] && echo -e "2. User account: $USERNAME"
    [ -n "$SSH_PUBLIC_KEY" ] && echo -e "3. SSH key installed for $USERNAME"
    [ "$DISABLE_PASSWORD_AUTH" = "true" ] && echo -e "4. Password authentication DISABLED"
    echo -e "${NC}"
} || {
    echo -e "${RED}!!! Setup failed - removing lock file !!!${NC}"
    rm -f $LOCK_FILE
    exit 1
}