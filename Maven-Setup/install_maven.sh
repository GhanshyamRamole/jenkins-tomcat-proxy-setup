#!/bin/bash

# ==============================================================================
# Maven Installation & Environment Setup Script (v2 - Robust)
# Target OS: Amazon Linux 2023
# Fixes: "mvn: command not found" by forcing a /usr/bin symlink.
# ==============================================================================

# --- Configuration ---
MAVEN_VERSION="3.9.12"
MAVEN_URL="https://dlcdn.apache.org/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.tar.gz"
INSTALL_DIR="/opt"
MAVEN_HOME="${INSTALL_DIR}/apache-maven-${MAVEN_VERSION}"
WORKSPACE_DIR="/myproject"

# --- Colors ---
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

check_root() {
    if [[ $EUID -ne 0 ]]; then
       echo -e "${RED}[ERROR] Must be run as root.${NC}"
       exit 1
    fi
}

check_root

echo -e "${GREEN}[INFO] Step 26: Downloading and Installing Maven...${NC}"

# 1. Download and Extract
cd "$INSTALL_DIR" || exit
if [ -d "$MAVEN_HOME" ]; then
    echo -e "${GREEN}[INFO] Maven directory already exists. Skipping download.${NC}"
else
    wget -q "$MAVEN_URL" -O maven.tar.gz
    if [ $? -ne 0 ]; then
        echo -e "${RED}[ERROR] Failed to download Maven. Check version number or internet connection.${NC}"
        exit 1
    fi
    tar -xzf maven.tar.gz
    rm -f maven.tar.gz
    echo -e "${GREEN}[INFO] Maven extracted to $MAVEN_HOME${NC}"
fi

# 2. THE FIX: Create System-Wide Symlinks
# This makes 'mvn' available instantly without needing to 'source' files.
echo -e "${GREEN}[INFO] Creating system-wide symlinks...${NC}"

# Remove old link if exists and create new one
if [ -L "/usr/bin/mvn" ]; then
    rm -f /usr/bin/mvn
fi
ln -s "${MAVEN_HOME}/bin/mvn" /usr/bin/mvn

echo -e "${GREEN}[INFO] Symlink created: /usr/bin/mvn -> ${MAVEN_HOME}/bin/mvn${NC}"

# 3. Dynamic Java Home Detection
REAL_JAVA_HOME=$(dirname $(dirname $(readlink -f /usr/bin/java)))
if [ -z "$REAL_JAVA_HOME" ]; then
    REAL_JAVA_HOME="/usr/lib/jvm/java-17-amazon-corretto.x86_64" 
fi

# 4. Configure Environment Variables (Required for Jenkins to find M2_HOME)
echo -e "${GREEN}[INFO] Step 27: Configuring Environment Variables...${NC}"

cat <<EOF > /etc/profile.d/maven.sh
export JAVA_HOME=${REAL_JAVA_HOME}
export MAVEN_HOME=${MAVEN_HOME}
export M2_HOME=${MAVEN_HOME}
export PATH=\${PATH}:\${JAVA_HOME}/bin:\${MAVEN_HOME}/bin
EOF

chmod +x /etc/profile.d/maven.sh

# 5. Prepare Custom Workspace (Step 30 Prep)
echo -e "${GREEN}[INFO] Preparing custom workspace directory...${NC}"
mkdir -p "$WORKSPACE_DIR"
if id "tomcat" &>/dev/null; then
    chown -R tomcat:tomcat "$WORKSPACE_DIR"
    chmod 755 "$WORKSPACE_DIR"
fi

# 6. Verify
echo -e "${GREEN}=============================================${NC}"
echo -e "${GREEN} INSTALLATION COMPLETE ${NC}"
echo -e "${GREEN}=============================================${NC}"

# Verify immediately using the symlink
/usr/bin/mvn --version
