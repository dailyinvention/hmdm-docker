# Setup script for Headwind MDM Docker installation
# Run this once after cloning: .\setup.ps1

$ErrorActionPreference = "Stop"

Write-Host "🔧 Setting up Headwind MDM installation..." -ForegroundColor Cyan
Write-Host ""

# Configure Git hooks
Write-Host "✓ Configuring Git hooks..." -ForegroundColor Green
git config core.hooksPath .githooks

# Note: Git hooks path configuration on Windows (.githooks already executable through git)
Write-Host "✓ Git hooks directory configured..." -ForegroundColor Green

# Create directories if they don't exist
Write-Host "✓ Creating certificate directories..." -ForegroundColor Green
if (-not (Test-Path "certs")) {
    New-Item -ItemType Directory -Path "certs" | Out-Null
}

if (-not (Test-Path "private")) {
    New-Item -ItemType Directory -Path "private" | Out-Null
}

# Check for .env file
if (-not (Test-Path ".env")) {
    Write-Host "✓ Creating .env from .env.example..." -ForegroundColor Green
    if (Test-Path ".env.example") {
        Copy-Item ".env.example" ".env"
        Write-Host "  ⚠️  Please edit .env with your configuration before running docker-compose" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "✅ Setup complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Edit .env with your configuration (domain, passwords, etc.)"
Write-Host "2. Run: .\generate-certs.ps1 (to create CSR or use existing certificates)"
Write-Host "3. Run: docker-compose up -d"
Write-Host ""
Write-Host "Git hooks are configured. On subsequent git pulls, ensure hooks"
Write-Host "permissions are maintained by your git client."
