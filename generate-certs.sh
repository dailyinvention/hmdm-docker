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

echo -e "${YELLOW}SSL Certificate Signing Request (CSR) Generation${NC}"
echo "Domain: $DOMAIN"
echo ""

# Generate private key
echo -e "${GREEN}Generating private key...${NC}"
openssl genrsa -out private/hmdm.key 2048

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
echo "  Private Key:  private/hmdm.key"
echo "  CSR File:     certs/hmdm.csr"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Submit certs/hmdm.csr to your Certificate Authority"
echo "2. Once you receive the signed certificate, save it as certs/hmdm.crt"
echo "3. Run: docker-compose up -d"
echo ""
