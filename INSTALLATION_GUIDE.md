# Headwind MDM Docker Installation Guide

## Overview

This installation provides a complete, automated Headwind MDM 5.37.3 (open-source) deployment in Docker with:
- ✅ Automatic installation from pre-downloaded ZIP file
- ✅ Automated configuration with English language
- ✅ English seed data initialization
- ✅ Complete MQTT broker support (port 31000/TCP)
- ✅ Nginx reverse proxy with SSL/TLS
- ✅ PostgreSQL database backend

---

## Installation Process

### 1. Prerequisites

Ensure you have:
- Docker and Docker Compose installed
- Pre-downloaded HMDM installer: `hmdm-5.37-install-ubuntu.zip` in `/hmdm-pre-downloaded/` directory
- Sufficient disk space (~2GB minimum)

### 2. Automated Deployment

The deployment is fully automated via the `docker-entrypoint.sh` script which:

1. **Extracts the pre-downloaded installer**
   - Unzips `hmdm-5.37-install-ubuntu.zip` 
   - Verifies all required files are present

2. **Deploys the WAR file**
   - Extracts `hmdm-5.37.3-os.war` to Tomcat ROOT directory
   - Unzips all application files in place

3. **Loads English seed data**
   - Executes `hmdm_init.en.sql` directly into PostgreSQL
   - Substitutes required variables:
     - `_HMDM_BASE_` → `/var/lib/tomcat9/work/hmdm`
     - `_HMDM_VERSION_` → `6.29`
     - `_HMDM_APK_` → `hmdm-6.29-os.apk`
     - `_ADMIN_EMAIL_` → `admin@example.com`

4. **Creates Tomcat context configuration**
   - Generates `ROOT.xml` with all HMDM parameters
   - Configures JDBC database connection
   - Sets up MQTT broker URI
   - Configures email/SMTP settings

5. **Initializes log4j configuration**
   - Creates `log4j-hmdm.xml` from template
   - Points to work directory for logging

### 3. Configuration Variables

All configuration is pre-set in the `docker-entrypoint.sh` script:

```bash
# Database Configuration
export SQL_HOST="postgres"          # Docker network hostname
export SQL_PORT="5432"              # PostgreSQL port
export SQL_BASE="hmdm"              # Database name
export SQL_USER="hmdm"              # Database user
export SQL_PASS="topsecret"         # Database password

# Installation Location
export LANGUAGE="en"                # English UI and seed data
export LOCATION="/var/lib/tomcat9/work/hmdm"  # HMDM work directory
export SCRIPT_LOCATION="/var/lib/tomcat9/work/hmdm"  # Scripts location

# Web Server Configuration
export PROTOCOL="https"             # HTTPS only
export BASE_DOMAIN="hmdm.example.com"  # Server domain
export PORT=""                      # Default ports (80/443)
export BASE_PATH="ROOT"             # Tomcat application path

# Admin Account
export ADMIN_EMAIL="admin@example.com"  # Admin email address

# SMTP (Email) Configuration
export SMTP_HOST="smtp.example.com"
export SMTP_PORT="587"
export SMTP_SSL="0"
export SMTP_STARTTLS="0"
export SMTP_USERNAME=""
export SMTP_PASSWORD=""
export SMTP_FROM="admin@example.com"
```

### 4. What Gets Deployed

**Container Structure:**
```
headwind-nginx (Ubuntu 22.04)
├── Nginx (reverse proxy, ports 80/443)
├── Tomcat 9.0.75 (application server, port 8080)
├── Mosquitto (MQTT broker, port 31000)
└── HMDM 5.37.3
    ├── WAR file deployed to /var/lib/tomcat9/webapps/ROOT/
    ├── Work directory: /var/lib/tomcat9/work/hmdm/
    └── Configuration: /var/lib/tomcat9/conf/Catalina/localhost/ROOT.xml

headwind-postgres (PostgreSQL 15-alpine)
├── Database: hmdm
├── User: hmdm
└── Seed data: English (en_US)
```

### 5. Tomcat Context Configuration

The `ROOT.xml` configuration file includes:

```xml
<!-- Database Connection -->
<Parameter name="JDBC.driver"   value="org.postgresql.Driver"/>
<Parameter name="JDBC.url"      value="jdbc:postgresql://postgres:5432/hmdm"/>
<Parameter name="JDBC.username" value="hmdm"/>
<Parameter name="JDBC.password" value="topsecret"/>

<!-- File Storage -->
<Parameter name="base.directory" value="/var/lib/tomcat9/work/hmdm"/>
<Parameter name="files.directory" value="/var/lib/tomcat9/work/hmdm/files"/>
<Parameter name="plugins.files.directory" value="/var/lib/tomcat9/work/hmdm/plugins"/>

<!-- Web Access -->
<Parameter name="base.url" value="https://hmdm.example.com/ROOT"/>
<Parameter name="swagger.host" value="hmdm.example.com"/>

<!-- MQTT Broker -->
<Parameter name="mqtt.server.uri" value="localhost:31000"/>
<Parameter name="mqtt.auth" value="1"/>

<!-- Security -->
<Parameter name="usage.scenario" value="private" />
<Parameter name="secure.enrollment" value="0"/>
<Parameter name="hash.secret" value="changeme-C3z9vi54"/>
```

---

## Starting the Deployment

### First Time Installation

