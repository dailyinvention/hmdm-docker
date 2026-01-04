#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if directories exist
if [ ! -d "certs" ]; then
    mkdir -p certs
fi

if [ ! -d "private" ]; then
    mkdir -p private
fi

# Get domain from .env or use default
if [ -f ".env" ]; then
    DOMAIN=$(grep HMDM_SERVER_URL .env | cut -d '=' -f 2)
else
    DOMAIN="hmdm.example.com"
fi

# Get certificate type from environment variable (default to ECC)
CERT_TYPE="${CERT_TYPE:-ecc}"
CERT_TYPE=$(echo "$CERT_TYPE" | tr '[:upper:]' '[:lower:]')

echo -e "${YELLOW}SSL Certificate Signing Request (CSR) Generation${NC}"
echo "Domain: $DOMAIN"
echo "Certificate Type: $CERT_TYPE"
echo ""

# Generate private key based on certificate type
echo -e "${GREEN}Generating private key...${NC}"
if [ "$CERT_TYPE" = "rsa" ]; then
    openssl genrsa -out private/hmdm.key 2048
    KEY_INFO="RSA 2048-bit"
else
    openssl ecparam -name prime256v1 -genkey -noout -out private/hmdm.key
    KEY_INFO="ECC (prime256v1)"
fi

# Generate CSR (Certificate Signing Request)
echo -e "${GREEN}Generating Certificate Signing Request (CSR)...${NC}"
openssl req -new -key private/hmdm.key -out certs/hmdm.csr -subj "/C=US/ST=State/L=City/O=Organization/CN=$DOMAIN"

# Set proper permissions
chmod 600 private/hmdm.key
chmod 644 certs/hmdm.csr

echo ""
echo -e "${GREEN}CSR generation complete!${NC}"
echo ""
echo -e "${YELLOW}Files created:${NC}"
echo "  Private Key:  private/hmdm.key ($KEY_INFO)"
echo "  CSR File:     certs/hmdm.csr"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Submit certs/hmdm.csr to your Certificate Authority"
echo "2. Once you receive the signed certificate, save it as certs/hmdm.crt"
echo "3. Run: docker-compose up -d"
echo ""
