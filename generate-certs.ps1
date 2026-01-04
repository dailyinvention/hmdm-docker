# SSL Certificate Signing Request (CSR) Generation Script for Windows
# Usage: .\generate-certs.ps1

$ErrorActionPreference = "Stop"

# Check if OpenSSL is available
try {
    openssl version | Out-Null
} catch {
    Write-Host "Error: OpenSSL is not installed or not in PATH" -ForegroundColor Red
    Write-Host "Please install OpenSSL or Git Bash (which includes OpenSSL)" -ForegroundColor Yellow
    exit 1
}

# Check if directories exist, create if needed
if (-not (Test-Path "certs")) {
    New-Item -ItemType Directory -Path "certs" | Out-Null
}

if (-not (Test-Path "private")) {
    New-Item -ItemType Directory -Path "private" | Out-Null
}

# Get domain from .env or use default
$DOMAIN = "hmdm.example.com"
if (Test-Path ".env") {
    $envContent = Get-Content ".env" -Raw
    $match = [regex]::Match($envContent, 'HMDM_SERVER_URL\s*=\s*(.+)')
    if ($match.Success) {
        $DOMAIN = $match.Groups[1].Value.Trim()
    }
}

# Get certificate type from environment variable (default to ECC)
$CERT_TYPE = $env:CERT_TYPE
if ([string]::IsNullOrEmpty($CERT_TYPE)) {
    $CERT_TYPE = "ecc"
}
$CERT_TYPE = $CERT_TYPE.ToLower()

Write-Host "SSL Certificate Signing Request (CSR) Generation" -ForegroundColor Yellow -BackgroundColor Black
Write-Host "Domain: $DOMAIN" -ForegroundColor Cyan
Write-Host "Certificate Type: $CERT_TYPE" -ForegroundColor Cyan
Write-Host ""

# Generate private key based on certificate type
Write-Host "Generating private key..." -ForegroundColor Green

if ($CERT_TYPE -eq "rsa") {
    openssl genrsa -out private/hmdm.key 2048
    $KEY_INFO = "RSA 2048-bit"
} else {
    openssl ecparam -name prime256v1 -genkey -noout -out private/hmdm.key
    $KEY_INFO = "ECC (prime256v1)"
}

# Check if key generation was successful
if (-not (Test-Path "private/hmdm.key")) {
    Write-Host "Error: Failed to generate private key" -ForegroundColor Red
    exit 1
}

# Generate CSR (Certificate Signing Request)
Write-Host "Generating Certificate Signing Request (CSR)..." -ForegroundColor Green
openssl req -new -key private/hmdm.key -out certs/hmdm.csr -subj "/C=US/ST=State/L=City/O=Organization/CN=$DOMAIN"

# Check if CSR generation was successful
if (-not (Test-Path "certs/hmdm.csr")) {
    Write-Host "Error: Failed to generate CSR" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "CSR generation complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Files created:" -ForegroundColor Yellow
Write-Host "  Private Key:  private/hmdm.key ($KEY_INFO)"
Write-Host "  CSR File:     certs/hmdm.csr"
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Submit certs/hmdm.csr to your Certificate Authority"
Write-Host "2. Once you receive the signed certificate, save it as certs/hmdm.crt"
Write-Host "3. Run: docker-compose up -d"
Write-Host ""
