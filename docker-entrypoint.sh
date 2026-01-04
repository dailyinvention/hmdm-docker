#!/bin/bash
set -e

echo "Starting Headwind MDM Docker container..."

# Wait for PostgreSQL to be available with longer timeout
echo "Waiting for PostgreSQL to be available (this may take 30-60 seconds)..."
MAX_ATTEMPTS=120  # 2 minutes with 1-second intervals
ATTEMPT=0

until pg_isready -h "${DB_HOST:-postgres}" -U postgres > /dev/null 2>&1; do
  ATTEMPT=$((ATTEMPT + 1))
  if [ $ATTEMPT -ge $MAX_ATTEMPTS ]; then
    echo "ERROR: PostgreSQL failed to start after ${MAX_ATTEMPTS} seconds"
    echo "Checking PostgreSQL container logs:"
    docker logs headwind-postgres 2>&1 | tail -20
    exit 1
  fi
  if [ $((ATTEMPT % 10)) -eq 0 ]; then
    echo "PostgreSQL is unavailable - sleeping (attempt $ATTEMPT/$MAX_ATTEMPTS)"
  fi
  sleep 1
done
echo "PostgreSQL is available"

# Setup database on first-time installation
echo "Verifying database setup..."
PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST:-postgres}" -U "${DB_USER}" -d "${DB_NAME}" -c "SELECT 1" > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "Database ${DB_NAME} is accessible"
else
    echo "Database ${DB_NAME} not accessible, attempting to create..."
    # The POSTGRES_USER (DB_USER) is the superuser when POSTGRES_USER is specified
    PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST:-postgres}" -U "${DB_USER}" -d postgres -c "CREATE DATABASE ${DB_NAME};" 2>/dev/null || echo "Database ${DB_NAME} already exists"
    echo "Database setup complete"
fi

# Define Tomcat webapps directory (using Apache Tomcat from /opt/tomcat)
TOMCAT_WEBAPPS="/opt/tomcat/webapps"
TOMCAT_CONF="/opt/tomcat/conf/Catalina/localhost"

# Check if HMDM is already deployed (check for WEB-INF which indicates a deployed WAR)
if [ ! -d "$TOMCAT_WEBAPPS/ROOT/WEB-INF" ] && [ ! -f "$TOMCAT_WEBAPPS/ROOT.war" ]; then
    echo "Headwind MDM not installed. Deploying from pre-downloaded installer..."
    
    # Create temp directory for installer
    TEMP_INSTALL_DIR="/tmp/hmdm-install-temp"
    rm -rf "$TEMP_INSTALL_DIR"
    mkdir -p "$TEMP_INSTALL_DIR"
    
    # Extract the pre-downloaded installer
    if [ -d "/hmdm-pre-downloaded" ] && [ -f "/hmdm-pre-downloaded/hmdm-5.37-install-ubuntu.zip" ]; then
        echo "✓ Using pre-downloaded HMDM installer..."
        cd "$TEMP_INSTALL_DIR" && unzip -o -q "/hmdm-pre-downloaded/hmdm-5.37-install-ubuntu.zip" && cd /
    else
        echo "ERROR: Pre-downloaded installer not found at /hmdm-pre-downloaded/hmdm-5.37-install-ubuntu.zip"
        exit 1
    fi
    
    # Deploy the WAR file directly to ROOT directory
    if [ -f "$TEMP_INSTALL_DIR/hmdm-install/hmdm-5.37.3-os.war" ]; then
        echo "✓ Found hmdm-5.37.3-os.war, extracting to ROOT directory..."
        mkdir -p "$TOMCAT_WEBAPPS/ROOT"
        cd "$TOMCAT_WEBAPPS/ROOT" && unzip -o -q "$TEMP_INSTALL_DIR/hmdm-install/hmdm-5.37.3-os.war" && cd /
    else
        echo "ERROR: WAR file not found in installer"
        exit 1
    fi
    
    # Create HMDM work directory structure
    mkdir -p /opt/tomcat/work/hmdm/files
    mkdir -p /opt/tomcat/work/hmdm/plugins
    chmod -R 755 /opt/tomcat/work/hmdm
    
    # Create Tomcat context configuration directory
    mkdir -p "$TOMCAT_CONF"
    
    # Create the ROOT.xml Tomcat context configuration with all HMDM parameters
    # This is the proper way HMDM loads configuration - via Tomcat Context Parameters
    echo "Creating Tomcat context configuration for HMDM..."
    cat > "$TOMCAT_CONF/ROOT.xml" << 'TOMCAT_CONTEXT'
