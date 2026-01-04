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
    PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST:-postgres}" -U "${DB_USER}" -d postgres -c "CREATE DATABASE ${DB_NAME};" 2>/dev/null || echo "Database ${DB_NAME} already exists"
    echo "Database setup complete"
fi

# Define Tomcat webapps directory (using /var/lib/tomcat9 - standard Ubuntu location)
TOMCAT_WEBAPPS="/var/lib/tomcat9/webapps"

# Check if HMDM is already deployed
if [ ! -d "$TOMCAT_WEBAPPS/ROOT/WEB-INF" ] && [ ! -f "$TOMCAT_WEBAPPS/ROOT.war" ]; then
    echo "Headwind MDM not installed. Running official installer..."
    
    # Create temp directory for installer
    TEMP_INSTALL_DIR="/tmp/hmdm-install-temp"
    rm -rf "$TEMP_INSTALL_DIR"
    mkdir -p "$TEMP_INSTALL_DIR"
    
    # Extract the pre-downloaded installer
    if [ -d "/hmdm-pre-downloaded" ] && [ -f "/hmdm-pre-downloaded/hmdm-5.37-install-ubuntu.zip" ]; then
        echo "✓ Extracting HMDM installer..."
        cd "$TEMP_INSTALL_DIR" && unzip -o -q "/hmdm-pre-downloaded/hmdm-5.37-install-ubuntu.zip" && cd /
    else
        echo "ERROR: Pre-downloaded installer not found"
        exit 1
    fi
    
    INSTALL_DIR="$TEMP_INSTALL_DIR/hmdm-install"
    
    # Verify installer structure
    if [ ! -f "$INSTALL_DIR/hmdm_install.sh" ] || [ ! -f "$INSTALL_DIR/hmdm-5.37.3-os.war" ]; then
        echo "ERROR: Installer structure is incomplete"
        exit 1
    fi
    
    echo "✓ Creating automated installer wrapper..."
    
    # Create a script that pipes all installer answers to stdin
    cat > "$TEMP_INSTALL_DIR/run_installer.sh" << 'INSTALLER_RUNNER'
#!/bin/bash
set -e

INSTALL_DIR="$1"
cd "$INSTALL_DIR"

# Prepare all configuration values
LANGUAGE="${LANGUAGE:-en}"
SQL_HOST="${DB_HOST:-postgres}"
SQL_PORT="${DB_PORT:-5432}"
SQL_BASE="${DB_NAME:-hmdm}"
SQL_USER="${DB_USER:-hmdm}"
SQL_PASS="${DB_PASSWORD:-topsecret}"
LOCATION="/var/lib/tomcat9/work/hmdm"
SCRIPT_LOCATION="/var/lib/tomcat9/work/hmdm"
PROTOCOL="${PROTOCOL:-https}"
BASE_DOMAIN="${HMDM_SERVER_URL:-hmdm.example.com}"
PORT="${HMDM_PORT:-}"
BASE_PATH="${HMDM_BASE_PATH:-ROOT}"
ADMIN_EMAIL="${ADMIN_EMAIL:-admin@example.com}"
SMTP_HOST="${SMTP_HOST:-}"
SMTP_PORT="${SMTP_PORT:-587}"
SMTP_SSL="${SMTP_SSL:-0}"
SMTP_STARTTLS="${SMTP_STARTTLS:-0}"
SMTP_USERNAME="${SMTP_USERNAME:-}"
SMTP_PASSWORD="${SMTP_PASSWORD:-}"
SMTP_FROM="${SMTP_FROM:-noreply@${HMDM_SERVER_URL:-hmdm.example.com}}"

# CRITICAL FIX: Pre-set LANGUAGE variable in the installer script
# The read command uses read -i "$LANGUAGE" which respects an already-set LANGUAGE variable
# We sed the script to inject our LANGUAGE value right at the start
sed -i "1a export LANGUAGE='$LANGUAGE'" hmdm_install.sh

# Pipe all answers to the installer script stdin
# The order must match the read statements in hmdm_install.sh
(
  echo ""  # LANGUAGE - allow read -i default to use exported LANGUAGE 
  echo "$SQL_HOST"
  echo "$SQL_PORT"
  echo "$SQL_BASE"
  echo "$SQL_USER"
  echo "$SQL_PASS"
  echo "$LOCATION"
  echo "$SCRIPT_LOCATION"
  echo "$PROTOCOL"
  echo "$BASE_DOMAIN"
  echo "$PORT"
  echo "$BASE_PATH"
  # Setup SMTP? (Y/n) - default to n
  echo "n"
  # Is this information correct? (Y/n) - answer Y
  echo "Y"
  # Setup HTTPS via LetsEncrypt? (Y/n) - answer n
  echo "n"
  # Use iptables to redirect? (Y/n) - answer n
  echo "n"
  # Move required APKs? (Y/n) - answer n
  echo "n"
) | bash hmdm_install.sh 2>&1 | tee /tmp/hmdm-install.log

INSTALLER_RUNNER
    
    chmod +x "$TEMP_INSTALL_DIR/run_installer.sh"
    
    # Run the automated installer
    echo "✓ Running HMDM installer with automated configuration (Language: ${LANGUAGE:-en})..."
    bash "$TEMP_INSTALL_DIR/run_installer.sh" "$INSTALL_DIR" 2>&1 | tail -100
    
    INSTALL_RESULT=$?
    if [ $INSTALL_RESULT -eq 0 ]; then
        echo "✓ HMDM installer completed successfully"
    else
        echo "⚠ HMDM installer exited with code $INSTALL_RESULT"
        tail -50 /tmp/hmdm-install.log
    fi
    
    # Verify deployment
    if [ -d "$TOMCAT_WEBAPPS/ROOT/WEB-INF" ]; then
        echo "✓ HMDM deployment verified"
    else
        echo "ERROR: HMDM installation failed - ROOT application not deployed"
        exit 1
    fi
    
    cd /
    
    # Clean up temp install directory
    rm -rf "$TEMP_INSTALL_DIR"
    
