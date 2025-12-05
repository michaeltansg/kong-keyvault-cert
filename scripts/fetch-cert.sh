#!/bin/bash
# Fetch certificate from Azure Key Vault and upload to Kong
# This script is designed to run on the VM with managed identity

set -e

# Configuration - these can be overridden by environment variables
KEYVAULT_NAME="${KEYVAULT_NAME:-}"
CERT_NAME="${CERT_NAME:-test-certificate}"
KONG_ADMIN_URL="${KONG_ADMIN_URL:-http://localhost:8001}"
IDENTITY_CLIENT_ID="${IDENTITY_CLIENT_ID:-}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check required variables
if [ -z "$KEYVAULT_NAME" ]; then
    print_error "KEYVAULT_NAME is required. Set it via environment variable."
    echo "Usage: KEYVAULT_NAME=<vault-name> $0"
    exit 1
fi

print_status "=== Fetching certificate from Azure Key Vault ==="
print_status "Key Vault: $KEYVAULT_NAME"
print_status "Certificate: $CERT_NAME"
print_status "Kong Admin URL: $KONG_ADMIN_URL"

# Login with managed identity
print_status "Logging in with managed identity..."
if [ -n "$IDENTITY_CLIENT_ID" ]; then
    az login --identity --allow-no-subscriptions --client-id "$IDENTITY_CLIENT_ID" --output none
else
    az login --identity --allow-no-subscriptions --output none
fi

# Download the certificate (stored as secret in PFX format)
print_status "Downloading certificate from Key Vault..."
az keyvault secret download \
    --vault-name "$KEYVAULT_NAME" \
    --name "$CERT_NAME" \
    --file /tmp/cert.pfx \
    --encoding base64

# Convert PFX to PEM (certificate)
print_status "Extracting certificate..."
openssl pkcs12 -in /tmp/cert.pfx -clcerts -nokeys -out /tmp/cert.pem -passin pass: 2>/dev/null

# Convert PFX to PEM (private key)
print_status "Extracting private key..."
openssl pkcs12 -in /tmp/cert.pfx -nocerts -nodes -out /tmp/key.pem -passin pass: 2>/dev/null

# Verify extracted files
if [ ! -s /tmp/cert.pem ] || [ ! -s /tmp/key.pem ]; then
    print_error "Failed to extract certificate or key from PFX"
    exit 1
fi

# Read certificate and key content
CERT=$(cat /tmp/cert.pem)
KEY=$(cat /tmp/key.pem)

# Check if Kong is accessible
print_status "Checking Kong Admin API..."
if ! curl -s "$KONG_ADMIN_URL" > /dev/null; then
    print_error "Cannot reach Kong Admin API at $KONG_ADMIN_URL"
    exit 1
fi

# Upload to Kong
print_status "Uploading certificate to Kong..."
CERT_RESPONSE=$(curl -s -X POST "$KONG_ADMIN_URL/certificates" \
    -F "cert=$CERT" \
    -F "key=$KEY" \
    -F "snis[]=test.example.com" \
    -F "snis[]=*.example.com")

CERT_ID=$(echo "$CERT_RESPONSE" | jq -r '.id')

if [ "$CERT_ID" != "null" ] && [ -n "$CERT_ID" ]; then
    print_status "Certificate uploaded successfully!"
    echo ""
    echo "Certificate ID: $CERT_ID"
    echo ""

    # Display SNIs
    echo "SNIs configured:"
    echo "$CERT_RESPONSE" | jq -r '.snis[]'
else
    # Check if certificate already exists
    EXISTING=$(echo "$CERT_RESPONSE" | jq -r '.message // empty')
    if [[ "$EXISTING" == *"already exists"* ]]; then
        print_warning "Certificate or SNI already exists. Attempting update..."

        # Get existing certificate ID by SNI
        EXISTING_CERT=$(curl -s "$KONG_ADMIN_URL/snis/test.example.com" | jq -r '.certificate.id')

        if [ "$EXISTING_CERT" != "null" ] && [ -n "$EXISTING_CERT" ]; then
            # Update existing certificate
            curl -s -X PATCH "$KONG_ADMIN_URL/certificates/$EXISTING_CERT" \
                -F "cert=$CERT" \
                -F "key=$KEY" > /dev/null
            print_status "Certificate updated successfully!"
            echo "Certificate ID: $EXISTING_CERT"
        else
            print_error "Failed to update certificate"
            echo "$CERT_RESPONSE"
            exit 1
        fi
    else
        print_error "Failed to upload certificate"
        echo "$CERT_RESPONSE"
        exit 1
    fi
fi

# Cleanup temporary files
rm -f /tmp/cert.pfx /tmp/cert.pem /tmp/key.pem

print_status "=== Certificate setup complete ==="
echo ""
echo "Verify certificate in Kong:"
echo "  curl $KONG_ADMIN_URL/certificates"
echo ""