<?xml version="1.0" encoding="UTF-8"?>
<Context>
    <!-- database configurations -->
    <Parameter name="JDBC.driver"   value="org.postgresql.Driver"/>
    <Parameter name="JDBC.url"      value="jdbc:postgresql://postgres:5432/hmdm"/>
    <Parameter name="JDBC.username" value="hmdm"/>
    <Parameter name="JDBC.password" value="topsecret"/>

    <!-- This directory is used to as a base directory to store app data -->
    <Parameter name="base.directory" value="/opt/tomcat/work/hmdm"/>
    
    <!-- This directory is used to store uploaded app files, must be accessible for tomcat user -->
    <Parameter name="files.directory" value="/opt/tomcat/work/hmdm/files"/>
    
    <!-- URL used to open Headwind MDM control panel -->
    <Parameter name="base.url" value="https://hmdm.example.com/ROOT"/>
    
    <!-- private / shared; shared can be used only in Enterprise solution -->
    <Parameter name="usage.scenario" value="private" />

    <!-- If set to 1, the device configuration request must be signed by a shared secret -->
    <Parameter name="secure.enrollment" value="0"/>
    
    <!-- A shared secret between mobile app and control panel -->
    <Parameter name="hash.secret" value="changeme-C3z9vi54"/>
    
    <!-- This directory is used to store files by plugins -->
    <Parameter name="plugins.files.directory" value="/opt/tomcat/work/hmdm/plugins"/>
    
    <!-- Configuration for logging plugin -->
    <Parameter name="plugin.devicelog.persistence.config.class" value="com.hmdm.plugins.devicelog.persistence.postgres.DeviceLogPostgresPersistenceConfiguration"/>
    
    <!-- Don't change this -->
    <Parameter name="role.orgadmin.id" value="2"/>

    <!-- Swagger Docs UI location -->
    <Parameter name="swagger.host" value="hmdm.example.com"/>
    <Parameter name="swagger.base.path" value="/ROOT/rest"/>
    
    <Parameter name="initialization.completion.signal.file" value="/opt/tomcat/work/hmdm/.initialized"/>
    <Parameter name="log4j.config" value="file:///opt/tomcat/work/hmdm/log4j-hmdm.xml"/>
    <Parameter name="aapt.command" value="aapt"/>

    <!-- MQTT notification service parameters -->
    <Parameter name="mqtt.server.uri" value="localhost:31000"/>
    
    <!-- Fast device search by last characters -->
    <Parameter name="device.fast.search.chars" value="5"/>

    <!-- MQTT authentication for more security -->
    <Parameter name="mqtt.auth" value="1"/> 

    <!-- Email parameters are necessary for password recovery -->
    <Parameter name="smtp.host" value="smtp.example.com"/>
    <Parameter name="smtp.port" value="587"/>
    <Parameter name="smtp.ssl" value="0"/>
    <Parameter name="smtp.starttls" value="0"/>
    <Parameter name="smtp.username" value=""/>
    <Parameter name="smtp.password" value=""/>
    <Parameter name="smtp.from" value="admin@hmdm.example.com"/>
    
    <!-- Email templates location -->
    <Parameter name="email.recovery.subj" value="/opt/tomcat/work/hmdm/emails/_LANGUAGE_/recovery_subj.txt"/>
    <Parameter name="email.recovery.body" value="/opt/tomcat/work/hmdm/emails/_LANGUAGE_/recovery_body.txt"/>
    
    <!-- APK trusted URL -->
    <Parameter name="apk.trusted.url" value="https://h-mdm.com"/>
    
</Context>
TOMCAT_CONTEXT
    
    echo "✓ Tomcat context configuration created at $TOMCAT_CONF/ROOT.xml"
    
    # Clean up
    cd /
    rm -rf "$TEMP_INSTALL_DIR"
    
    # Verify deployment
    if [ -d "$TOMCAT_WEBAPPS/ROOT/WEB-INF" ]; then
        echo "✓ HMDM deployment verified"
        echo "✓ Configuration file: $TOMCAT_CONF/ROOT.xml"
    else
        echo "ERROR: HMDM deployment failed"
        exit 1
    fi
else
    echo "Headwind MDM already installed, skipping deployment"
fi

# Substitute environment variables in the nginx config file
echo "Configuring Nginx..."

# Use cert directory that can be in a volume
CERT_DIR="/var/lib/hmdm/certs"
KEY_DIR="/var/lib/hmdm/private"
mkdir -p "$CERT_DIR" "$KEY_DIR"

# Check if SSL certificates exist, if not create self-signed for testing
if [ ! -f "$CERT_DIR/hmdm.crt" ] || [ ! -f "$KEY_DIR/hmdm.key" ]; then
    echo "SSL certificates not found, generating self-signed certificate for testing..."
    
    # Generate with better error reporting to writable location
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "$KEY_DIR/hmdm.key" \
        -out "$CERT_DIR/hmdm.crt" \
        -subj "/CN=${HMDM_SERVER_URL:-localhost}"
    
    # Check if generation was successful
    if [ $? -eq 0 ] && [ -f "$CERT_DIR/hmdm.crt" ]; then
        echo "✓ Self-signed certificate created"
        chmod 644 "$CERT_DIR/hmdm.crt"
        chmod 600 "$KEY_DIR/hmdm.key"
    else
        echo "⚠ Failed to generate SSL certificate"
        ls -la "$CERT_DIR/" 2>&1 || echo "  → Certificate directory listing failed"
        ls -la "$KEY_DIR/" 2>&1 || echo "  → Key directory listing failed"
    fi
