#!/bin/bash
set -e

echo "Starting Headwind MDM Docker container..."

# Wait for PostgreSQL to be available
echo "Waiting for PostgreSQL to be available..."
until pg_isready -h "${DB_HOST:-postgres}" -U "${DB_USER}" -d "${DB_NAME}" > /dev/null 2>&1; do
  echo "PostgreSQL is unavailable - sleeping"
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
    # Use postgres superuser to create database and user
    PGPASSWORD="${POSTGRES_PASSWORD:-postgres}" psql -h "${DB_HOST:-postgres}" -U postgres -d postgres -c "CREATE USER ${DB_USER} WITH PASSWORD '${DB_PASSWORD}';" 2>/dev/null || echo "User ${DB_USER} already exists"
    PGPASSWORD="${POSTGRES_PASSWORD:-postgres}" psql -h "${DB_HOST:-postgres}" -U postgres -d postgres -c "CREATE DATABASE ${DB_NAME} WITH OWNER=${DB_USER};" 2>/dev/null || echo "Database ${DB_NAME} already exists"
    PGPASSWORD="${POSTGRES_PASSWORD:-postgres}" psql -h "${DB_HOST:-postgres}" -U postgres -d postgres -c "GRANT ALL PRIVILEGES ON DATABASE ${DB_NAME} TO ${DB_USER};" 2>/dev/null || true
    echo "Database setup complete"
fi

# Check if HMDM needs to be installed (check if Tomcat ROOT.war exists)
if [ ! -f "/var/lib/tomcat9/webapps/ROOT.war" ]; then
    echo "Headwind MDM not installed. Running installation..."
    
    if [ -f "/hmdm-install.sh" ]; then
        echo "Running HMDM installer..."
        /hmdm-install.sh
    else
        echo "WARNING: hmdm-install.sh not found. HMDM will not be installed."
        echo "Please manually download and install Headwind MDM from https://h-mdm.com/download"
    fi
else
    echo "Headwind MDM already installed, skipping installation"
fi

# Substitute environment variables in the nginx config file
echo "Configuring Nginx..."
envsubst '\
    ${HMDM_SERVER_URL},\
    ${SSL_CERTIFICATE_PATH},\
    ${SSL_CERTIFICATE_KEY_PATH}' \
  < /etc/nginx/sites-available/headwind.conf.template \
  > /etc/nginx/sites-available/headwind.conf

# Create symlink to enable the site
ln -sf /etc/nginx/sites-available/headwind.conf /etc/nginx/sites-enabled/headwind.conf

# Test nginx configuration
nginx -t

echo "Starting Nginx..."
nginx -g "daemon off;" &

echo "Starting Tomcat 9..."
service tomcat9 start

echo "Headwind MDM is starting..."
echo "  - Nginx: https://${HMDM_SERVER_URL} (reverse proxy)"
echo "  - Tomcat: http://localhost:8080 (application server)"
echo "  - Default login: admin:admin"
echo ""

# Keep the container running
wait