```bash
docker-compose down -v        # Clean slate (if needed)
docker-compose build          # Build the image
docker-compose up -d          # Start in background
sleep 60                      # Wait for full initialization
docker-compose logs nginx -f  # Monitor logs
```

### Subsequent Startups

```bash
docker-compose up -d          # Starts immediately if already deployed
docker-compose logs nginx     # View initialization logs
```

### Stopping

```bash
docker-compose down           # Stop and preserve volumes
docker-compose down -v        # Stop and remove volumes (deletes data!)
```

---

## Access the System

### Web Interface
- **URL**: https://hmdm.example.com/ (or https://localhost/)
- **Default Login**: `admin` / `admin` (from seed data)
- **Admin Email**: `admin@example.com`

### Direct Tomcat Access
- **URL**: http://localhost:8080/ROOT/

### MQTT Broker
- **Address**: localhost:31000
- **Port**: 31000/TCP
- **Authentication**: Enabled (use HMDM credentials)

### Database
```bash
docker-compose exec postgres psql -U hmdm -d hmdm
```

### View Logs
```bash
docker-compose logs nginx -f     # Tomcat & entrypoint logs
docker-compose logs postgres -f  # Database logs
```

---

## Key Features

### ✅ Automated Everything
- No interactive prompts
- No manual SQL execution
- No manual configuration needed
- Pre-configured database, language, SMTP

### ✅ English Language
- UI in English (en_US)
- Seed data with English content
- English email templates

### ✅ Production Ready
- SSL/TLS certificates (self-signed by default)
- Nginx reverse proxy with proper headers
- PostgreSQL database backend
- MQTT broker for device communication

### ✅ Easy Management
- Single `docker-compose up` command
- All configuration in environment variables
- Automatic volume persistence
- Health checks on database

---

## Customization

### Change Deployment Variables

Edit `docker-entrypoint.sh` and modify the export statements:

```bash
# Example: Change HMDM domain
export BASE_DOMAIN="your-domain.com"

# Example: Change admin email
export ADMIN_EMAIL="your-admin@example.com"

# Example: Add SMTP configuration
export SMTP_HOST="smtp.gmail.com"
export SMTP_PORT="587"
export SMTP_USERNAME="your-email@gmail.com"
export SMTP_PASSWORD="your-app-password"
```

Then rebuild:
```bash
docker-compose down -v
docker-compose build --no-cache
docker-compose up -d
```

### Use Production SSL Certificates

Replace the self-signed certificates:
```bash
# Replace these files:
# - /etc/ssl/certs/hmdm.crt
# - /etc/ssl/private/hmdm.key
```

Update `headwind.conf` Nginx configuration:
```nginx
ssl_certificate /etc/ssl/certs/your-cert.crt;
ssl_certificate_key /etc/ssl/private/your-key.key;
```

---

## Troubleshooting

### Installation Hangs

The official installer takes time for database initialization (5-10 minutes on first run):
```bash
docker-compose logs nginx  # Check progress
```

Look for:
```
✓ Loading English seed data...
✓ English seed data loaded successfully
✓ HMDM installation completed successfully
```

### Database Connection Failed

Verify PostgreSQL is healthy:
```bash
docker-compose ps          # Check container status
docker-compose logs postgres  # Check database logs
```

Ensure credentials match in `docker-entrypoint.sh`:
- `SQL_HOST=postgres` (Docker network name)
- `SQL_USER=hmdm`
- `SQL_PASS=topsecret`
- `SQL_BASE=hmdm`

### HMDM Returns 404

Verify ROOT is deployed:
```bash
docker-compose exec nginx ls -la /var/lib/tomcat9/webapps/ROOT/WEB-INF
```

Check Tomcat logs:
```bash
docker-compose logs nginx | grep -E "ERROR|ROOT|Deployment"
```

### MQTT Not Connecting

Verify port is open:
```bash
nc -zv localhost 31000
```

Check MQTT configuration in ROOT.xml:
- `mqtt.server.uri` should be `localhost:31000`
- `mqtt.auth` should be `1` (enabled)

---

## Performance Considerations

- **First Run**: Takes 2-5 minutes for full initialization (Liquibase + seed data)
- **Subsequent Runs**: Starts in 30-60 seconds
- **Database Size**: ~50MB after initialization
- **Memory**: Tomcat typically uses 500MB-1GB
- **Disk**: Reserve 2GB minimum for volumes and logs

---

## Support & Customization

### To Add Custom Configuration

Modify `docker-entrypoint.sh` before the WAR deployment section:

```bash
# After creating the Tomcat context configuration,
# you can add additional parameters to ROOT.xml

cat >> "$TOMCAT_CONF/ROOT.xml" << 'EOF'
    <!-- Your custom parameters -->
EOF
```

### To Change Installation Directory

Update the `LOCATION` variable:
```bash
export LOCATION="/var/lib/tomcat9/work/hmdm"
```

All related paths will adjust automatically.

---

## Maintenance

### Backup Database

```bash
docker-compose exec postgres pg_dump -U hmdm hmdm > backup.sql
```

### Restore Database

```bash
docker-compose exec postgres psql -U hmdm hmdm < backup.sql
```

### Update HMDM

1. Update the pre-downloaded WAR file
2. Remove the old installation: `docker-compose down -v`
3. Rebuild and start: `docker-compose up -d`

---

**Installation Date**: January 4, 2026  
**HMDM Version**: 5.37.3  
**Status**: ✅ Fully Automated
