#!/bin/bash

# Setup script for Headwind MDM Docker installation
# Run this once after cloning: ./setup.sh

set -e

echo "🔧 Setting up Headwind MDM installation..."
echo ""

# Configure Git hooks
echo "✓ Configuring Git hooks..."
git config core.hooksPath .githooks

# Make scripts executable
echo "✓ Making scripts executable..."
chmod +x generate-certs.sh
chmod +x docker-entrypoint.sh
chmod +x .githooks/post-checkout

# Create directories if they don't exist
echo "✓ Creating certificate directories..."
mkdir -p certs
mkdir -p private

# Check for .env file
if [ ! -f ".env" ]; then
    echo "✓ Creating .env from .env.example..."
    if [ -f ".env.example" ]; then
        cp .env.example .env
        echo "  ⚠️  Please edit .env with your configuration before running docker-compose"
    fi
fi

echo ""
echo "✅ Setup complete!"
echo ""
echo "Next steps:"
echo "1. Edit .env with your configuration (domain, passwords, etc.)"
echo "2. Run: ./generate-certs.sh (to create CSR or use existing certificates)"
echo "3. Run: docker-compose up -d"
echo ""
echo "Git hooks are now configured. Scripts will automatically become"
echo "executable on future git pulls."
