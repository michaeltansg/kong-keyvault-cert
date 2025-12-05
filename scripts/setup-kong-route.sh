#!/bin/bash
# Setup Kong upstream, service, and route for the nginx test service

set -e

KONG_ADMIN_URL="${KONG_ADMIN_URL:-http://localhost:8001}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_status "=== Setting up Kong route ==="
print_status "Kong Admin URL: $KONG_ADMIN_URL"

# Check if Kong is accessible
if ! curl -s "$KONG_ADMIN_URL" > /dev/null; then
    print_error "Cannot reach Kong Admin API at $KONG_ADMIN_URL"
    exit 1
fi

# Create upstream
print_status "Creating upstream 'nginx-upstream'..."
curl -s -X POST "$KONG_ADMIN_URL/upstreams" \
    -d "name=nginx-upstream" \
    -o /dev/null || true

# Add target to upstream (nginx container)
print_status "Adding target to upstream..."
curl -s -X POST "$KONG_ADMIN_URL/upstreams/nginx-upstream/targets" \
    -d "target=nginx-upstream:80" \
    -o /dev/null || true

# Create service pointing to upstream
print_status "Creating service 'nginx-service'..."
curl -s -X POST "$KONG_ADMIN_URL/services" \
    -d "name=nginx-service" \
    -d "host=nginx-upstream" \
    -d "port=80" \
    -d "protocol=http" \
    -o /dev/null || true

# Create route for HTTPS traffic
print_status "Creating route 'nginx-route'..."
curl -s -X POST "$KONG_ADMIN_URL/services/nginx-service/routes" \
    -d "name=nginx-route" \
    -d "protocols[]=https" \
    -d "protocols[]=http" \
    -d "hosts[]=test.example.com" \
    -d "paths[]=/" \
    -d "strip_path=false" \
    -o /dev/null || true

print_status "=== Kong route setup complete ==="
echo ""
echo "Configuration summary:"
echo "  Upstream:  nginx-upstream -> nginx-upstream:80"
echo "  Service:   nginx-service -> nginx-upstream"
echo "  Route:     nginx-route (test.example.com)"
echo ""
echo "Test commands:"
echo ""
echo "  # Test HTTP (from VM):"
echo "  curl http://localhost:8000 -H 'Host: test.example.com'"
echo ""
echo "  # Test HTTPS (from VM):"
echo "  curl -k https://localhost:8443 -H 'Host: test.example.com'"
echo ""
echo "  # Test from external (replace <public-ip>):"
echo "  curl -k https://<public-ip>:8443 -H 'Host: test.example.com'"
echo ""
echo "  # Verify certificate:"
echo "  openssl s_client -connect <public-ip>:8443 -servername test.example.com"
echo ""
