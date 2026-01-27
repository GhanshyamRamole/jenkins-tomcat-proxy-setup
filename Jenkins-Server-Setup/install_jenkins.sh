#!/bin/bash

# ==============================================================================
# Jenkins on Tomcat 11 with Apache Reverse Proxy Setup Script
# Target OS: Amazon Linux 2023
# Description: Automates the installation of Java 21, Tomcat 11, Apache HTTPD,
#              and Jenkins WAR deployment.
# ==============================================================================

# --- Configuration Variables ---
HOSTNAME_VAL="jenkins"
TIMEZONE="Asia/Kolkata"
TOMCAT_VERSION="11.0.18"
TOMCAT_URL="https://dlcdn.apache.org/tomcat/tomcat-11/v11.0.18/bin/apache-tomcat-11.0.18.tar.gz"
JENKINS_WAR_URL="https://get.jenkins.io/war-stable/2.492.1/jenkins.war"
JAVA_PACKAGE="java-21*"
TOMCAT_USER="tomcat"
TOMCAT_INSTALL_DIR="/usr/share/tomcat"
ADMIN_USER="admin"
ADMIN_PASS="111"

# --- Colors for Output ---
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# --- Helper Functions ---
log_info() {
    echo -e "${GREEN}[INFO] $1${NC}"
}

log_error() {
    echo -e "${RED}[ERROR] $1${NC}"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
       log_error "This script must be run as root. Try 'sudo ./install_jenkins.sh'"
       exit 1
    fi
}

# ==============================================================================
# Execution Start
# ==============================================================================

check_root

# 1. System Prep
log_info "Step 1: Setting Hostname and Timezone..."
hostnamectl set-hostname "$HOSTNAME_VAL"
timedatectl set-timezone "$TIMEZONE"

# 2. Install Java
log_info "Step 2: Installing Java 21..."
yum update -y -q
yum install $JAVA_PACKAGE -y -q
java -version

# 3. Create Tomcat User
log_info "Step 3: Creating Tomcat System User..."
if id "$TOMCAT_USER" &>/dev/null; then
    log_info "User $TOMCAT_USER already exists. Skipping."
else
    groupadd --system "$TOMCAT_USER"
    useradd -d "$TOMCAT_INSTALL_DIR" -r -s /bin/false -g "$TOMCAT_USER" "$TOMCAT_USER"
fi

# 4 & 5. Download and Extract Tomcat
log_info "Step 4-6: Downloading and Installing Tomcat $TOMCAT_VERSION..."
cd /tmp
wget -q "$TOMCAT_URL" -O tomcat.tar.gz
tar -xzf tomcat.tar.gz -C /usr/share/
rm -f tomcat.tar.gz

# 6. Create Symlink
# Remove existing link or directory if it exists to avoid errors
rm -rf "$TOMCAT_INSTALL_DIR"
ln -s "/usr/share/apache-tomcat-$TOMCAT_VERSION" "$TOMCAT_INSTALL_DIR"

# 7. Permissions
log_info "Step 7: Updating Permissions..."
chown -R "$TOMCAT_USER":"$TOMCAT_USER" "$TOMCAT_INSTALL_DIR"
chown -R "$TOMCAT_USER":"$TOMCAT_USER" "/usr/share/apache-tomcat-$TOMCAT_VERSION"

# 8. Create Systemd Service
log_info "Step 8: Configuring Systemd Service..."
# Note: Dynamically attempting to locate correct JAVA_HOME, falling back to prompt default
REAL_JAVA_HOME=$(dirname $(dirname $(readlink -f /usr/bin/java)))
if [ -z "$REAL_JAVA_HOME" ]; then
    REAL_JAVA_HOME="/usr/lib/jvm/jre"
fi

cat <<EOF > /etc/systemd/system/tomcat.service
[Unit]
Description=Tomcat Server
After=syslog.target network.target

[Service]
Type=forking
User=$TOMCAT_USER
Group=$TOMCAT_USER

