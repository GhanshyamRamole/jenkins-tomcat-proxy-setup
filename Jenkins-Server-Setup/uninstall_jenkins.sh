#!/bin/bash

# ==============================================================================
# Jenkins & Tomcat Cleanup Script
# Target OS: Amazon Linux 2023
# Description: Removes Jenkins, Tomcat 11, Apache HTTPD configs, and users.
# ==============================================================================

# --- Configuration Variables ---
TOMCAT_USER="tomcat"
TOMCAT_LINK="/usr/share/tomcat"
TOMCAT_SERVICE="/etc/systemd/system/tomcat.service"
APACHE_CONF="/etc/httpd/conf.d/tomcat_manager.conf"

# --- Colors for Output ---
YELLOW='\033[1;33m'
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# --- Helper Functions ---
log_info() {
    echo -e "${GREEN}[INFO] $1${NC}"
}
log_warn() {
    echo -e "${YELLOW}[WARN] $1${NC}"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
       echo -e "${RED}[ERROR] This script must be run as root.${NC}"
       exit 1
    fi
}

# ==============================================================================
# Execution Start
# ==============================================================================

check_root

echo -e "${RED}============================================================${NC}"
echo -e "${RED}   DANGER ZONE: JENKINS UNINSTALLATION                      ${NC}"
echo -e "${RED}============================================================${NC}"
echo "This will delete:"
echo " 1. Jenkins Home (all build data, jobs, plugins)"
echo " 2. Tomcat Installation and Service"
echo " 3. Apache HTTPD specific configs"
echo " 4. Java 21 and Httpd packages"
echo ""
read -p "Are you sure you want to proceed? (y/N): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_info "Operation cancelled."
    exit 1
fi

# 1. Stop Services
log_info "Step 1: Stopping Services..."
systemctl stop tomcat 2>/dev/null || log_warn "Tomcat service not running or not found."
systemctl stop httpd 2>/dev/null || log_warn "Apache service not running or not found."

# 2. Disable Services
log_info "Step 2: Disabling Systemd Services..."
systemctl disable tomcat 2>/dev/null
systemctl disable httpd 2>/dev/null

# 3. Remove Service File
log_info "Step 3: Removing Tomcat Service Definition..."
if [ -f "$TOMCAT_SERVICE" ]; then
    rm -f "$TOMCAT_SERVICE"
    systemctl daemon-reload
    log_info "Service file removed."
else
    log_warn "Service file not found."
fi

# 4. Remove Files and Directories
log_info "Step 4: Deleting Installation Directories..."
# Remove Symlink
if [ -L "$TOMCAT_LINK" ]; then
    rm -f "$TOMCAT_LINK"
    log_info "Symlink /usr/share/tomcat removed."
elif [ -d "$TOMCAT_LINK" ]; then
    rm -rf "$TOMCAT_LINK" # In case it was a real dir
fi

# Remove Actual Folders (Wildcard for version safety)
rm -rf /usr/share/apache-tomcat-*
log_info "Tomcat source directories removed."

# 5. Remove User
log_info "Step 5: Removing Tomcat User..."
if id "$TOMCAT_USER" &>/dev/null; then
    userdel -r "$TOMCAT_USER" 2>/dev/null
    log_info "User '$TOMCAT_USER' deleted."
else
    log_warn "User '$TOMCAT_USER' not found."
fi

# 6. Remove Apache Configs
log_info "Step 6: Removing Apache Reverse Proxy Config..."
if [ -f "$APACHE_CONF" ]; then
    rm -f "$APACHE_CONF"
    log_info "Apache config removed."
else
    log_warn "Apache config file not found."
fi

# 7. Remove Packages
log_info "Step 7: Removing Packages (Java 21 & Httpd)..."
yum remove httpd java-21* -y -q
log_info "Packages removed."

# 8. Clean Firewall
log_info "Step 8: Cleaning Firewall Rules..."
if systemctl is-active --quiet firewalld; then
    firewall-cmd --permanent --remove-port=8080/tcp
    firewall-cmd --reload
    log_info "Port 8080 closed."
fi

log_info "============================================================"
log_info "UNINSTALLATION COMPLETE - System Cleaned"
log_info "============================================================"
