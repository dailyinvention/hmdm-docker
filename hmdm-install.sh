#!/bin/bash
set -e

# This script downloads and installs Headwind MDM in non-interactive mode
# It assumes PostgreSQL is already set up with the database and user

HMDM_VERSION="5.37"
HMDM_INSTALL_URL="https://h-mdm.com/files/hmdm-${HMDM_VERSION}-install-ubuntu.zip"
HMDM_INSTALL_DIR="/tmp/hmdm-install"

echo "================================"
echo "Headwind MDM Installation Script"
echo "================================"
echo ""

# Check if already installed
if [ -f "/var/lib/tomcat9/webapps/ROOT.war" ]; then
    echo "Headwind MDM appears to already be installed (ROOT.war exists)"
    echo "Skipping installation..."
    exit 0
fi

# Make sure we have internet connectivity
echo "Checking internet connectivity..."
if ! wget --spider https://h-mdm.com 2>/dev/null; then
    echo "ERROR: Cannot reach h-mdm.com. Check your internet connection."
    exit 1
fi

echo "Downloading Headwind MDM installer (version ${HMDM_VERSION})..."
mkdir -p "${HMDM_INSTALL_DIR}"
cd "${HMDM_INSTALL_DIR}"

if ! wget -q "${HMDM_INSTALL_URL}" -O hmdm-install.zip; then
    echo "ERROR: Failed to download Headwind MDM installer"
    echo "Please check the version number or visit https://h-mdm.com/download"
    exit 1
fi

echo "Extracting installer..."
if ! unzip -q hmdm-install.zip; then
    echo "ERROR: Failed to extract installer"
    exit 1
fi

cd hmdm-install/

echo ""
echo "Running Headwind MDM installation..."
echo "This may take several minutes..."
echo ""

# Run the installer
# Note: The installer will be interactive and prompt for configuration
# You can respond to the prompts or use expect scripts for full automation
if [ -f "./hmdm_install.sh" ]; then
    bash ./hmdm_install.sh
else
    echo "ERROR: hmdm_install.sh not found in the installation package"
    exit 1
fi

echo ""
echo "Installation complete!"
echo ""
echo "Next steps:"
echo "1. Access the admin panel at https://${HMDM_SERVER_URL}"
echo "2. Login with default credentials: admin:admin"
echo "3. Change your password (you will be prompted)"
echo "4. Configure your MDM policies"
echo ""