Environment=JAVA_HOME=$REAL_JAVA_HOME
Environment='JAVA_OPTS=-Djava.awt.headless=true'
Environment=CATALINA_HOME=$TOMCAT_INSTALL_DIR
Environment=CATALINA_BASE=$TOMCAT_INSTALL_DIR
Environment=CATALINA_PID=$TOMCAT_INSTALL_DIR/temp/tomcat.pid
Environment='CATALINA_OPTS=-Xms512M -Xmx1024M'
ExecStart=$TOMCAT_INSTALL_DIR/bin/catalina.sh start
ExecStop=$TOMCAT_INSTALL_DIR/bin/catalina.sh stop

[Install]
WantedBy=multi-user.target
EOF

# 9 & 10. Start Tomcat
log_info "Step 9-10: Starting Tomcat..."
systemctl daemon-reload
systemctl start tomcat
systemctl enable tomcat

# 11. Firewall (Conditional for RHEL/CentOS/AL2023 with firewalld)
if systemctl is-active --quiet firewalld; then
    log_info "Step 11: Configuring Firewall..."
    firewall-cmd --permanent --add-port=8080/tcp
    firewall-cmd --reload
else
    log_info "Firewalld not active. Skipping Step 11."
fi

# 12. Configure Tomcat Auth
log_info "Step 12: Configuring Tomcat Users..."
# We overwrite the file to ensure XML integrity
cat <<EOF > "$TOMCAT_INSTALL_DIR/conf/tomcat-users.xml"
<?xml version="1.0" encoding="UTF-8"?>
<tomcat-users xmlns="http://tomcat.apache.org/xml"
              xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
              xsi:schemaLocation="http://tomcat.apache.org/xml tomcat-users.xsd"
              version="1.0">
  <role rolename="admin-gui"/>
  <role rolename="manager-gui"/>
  <user username="$ADMIN_USER" password="$ADMIN_PASS" fullName="Administrator" roles="admin-gui,manager-gui"/>
</tomcat-users>
EOF

# 13. Restart Tomcat
systemctl restart tomcat

# 14. Apache Proxy Setup
log_info "Step 14: Installing Apache HTTPD..."
yum install httpd -y -q

# 15. VirtualHost Config
log_info "Step 15: Configuring Apache Reverse Proxy..."
SERVER_IP=$(hostname -I | awk '{print $1}')
cat <<EOF > /etc/httpd/conf.d/tomcat_manager.conf
<VirtualHost *:80>
    ServerAdmin root@localhost
    ServerName tomcat.example.com
    DefaultType text/html
    ProxyRequests off
    ProxyPreserveHost On
    ProxyPass / http://localhost:8080/
    ProxyPassReverse / http://localhost:8080/
</VirtualHost>

<VirtualHost *:80>
  ServerName ajp.example.com
  ProxyRequests Off
  ProxyPass / ajp://localhost:8009/
  ProxyPassReverse / ajp://localhost:8009/
</VirtualHost>
EOF

# 16. Start Apache
log_info "Step 16: Starting Apache..."
systemctl start httpd
systemctl enable httpd

# 19. Download Jenkins
log_info "Step 19: Deploying Jenkins WAR..."
cd "$TOMCAT_INSTALL_DIR/webapps"
if [ -f "jenkins.war" ]; then
    rm -f jenkins.war
fi
wget -q "$JENKINS_WAR_URL"

# 20. Restart Tomcat to Deploy
log_info "Step 20: Restarting Tomcat to trigger deployment..."
systemctl restart tomcat

# Waiting for deployment to initialize
log_info "Waiting 30 seconds for Jenkins to initialize..."
sleep 30

# 21. Retrieve Password
log_info "============================================================"
log_info "INSTALLATION COMPLETE"
log_info "============================================================"
echo "Access Jenkins at: http://"$(curl ifconfig.me)"/jenkins"
echo "Tomcat Manager at: http://"$(curl ifconfig.me)"/manager/html (User: $ADMIN_USER / Pass: $ADMIN_PASS)"
echo ""
echo "Attempting to retrieve Initial Admin Password..."

PASSWORD_FILE="$TOMCAT_INSTALL_DIR/.jenkins/secrets/initialAdminPassword"

if [ -f "$PASSWORD_FILE" ]; then
    echo -e "${GREEN}INITIAL ADMIN PASSWORD:${NC}"
    cat "$PASSWORD_FILE"
    echo ""
else
    echo -e "${RED}Password file not found yet. Jenkins is still initializing.${NC}"
    echo "Check manually later: cat $PASSWORD_FILE"
fi
echo "============================================================"
