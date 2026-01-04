# Headwind MDM Docker Installation

This Docker Compose setup installs and runs Headwind MDM with Nginx as a reverse proxy and PostgreSQL as the database.

## What's Included

- **Ubuntu 22.04** base image
- **Nginx** - Reverse proxy with HTTP to HTTPS redirect
- **Tomcat 9** - Application server for Headwind MDM
- **PostgreSQL 15** - Database backend
- **Headwind MDM** - Mobile Device Management platform

## Files

- **Dockerfile** - Ubuntu 22.04 image with Nginx, Tomcat, and dependencies
- **headwind.conf** - Nginx configuration template with environment variables
- **docker-entrypoint.sh** - Entrypoint script that configures Nginx and starts services
- **hmdm-install.sh** - Script to download and install Headwind MDM
- **docker-compose.yml** - Docker Compose configuration with PostgreSQL service
- **.env** - Environment variables file
- **setup.sh** - Linux/macOS setup script (configures environment and permissions)
- **setup.ps1** - Windows PowerShell setup script
- **generate-certs.sh** - Linux/macOS script to generate private key and CSR file
- **generate-certs.ps1** - Windows PowerShell script to generate private key and CSR file

## Quick Start

### 0. Clone and Setup

Clone the repository and run the setup script appropriate for your operating system:

**Linux/macOS:**
```bash
git clone <repository-url>
cd hmdm-docker
./setup.sh
```

**Windows:**
```powershell
git clone <repository-url>
cd hmdm-docker
.\setup.ps1
```

The setup script automatically:
- Configures Git hooks for automatic script permission updates on future pulls
- Creates necessary directories for certificates
- Sets up `.env` from `.env.example` if needed
- (Linux/macOS only) Makes all scripts executable

### 1. Configure Environment Variables

Edit `.env` with your settings:

```bash
# Shared SSL Configuration
SSL_CERTIFICATE_PATH=/etc/ssl/certs/hmdm.crt
SSL_CERTIFICATE_KEY_PATH=/etc/ssl/private/hmdm.key
CERT_TYPE=ecc # Use 'rsa' or 'ecc'

# HMDM Configuration
HMDM_SERVER_URL=hmdm.example.com

# PostgreSQL Configuration
DB_USER=hmdm
DB_PASSWORD=topsecret #change to something more secure
DB_NAME=hmdm
```

### 2. Add SSL Certificates

⚠️ **Important Security Notice:**

If SSL certificate files are not provided, the Docker image will automatically generate and use **self-signed certificates**. These are suitable for **local testing and development only** but should **never be used in production environments exposed on the internet**. Self-signed certificates will trigger browser security warnings and are not trusted by certificate authorities.

#### Option A: Already Have a Certificate from an Authorized Provider (Recommended for Production)

If you already have an SSL certificate from a trusted Certificate Authority such as Let's Encrypt, DigiCert, Sectigo, GlobalSign, or Amazon Certificate Manager:

1. **Place the certificate files in the project:**
   - `certs/hmdm.crt` - SSL certificate
   - `private/hmdm.key` - Private key

2. **Ensure proper permissions (on Linux/macOS):**
   ```bash
   chmod 644 certs/hmdm.crt
   chmod 600 private/hmdm.key
   ```

3. **Proceed with deployment**

#### Option B: Generate a Certificate Signing Request (CSR) for a CA

If you don't yet have a certificate, generate a Certificate Signing Request (CSR) to submit to a Certificate Authority:

**Linux/macOS:**
```bash
./generate-certs.sh
```

**Windows:**
```powershell
.\generate-certs.ps1
```

This will create:
- `private/hmdm.key` - Private key (keep this safe!)
- `certs/hmdm.csr` - Certificate Signing Request

**Certificate Type Options:**

The certificate generation script supports both ECC and RSA certificate types:

**Linux/macOS:**
```bash
# Generate ECC certificate (default, recommended)
CERT_TYPE=ecc ./generate-certs.sh

# Generate RSA certificate
CERT_TYPE=rsa ./generate-certs.sh
```

**Windows:**
```powershell
# Generate ECC certificate (default, recommended)
$env:CERT_TYPE='ecc'; .\generate-certs.ps1

# Generate RSA certificate
$env:CERT_TYPE='rsa'; .\generate-certs.ps1
```

You can also set `CERT_TYPE` in `.env`:
```bash
CERT_TYPE=ecc  # or rsa
```