fi

# Update environment variables for nginx config
export SSL_CERTIFICATE_PATH="$CERT_DIR/hmdm.crt"
export SSL_CERTIFICATE_KEY_PATH="$KEY_DIR/hmdm.key"

envsubst '\
    ${HMDM_SERVER_URL},\
    ${SSL_CERTIFICATE_PATH},\
    ${SSL_CERTIFICATE_KEY_PATH}' \
  < /etc/nginx/sites-available/headwind.conf.template \
  > /etc/nginx/sites-available/headwind.conf

# Create symlink to enable the site
ln -sf /etc/nginx/sites-available/headwind.conf /etc/nginx/sites-enabled/headwind.conf

# Test nginx configuration (retry a few times)
NGINX_TEST_RETRIES=5
NGINX_TEST_COUNT=0
while [ $NGINX_TEST_COUNT -lt $NGINX_TEST_RETRIES ]; do
    if nginx -t 2>/dev/null; then
        echo "✓ Nginx configuration valid"
        break
    else
        NGINX_TEST_COUNT=$((NGINX_TEST_COUNT + 1))
        if [ $NGINX_TEST_COUNT -lt $NGINX_TEST_RETRIES ]; then
            echo "⚠ Nginx config test failed (attempt $NGINX_TEST_COUNT/$NGINX_TEST_RETRIES), retrying..."
            sleep 1
        else
            echo "✗ Nginx config test failed after $NGINX_TEST_RETRIES attempts"
            echo "Checking for certificate files:"
            ls -la /etc/ssl/certs/hmdm.crt 2>&1 || echo "  → Certificate file not found"
            ls -la /etc/ssl/private/hmdm.key 2>&1 || echo "  → Key file not found"
        fi
    fi
done

echo "Starting Nginx..."
nginx -g "daemon off;" &

echo "Starting Tomcat 9..."
# Change to a valid directory before starting Tomcat
cd /opt/tomcat

# Create HMDM work directories
mkdir -p /opt/tomcat/work/hmdm/files
mkdir -p /opt/tomcat/work/hmdm/plugins

# Set Tomcat system properties for HMDM configuration as a single line
export CATALINA_OPTS="-Djdbc.driver=org.postgresql.Driver -Djdbc.url=jdbc:postgresql://${DB_HOST:-postgres}:${DB_PORT:-5432}/${DB_NAME:-hmdm} -Djdbc.username=${DB_USER:-hmdm} -Djdbc.password=${DB_PASSWORD:-topsecret} -Dbase.directory=/opt/tomcat/work/hmdm -Dfiles.directory=/opt/tomcat/work/hmdm/files -Dplugins.files.directory=/opt/tomcat/work/hmdm/plugins -Dbase.url=https://${HMDM_SERVER_URL:-hmdm.example.com} -Dusage.scenario=private -Dhash.secret=changeme-C3z9vi54 -Dsecure.enrollment=0 -Drole.orgadmin.id=2 -Ddevice.fast.search.chars=5 -Dmqtt.auth=1 -Dmqtt.server.uri=${HMDM_SERVER_URL:-hmdm.example.com}:31000 -Dsmtp.host= -Dsmtp.port=25 -Dsmtp.ssl=0 -Dsmtp.starttls=0 -Dsmtp.username= -Dsmtp.password= -Dsmtp.from=noreply@${HMDM_SERVER_URL:-hmdm.example.com} -Daapt.command=aapt -Dswagger.host=${HMDM_SERVER_URL:-hmdm.example.com} -Dswagger.base.path=/rest"

echo "Configuration summary:"
echo "  Database: jdbc:postgresql://${DB_HOST:-postgres}:${DB_PORT:-5432}/${DB_NAME:-hmdm}"
echo "  Base URL: https://${HMDM_SERVER_URL:-hmdm.example.com}"
echo "  Work directory: /opt/tomcat/work/hmdm"
echo ""

# Start Tomcat in foreground so Docker container stays running
if [ -x /opt/tomcat/bin/catalina.sh ]; then
    /opt/tomcat/bin/catalina.sh run
else
    echo "⚠ Tomcat startup failed - catalina.sh not found at /opt/tomcat/bin/catalina.sh"
    exit 1
fi &

echo "Headwind MDM is starting..."
echo "  - Nginx: https://${HMDM_SERVER_URL} (reverse proxy)"
echo "  - Tomcat: http://localhost:8080 (application server)"
echo "  - Default login: admin:admin"
echo ""

# Keep the container running
wait