else
    echo "Headwind MDM already installed, skipping installation"
fi

# Substitute environment variables in the nginx config file
echo "Configuring Nginx..."

# Use cert directory that can be in a volume
CERT_DIR="/var/lib/hmdm/certs"
KEY_DIR="/var/lib/hmdm/private"
mkdir -p "$CERT_DIR" "$KEY_DIR"

# Check if SSL certificates exist, if not create self-signed for testing
if [ ! -f "$CERT_DIR/hmdm.crt" ] || [ ! -f "$KEY_DIR/hmdm.key" ]; then
    echo "✓ Generating self-signed SSL certificate..."
    
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "$KEY_DIR/hmdm.key" \
        -out "$CERT_DIR/hmdm.crt" \
        -subj "/CN=${HMDM_SERVER_URL:-localhost}"
    
    chmod 644 "$CERT_DIR/hmdm.crt"
    chmod 600 "$KEY_DIR/hmdm.key"
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

ln -sf /etc/nginx/sites-available/headwind.conf /etc/nginx/sites-enabled/headwind.conf

# Test and start nginx
if nginx -t 2>/dev/null; then
    echo "✓ Nginx configuration valid"
    echo "✓ Starting Nginx..."
    nginx -g "daemon off;" &
else
    echo "✗ Nginx config test failed"
    exit 1
fi

echo "✓ Starting Tomcat 9..."
# Change to Tomcat directory
cd /var/lib/tomcat9

echo "Headwind MDM is starting..."
echo "  - Nginx: https://${HMDM_SERVER_URL:-hmdm.example.com} (reverse proxy)"
echo "  - Tomcat: http://localhost:8080 (application server)"
echo "  - Default login: admin:admin"
echo "  - Database: ${DB_HOST:-postgres}/${DB_NAME:-hmdm}"
echo ""

# Start background task to apply English SQL after Liquibase finishes migrations
(
    # Wait for Liquibase to complete by checking for a specific table that's created during migrations
    echo "⏳ Waiting for Liquibase database initialization to complete..."
    WAIT_COUNT=0
    MAX_WAIT=180  # 3 minutes max
    until PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST:-postgres}" -U "${DB_USER}" -d "${DB_NAME}" -c "SELECT 1 FROM databasechangelog LIMIT 1" > /dev/null 2>&1; do
        WAIT_COUNT=$((WAIT_COUNT + 1))
        if [ $WAIT_COUNT -ge $MAX_WAIT ]; then
            echo "⚠ Liquibase initialization timeout"
            break
        fi
        sleep 1
    done
    
    # Additional delay to ensure all migrations are complete and tables exist
    echo "⏳ Waiting for database tables to be created..."
    sleep 15
    
    # Verify required tables exist
    TABLES_READY=0
    for i in {1..30}; do
        PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST:-postgres}" -U "${DB_USER}" -d "${DB_NAME}" -c "SELECT 1 FROM configurations LIMIT 1" > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            TABLES_READY=1
            echo "✓ All required tables are ready"
            break
        fi
        sleep 1
    done
    
    # Apply complete English language SQL from the installer archive
    echo "✓ Applying complete English language configuration..."
    ENGLISH_SQL_FILE="/tmp/hmdm_init_english.sql"
    
    # Extract English SQL from the pre-downloaded installer ZIP
    unzip -j -o /hmdm-pre-downloaded/hmdm-5.37-install-ubuntu.zip 'hmdm-install/install/sql/hmdm_init.en.sql' -d /tmp/ > /dev/null 2>&1
    if [ -f "/tmp/hmdm_init.en.sql" ]; then
        mv /tmp/hmdm_init.en.sql "$ENGLISH_SQL_FILE"
    fi
    
    if [ -f "$ENGLISH_SQL_FILE" ]; then
        echo "  Applying $(wc -l < "$ENGLISH_SQL_FILE") SQL statements..."
        SQL_OUTPUT=$(mktemp)
        PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST:-postgres}" -U "${DB_USER}" -d "${DB_NAME}" -f "$ENGLISH_SQL_FILE" > "$SQL_OUTPUT" 2>&1
        SQL_RESULT=$?
        
        if [ $SQL_RESULT -eq 0 ]; then
            # Verify configuration was updated
            CONFIG_NAME=$(PGPASSWORD="${DB_PASSWORD}" psql -h "${DB_HOST:-postgres}" -U "${DB_USER}" -d "${DB_NAME}" -tc "SELECT name FROM configurations LIMIT 1;" 2>/dev/null | xargs)
            if [ "$CONFIG_NAME" = "Managed Launcher" ]; then
                echo "✅ English configuration applied successfully!"
                echo "   Configuration name: '$CONFIG_NAME'"
            else
                echo "⚠ SQL applied but configuration shows: '$CONFIG_NAME'"
            fi
        else
            echo "⚠ Failed to apply English SQL"
        fi
        rm -f "$SQL_OUTPUT" "$ENGLISH_SQL_FILE"
    else
        echo "⚠ English SQL file could not be extracted from installer archive"
    fi
) &

# Start Tomcat in foreground so Docker container stays running
if [ -x /usr/share/tomcat9/bin/catalina.sh ]; then
    /usr/share/tomcat9/bin/catalina.sh run
else
    echo "✗ Tomcat startup failed - catalina.sh not found"
    exit 1
fi &

# Keep the container running
wait
