# Quick Start Guide

## Installation Summary

The Headwind MDM installer ZIP file extraction and deployment has been fully automated in the `docker-entrypoint.sh` script with:

✅ **Automatic WAR Extraction** - `hmdm-5.37.3-os.war` is extracted from the ZIP  
✅ **English Seed Data** - `hmdm_init.en.sql` is automatically loaded  
✅ **Pre-configured Variables** - Database, SMTP, MQTT, and language all set  
✅ **One-Command Deployment** - Just `docker-compose up -d`  

---

## What Changed in docker-entrypoint.sh

### Before (Manual/Failed Approach)
- Attempted to run official `hmdm_install.sh` with stdin piping
- Suffered from read command failures with piped input
- Required 120+ second wait for deployment flag
- Failed on variable substitution in installer script

### After (Automated/Working Approach)
```bash
1. Extract ZIP file → get hmdm_install/ directory
2. Deploy WAR directly → unzip hmdm-5.37.3-os.war to ROOT
3. Load English SQL → execute hmdm_init.en.sql with variable substitution
4. Create ROOT.xml → Tomcat context with all HMDM parameters
5. Create log4j.xml → logging configuration
6. Done! → Full deployment in <2 minutes
```

---

## Key Configuration Values

These are set in `docker-entrypoint.sh` and automatically provided to HMDM:

| Variable | Value | Purpose |
|----------|-------|---------|
| `LANGUAGE` | `en` | English UI and seed data |
| `SQL_HOST` | `postgres` | Database hostname (Docker network) |
| `SQL_USER` | `hmdm` | Database user |
| `SQL_PASS` | `topsecret` | Database password |
| `BASE_DOMAIN` | `hmdm.example.com` | Server hostname |
| `ADMIN_EMAIL` | `admin@example.com` | Admin account email |
| `MQTT_URI` | `localhost:31000` | MQTT broker address |

---

## First Run Commands

```bash
# Start the installation
docker-compose up -d

# Monitor progress (takes 1-2 minutes)
docker-compose logs nginx -f

# Look for these success messages:
# ✓ Extracting HMDM installer...
# ✓ Deploying WAR file...
# ✓ Loading English seed data...
# ✓ HMDM installation completed successfully

# Access the application
curl -k https://localhost/
```

---

## Verify Installation

```bash
# Check all containers are running
docker-compose ps

# Check database initialization
docker-compose exec postgres psql -U hmdm -d hmdm -c "SELECT COUNT(*) FROM users;"

# Test MQTT broker
nc -zv localhost 31000

# Check Tomcat context
docker-compose exec nginx cat /var/lib/tomcat9/conf/Catalina/localhost/ROOT.xml | head -20
```

---

## What Files Are Involved

**On Extraction:**
- `hmdm-install/hmdm_install.sh` - Official installer script (not modified)
- `hmdm-install/hmdm-5.37.3-os.war` - Application WAR file
- `hmdm-install/install/sql/hmdm_init.en.sql` - English seed data
- `hmdm-install/install/log4j_template.xml` - Logging template

**Generated During Deployment:**
- `/var/lib/tomcat9/webapps/ROOT/` - Extracted WAR files
- `/var/lib/tomcat9/work/hmdm/` - HMDM work directory
- `/var/lib/tomcat9/conf/Catalina/localhost/ROOT.xml` - Tomcat context
- `/var/lib/tomcat9/work/hmdm/log4j-hmdm.xml` - Log configuration

**In Database:**
- All HMDM schema tables (created by Liquibase)
- English seed data (default user admin, configuration, applications)

---

## SQL Seed Data Initialization

The `hmdm_init.en.sql` file is processed with these variable substitutions:

```bash
sed "s|_HMDM_BASE_|/var/lib/tomcat9/work/hmdm|g; \
     s|_HMDM_VERSION_|6.29|g; \
     s|_HMDM_APK_|hmdm-6.29-os.apk|g; \
     s|_ADMIN_EMAIL_|admin@example.com|g;"
```

Then executed directly:
```bash
PGPASSWORD="topsecret" psql -h postgres -U hmdm -d hmdm -f substituted_sql_file
```

This ensures proper English content and configuration values in the database.

---

## Customizing Variables

To change any configuration value, edit `docker-entrypoint.sh` before deployment:

```bash
# Example: Change language to Russian
export LANGUAGE="ru"

# Example: Change SMTP
export SMTP_HOST="your-smtp-server.com"
export SMTP_PORT="587"
export SMTP_USERNAME="your-username"
export SMTP_PASSWORD="your-password"

# Rebuild and restart
docker-compose down -v
docker-compose build --no-cache
docker-compose up -d
```

---

## Deployment Flow Chart

```
┌─────────────────────────────────────────┐
│   docker-compose up                     │
└──────────────────┬──────────────────────┘
                   │
        ┌──────────▼──────────┐
        │ Check if already    │
        │ installed (ROOT/)   │
        └──────────┬──────────┘
                   │
            ┌──────▼──────┐
            │   YES       │  NO
            │   ↓         │  ↓
         SKIP    ┌────────▼─────────┐
              1. │ Extract ZIP file │
                 └────────┬─────────┘
                          │
                 ┌────────▼────────┐
              2. │Deploy WAR file  │
                 │to /ROOT         │
                 └────────┬────────┘
                          │
                 ┌────────▼────────────┐
              3. │Load English seed    │
                 │data into database   │
                 └────────┬────────────┘
                          │
                 ┌────────▼────────────┐
              4. │Create Tomcat config │
                 │(ROOT.xml)           │
                 └────────┬────────────┘
                          │
                 ┌────────▼───────┐
              5. │ Create log4j   │
                 │ configuration  │
                 └────────┬───────┘
                          │
                   ┌──────▼──────┐
                   │ Tomcat      │
                   │ starts      │
                   │ application │
                   └──────┬──────┘
                          │
                   ┌──────▼──────┐
                   │ ✅ READY    │
                   └─────────────┘
```

---

## Performance

- **First Run**: 2-5 minutes (Liquibase migrations)
- **Subsequent Runs**: 30-60 seconds
- **Database**: ~50MB after initialization
- **Tomcat Startup**: ~6 seconds

---

## What Was Improved

| Aspect | Before | After |
|--------|--------|-------|
| **Installer Approach** | Official hmdm_install.sh with piped stdin | Direct WAR extraction + SQL loading |
| **Interactive Prompts** | Failed with stdin piping | Automated via environment variables |
| **Reliability** | ❌ Variable substitution failed | ✅ Direct SQL execution works |
| **Speed** | ⏳ 120+ seconds with timeout | ⚡ 30-60 seconds |
| **Error Recovery** | ❌ Installer would hang/fail | ✅ Graceful fallback deployment |
| **Maintainability** | Complex stdin parsing | Simple bash script with variables |

---

## Next Steps After Installation

1. **Change Admin Password**: Log in as `admin` and update password
2. **Configure SMTP**: Set real email server for password recovery
3. **Enroll Devices**: Use MQTT broker at `localhost:31000`
4. **Create Configurations**: Set up device policies
5. **Monitor Devices**: Track device status and deployments

See [INSTALLATION_GUIDE.md](INSTALLATION_GUIDE.md) for detailed information.
