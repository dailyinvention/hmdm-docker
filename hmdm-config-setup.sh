#!/bin/bash

# This script sets up HMDM configuration before running the installer
# It configures the database connection and other settings

set -e

echo "=== Setting up HMDM Configuration ==="

# Get database credentials from environment
DB_HOST="${DB_HOST:-postgres}"
DB_PORT="${DB_PORT:-5432}"
DB_USER="${DB_USER:-hmdm}"
DB_PASSWORD="${DB_PASSWORD:-topsecret}"
DB_NAME="${DB_NAME:-hmdm}"

# Create HMDM config directory
HMDM_CONF_DIR="/var/lib/tomcat9/conf/Catalina/localhost"
mkdir -p "$HMDM_CONF_DIR"

# Create or update hmdm database configuration
# This tells Tomcat/HMDM how to connect to PostgreSQL
cat > "$HMDM_CONF_DIR/hmdm-db.xml" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<Context>
    <Resource name="jdbc/hmdm"
              auth="Container"
              type="javax.sql.DataSource"
              driverClassName="org.postgresql.Driver"
              url="jdbc:postgresql://${DB_HOST}:${DB_PORT}/${DB_NAME}"
              username="${DB_USER}"
              password="${DB_PASSWORD}"
              maxActive="20"
              maxIdle="10"
              maxWait="30000"
              testOnBorrow="true"
              validationQuery="SELECT 1" />
</Context>
EOF

echo "✓ HMDM database configuration created"

# Optional: Create HMDM application properties file if needed
HMDM_APP_PROPS="/var/lib/tomcat9/webapps/ROOT/WEB-INF/classes/application.properties"

# This will be created by the installer, but we can pre-configure if needed
if [ -d "/var/lib/tomcat9/webapps/ROOT/WEB-INF/classes" ]; then
    cat > "$HMDM_APP_PROPS" << EOF
# Headwind MDM Application Properties
spring.datasource.url=jdbc:postgresql://${DB_HOST}:${DB_PORT}/${DB_NAME}
spring.datasource.username=${DB_USER}
spring.datasource.password=${DB_PASSWORD}
spring.datasource.driver-class-name=org.postgresql.Driver
spring.jpa.hibernate.ddl-auto=update
spring.jpa.database-platform=org.hibernate.dialect.PostgreSQL10Dialect
EOF
    echo "✓ HMDM application properties configured"
fi

echo "=== Configuration complete ==="
