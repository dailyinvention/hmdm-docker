#!/bin/bash
set -e

# This script downloads and installs Headwind MDM in non-interactive mode
# It supports both:
# Option 1: Using pre-downloaded installer (RECOMMENDED - no network issues)
# Option 2: Downloading from internet during startup

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

mkdir -p "${HMDM_INSTALL_DIR}"
cd "${HMDM_INSTALL_DIR}"

# Clean up any previous extraction attempt
rm -rf hmdm-install hmdm-install.zip

# Option 1: Check for pre-downloaded installer (RECOMMENDED)
if [ -d "/hmdm-pre-downloaded" ] && [ -f "/hmdm-pre-downloaded/hmdm-${HMDM_VERSION}-install-ubuntu.zip" ]; then
    echo "✓ Option 1: Using pre-downloaded installer (no network required)"
    cp "/hmdm-pre-downloaded/hmdm-${HMDM_VERSION}-install-ubuntu.zip" ./hmdm-install.zip
else
    # Option 2: Download from internet (fallback)
    echo "Pre-downloaded installer not found, attempting Option 2: download from internet..."
    echo ""
    
    # Make sure we have internet connectivity
    echo "Checking internet connectivity..."
    for i in {1..15}; do
        if wget --timeout=10 --tries=2 -q -O /tmp/test.html https://h-mdm.com 2>/dev/null; then
            echo "Internet connection verified"
            rm -f /tmp/test.html
            break
        else
            if [ $i -lt 15 ]; then
                echo "Connection attempt $i/15 failed, retrying..."
                sleep 3
            else
                echo "ERROR: Cannot reach h-mdm.com after 15 attempts."
                echo ""
                echo "Troubleshooting:"
                echo "1. Use Option 1 (pre-download): mkdir -p hmdm-installer && wget https://h-mdm.com/files/hmdm-install.zip -O hmdm-installer/"
                echo "2. Verify Docker has internet access: docker run --rm alpine wget -q -O - https://h-mdm.com"
                echo "3. Check if DNS is working: docker run --rm alpine nslookup h-mdm.com"
                echo "4. Check your network/firewall settings"
                exit 1
            fi
        fi
    done

    echo "Downloading Headwind MDM installer (version ${HMDM_VERSION})..."
    if ! wget -q "${HMDM_INSTALL_URL}" -O hmdm-install.zip; then
        echo "ERROR: Failed to download Headwind MDM installer"
        echo "Please check the version number or visit https://h-mdm.com/download"
        exit 1
    fi
fi

echo "Extracting installer..."
if ! unzip -o -q hmdm-install.zip; then
    echo "ERROR: Failed to extract installer"
    exit 1
fi

cd hmdm-install/

echo ""
echo "Running Headwind MDM installation..."
echo "This may take several minutes..."
echo ""

# Run the installer with automated responses via stdin
if [ -f "./hmdm_install.sh" ]; then
    # Prepare responses for the installer's interactive prompts
    (
        echo "n"       # Install missing package(s) - answer NO (already installed)
        echo "Y"       # Proceed as current user - YES
        sleep 1
        echo "/var/lib/tomcat9"  # Tomcat base directory
        echo "localhost"  # Database host
        echo "5432"     # Database port
        echo "hmdm"     # Database user
        echo "${DB_PASSWORD}"  # Database password
        echo "hmdm"     # Database name
        echo ""        # Default location
        echo "Y"       # Continue
        echo "Y"       # YES, I want to continue
    ) | timeout 600 bash ./hmdm_install.sh > /tmp/hmdm_install.log 2>&1 &
    INSTALLER_PID=$!
    
    # Wait for the installer to complete with a longer timeout
    wait $INSTALLER_PID
    if [ $? -eq 0 ]; then
        echo "✓ HMDM installation completed successfully"
    else
        echo "⚠ HMDM installer exited with status code $?"
        echo "Last 50 lines of installation log:"
        tail -50 /tmp/hmdm_install.log
    fi
else
    echo "ERROR: hmdm_install.sh not found in the installation package"
    exit 1
fi

echo ""
echo "Next steps:"
echo "1. Access the admin panel at https://${HMDM_SERVER_URL}"
echo "2. Login with default credentials: admin:admin"
echo "3. Change your password (you will be prompted)"
echo "4. Configure your MDM policies"
echo ""

