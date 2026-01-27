# Jenkins on Tomcat with Apache Reverse Proxy

![Project Status](https://img.shields.io/badge/status-active-brightgreen)
![OS](https://img.shields.io/badge/OS-Amazon_Linux_2023-orange)
![Java](https://img.shields.io/badge/Java-21-red)
![Tomcat](https://img.shields.io/badge/Tomcat-11-yellow)

## 📋 Project Overview

This project provides a fully automated Bash script solution to deploy **Jenkins** on an **Amazon Linux 2023** server. 

Unlike standard installations, this project implements a production-grade **"Reverse Proxy" architecture**. Jenkins runs as a `.war` deployment inside **Apache Tomcat 11**, hidden behind an **Apache HTTP Server (httpd)** gateway. This setup enhances security and flexibility by serving traffic over standard HTTP port 80 instead of the default Tomcat port 8080.

### 🏗 Architecture
**User** (Port 80) ➡️ **Apache HTTPD** (Proxy) ➡️ **Tomcat** (Port 8080) ➡️ **Jenkins App**

## 🚀 Features
* **Automated Setup:** Installs Java 21, Tomcat 11, Apache HTTPD, and Jenkins in <2 minutes.
* **Reverse Proxy:** Configures `mod_proxy` to forward traffic from Port 80 to 8080.
* **Self-Healing:** Scripts include idempotency checks (won't fail if run twice).
* **Cleanup Utility:** Includes a full uninstallation script to reset the environment.
* **Dynamic Configuration:** Automatically detects server IP and creates valid XML/Service files.

---

## 🛠 Prerequisites

* **Operating System:** Amazon Linux 2023 (AMI 2023).
* **User:** Root privileges (sudo).
* **Network/Security Group:**
    * **Port 80 (HTTP):** Open to 0.0.0.0/0 (for Web Access).
    * **Port 22 (SSH):** Open to Admin IP.

---

## 📥 Installation

1.  **Clone the Repository** (or download the scripts):
    ```bash
    git clone [https://github.com/YourUsername/jenkins-tomcat-proxy-setup.git](https://github.com/YourUsername/jenkins-tomcat-proxy-setup.git)
    cd jenkins-tomcat-proxy-setup
    ```

2.  **Make Scripts Executable:**
    ```bash
    chmod +x install_jenkins.sh uninstall_jenkins.sh
    ```

3.  **Run the Installer:**
    ```bash
    sudo ./install_jenkins.sh
    ```

### What the Script Does:
1.  Sets system hostname and timezone (Asia/Kolkata).
2.  Installs **Java 21 (Corretto)**.
3.  Creates a dedicated `tomcat` system user.
4.  Downloads and configures **Tomcat 11**.
5.  Sets up **Systemd services** for auto-start on boot.
6.  Installs **Apache HTTPD** and configures the `VirtualHost` proxy.
7.  Deploys the latest **Jenkins WAR** file.

---

## 🔐 Post-Installation Setup

Once the script finishes, it will display the access URLs.

1.  **Access the Dashboard:**
    Open your browser and navigate to:
    `http://<YOUR_PUBLIC_IP>/jenkins`

2.  **Unlock Jenkins:**
    The script attempts to print the initial password at the end of the log. If it wasn't ready yet, run this command on your server to get it:
    ```bash
    sudo cat /usr/share/tomcat/.jenkins/secrets/initialAdminPassword
    ```

3.  **Complete Wizard:**
    * Paste the password.
    * Select **"Install Suggested Plugins"**.
    * Create your first Admin User.

---

## 🧹 Uninstallation

To completely remove Jenkins, Tomcat, Apache, and all related configuration files (useful for testing or resetting):

```bash
sudo ./uninstall_jenkins.sh
```