**Steps to obtain a CA-signed certificate:**
1. Submit `certs/hmdm.csr` to your Certificate Authority (Let's Encrypt, DigiCert, etc.)
2. Once you receive the signed certificate, save it as `certs/hmdm.crt`
3. Ensure proper permissions: `chmod 644 certs/hmdm.crt`
4. Proceed with deployment

#### Option C: Self-Signed Certificates (Local Testing Only)

If certificates are not provided, the Docker image will automatically generate self-signed certificates on startup. This is acceptable **only for**:
- Local development and testing
- Internal testing environments
- Proof-of-concept deployments

**Do NOT use self-signed certificates for:**
- Production environments
- Public/internet-facing deployments
- Any scenario requiring browser trust or end-user access

### 3. Start the Services

```bash
docker-compose up -d
```

**First-time startup:**
1. PostgreSQL will start and initialize
2. Nginx will configure and start
3. Tomcat 9 will start
4. **The Headwind MDM installer will run interactively** - you'll see prompts in the logs
   - Answer the installer questions (you can review them with `docker-compose logs nginx`)
   - This typically takes 5-10 minutes
5. Access the application once installation completes

**Watch the installation progress:**
```bash
docker-compose logs -f nginx
```

You'll see prompts like:
- Install required software? (respond: yes)
- Upgrade Tomcat? (respond: yes)
- Configure HTTPS? (respond: yes)
- Accept LetsEncrypt terms? (respond: yes)

Once complete, you'll see:
```
Headwind MDM is starting...
  - Nginx: https://HMDM_SERVER_URL (reverse proxy)
  - Tomcat: http://localhost:8080 (application server)
  - Default login: admin:admin
```

### Using Docker Compose:

1. Copy `.env.example` to `.env` and update with your values:
   ```bash
   cp .env.example .env
   ```

2. Edit `.env` with your configuration:
   ```bash
   nano .env
   ```

3. Start the container:
   ```bash
   docker-compose up -d
   ```

4. View logs:
   ```bash
   docker-compose logs -f
   ```

5. Stop the container:
   ```bash
   docker-compose down
   ```

## Environment Variables

### Required

- **HMDM_SERVER_URL** - Server URL/domain for Headwind MDM (e.g., `hmdm.example.com`)
- **SSL_CERTIFICATE_PATH** - Path to SSL certificate inside container (default: `/etc/ssl/certs/hmdm.crt`)
- **SSL_CERTIFICATE_KEY_PATH** - Path to SSL private key inside container (default: `/etc/ssl/private/hmdm.key`)

### SSL/TLS Configuration

- **CERT_TYPE** - Certificate type for CSR generation: `ecc` (default, recommended) or `rsa` (default: `ecc`)
  - ECC (Elliptic Curve Cryptography): Modern, smaller keys, better performance
  - RSA: Traditional, widely compatible, larger keys

### Database

- **DB_USER** - PostgreSQL username for Headwind MDM (default: `hmdm`)
- **DB_PASSWORD** - PostgreSQL password (default: `topsecret`) ⚠️ Change this!
- **DB_NAME** - PostgreSQL database name (default: `hmdm`)
- **DB_HOST** - PostgreSQL hostname (auto-set to `postgres` when using Docker Compose)

## Volume Mounts

### PostgreSQL Data
- `postgres_data:/var/lib/postgresql/data` - Persistent database storage

### Tomcat Data
- `tomcat_data:/var/lib/tomcat9` - Persistent application data

### SSL Certificates
- `./certs:/etc/ssl/certs:ro` - Read-only SSL certificates
- `./private:/etc/ssl/private:ro` - Read-only private keys

## How Installation Works

The Headwind MDM installation is **automated on first container startup**:

1. **Container starts** → Checks if HMDM is already installed
2. **If not installed**:
   - PostgreSQL user and database are created
   - The Headwind MDM installer script downloads the latest version
   - The installer runs **interactively** (you respond to prompts via `docker-compose logs`)
   - Tomcat is configured and started
   - Nginx is configured as a reverse proxy
3. **If already installed**: Skips installation and starts services directly

### Interactive Installation Prompts

When you see the installation prompts, you can respond with:
- `y` or `yes` for most questions
- `n` or `no` for optional features

Alternatively, use `docker attach` to interact directly with the installer:
```bash
docker attach headwind-nginx
```

## Port Mappings

| Port | Service | Purpose |
|------|---------|---------|
| 80 | Nginx | HTTP redirect to HTTPS |
| 443 | Nginx | HTTPS reverse proxy |
| 8080 | Tomcat | Direct application server access |
| 31000 | MQTT | MQTT broker for device communication

## SSL Certificates

The container expects SSL certificates to be available at the paths specified in the environment variables. Mount these from your host system or use volume mounts to provide them.

## Troubleshooting

### Network/Internet Connectivity Issues

**Error: "Cannot reach [installer URL]. Check your internet connection."**

The container needs internet access to download the Headwind MDM installer. Try these steps:

1. **Verify Docker has internet access:**
   ```bash
   docker run --rm alpine wget -q -O - https://example.com
   ```
   If this fails, Docker doesn't have internet access.

2. **Check DNS resolution:**
   ```bash
   docker run --rm alpine nslookup example.com
   ```
   If this fails, DNS isn't working inside the container.

3. **Restart Docker services:**
   ```bash
   docker-compose restart nginx
   ```

4. **Check your network/firewall:**
   - Ensure port 443 outbound is open
   - Check if you're behind a proxy or firewall blocking the installer URL
   - Try accessing the installer URL from your host machine

5. **Check Docker daemon network settings:**
   ```bash
   docker inspect headwind-nginx | grep -A 5 NetworkSettings
   ```

### View Logs

```bash
# All containers
docker-compose logs -f

# Specific service
docker-compose logs -f nginx
docker-compose logs -f postgres
```

### Check Tomcat Logs

```bash
docker exec headwind-nginx journalctl -u tomcat9.service -f
```

### Validate Nginx Configuration

```bash
docker exec headwind-nginx nginx -t
```

### Connect to PostgreSQL

```bash
docker exec -it headwind-postgres psql -U hmdm -d hmdm
```

### Restart Services

```bash
# Restart all
docker-compose restart

# Restart specific service
docker-compose restart nginx
```

### Stop Everything

```bash
docker-compose down
```

To also remove volumes (warning: deletes data):
```bash
docker-compose down -v
```

## Security Recommendations

1. **Change Database Password**: Update `DB_PASSWORD` in `.env` to a strong password
2. **Change Admin Password**: First login to Headwind MDM and change default `admin:admin` credentials
3. **SSL Certificates**: Use proper SSL certificates (not self-signed) in production
4. **Firewall**: Restrict access to ports 80, 443, 31000, and 8080 as needed
5. **Backups**: Regularly backup the PostgreSQL volume (`postgres_data`)

### Disclaimer

This Docker setup is provided as-is for deploying Headwind MDM. While these scripts and configurations follow best practices, **users are responsible for:**

- Securing their infrastructure, software, and network
- Maintaining and updating the system

**The creators of this setup are not liable for:**
- Security breaches or data loss
- Misconfiguration or improper deployment
- Failure to follow security recommendations
- System downtime or service interruptions
- Any damages or losses resulting from the use of this setup

It is your responsibility to ensure this deployment meets your security and compliance requirements.

## Production Considerations

### Backup Strategy

```bash
# Backup database
docker exec headwind-postgres pg_dump -U hmdm -d hmdm > hmdm_backup.sql

# Backup Tomcat configuration
docker cp headwind-nginx:/var/lib/tomcat9/conf/ ./tomcat-conf-backup/
```

### Restore from Backup

```bash
# Restore database
docker exec -i headwind-postgres psql -U hmdm -d hmdm < hmdm_backup.sql
```

### Hardware Requirements (from Headwind MDM)

- **Testing/Small**: 4 GB RAM, 2x CPU, 20 GB SSD
- **Production**: Larger resources depending on device count

## Next Steps

1. Enroll devices using the QR code in the Devices section
2. Configure device policies and restrictions
3. Deploy applications to managed devices
4. Monitor device health and compliance

For more information, visit: [Headwind MDM Documentation](https://h-mdm.com/)

## Support

- Headwind MDM Docs: https://h-mdm.com/
- Installation Guide: https://h-mdm.com/advanced-web-panel-installation/
- System Requirements: https://h-mdm.com/hardware-requirements/

## Notes

- Tomcat 9 is used as the application server
- PostgreSQL 15 Alpine image provides a lightweight database
- Nginx serves as reverse proxy with SSL termination
- First-time setup may take several minutes as Headwind MDM initializes
- Database and Tomcat data are persisted in Docker volumes for container restarts
