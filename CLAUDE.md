# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Proof of concept for retrieving SSL/TLS certificates from Azure Key Vault and updating Kong Gateway via its Admin API. Uses Terraform for Azure infrastructure provisioning.

## Architecture

```
Internet → Kong (8443 HTTPS) → Nginx (80 HTTP)
                │
    Certificate from Key Vault
                │
Azure Key Vault ← fetch-cert.sh (via Managed Identity)
```

**Components:**
- **Azure Key Vault**: Stores SSL/TLS certificates (self-signed for PoC)
- **Kong Gateway**: API gateway with TLS termination (Docker container)
- **Nginx**: Test upstream service (Docker container)
- **PostgreSQL Flexible Server**: Kong database (VNet integrated)
- **User-Assigned Managed Identity**: Secure access to Key Vault

## Docker Containers

Both Kong and Nginx run as Docker containers on the VM, managed via docker-compose (`/opt/kong/docker-compose.yml`).

| Container | Image | Ports | Purpose |
|-----------|-------|-------|---------|
| `kong` | `kong:3.4` | 8000 (HTTP), 8001 (Admin), 8443 (HTTPS) | API Gateway with TLS termination |
| `nginx-upstream` | `nginx:alpine` | 80 (internal only) | Test upstream service |

**Network**: Both containers share a `kong-net` bridge network. Kong reaches nginx via `nginx-upstream:80`.

**Test Flow**:
1. Request hits Kong on port 8443 (HTTPS)
2. Kong terminates TLS using the certificate from Key Vault
3. Kong forwards request to `nginx-upstream:80` (HTTP)
4. Nginx returns HTML page
5. Response sent back over HTTPS

```bash
# Verify containers are running (on VM)
docker ps

# View logs
docker logs kong
docker logs nginx-upstream
```

## Project Structure

```
├── main.tf              # Provider, resource group, random suffix
├── variables.tf         # Input variables
├── outputs.tf           # Output values (IPs, URLs, commands)
├── network.tf           # VNet, subnets, NSG, public IP, private DNS
├── identity.tf          # User-assigned managed identity
├── keyvault.tf          # Key Vault, access policies, self-signed cert
├── postgres.tf          # PostgreSQL Flexible Server
├── vm.tf                # VM with cloud-init
├── cloud-init.yaml      # Docker, Kong, nginx setup
└── scripts/
    ├── fetch-cert.sh    # Retrieve cert from KV, push to Kong
    └── setup-kong-route.sh  # Configure Kong service/route
```

## Azure Authentication for Terraform

Terraform does not require Azure CLI. It can authenticate via:

**Option A: Azure CLI (easiest for local dev)**
```bash
brew install azure-cli
az login
```

**Option B: Service Principal (no Azure CLI needed)**
```bash
export ARM_CLIENT_ID="<app-id>"
export ARM_CLIENT_SECRET="<password>"
export ARM_TENANT_ID="<tenant-id>"
export ARM_SUBSCRIPTION_ID="<subscription-id>"
```

## Commands

### Deploy Infrastructure

```bash
# Create terraform.tfvars with your values
cat > terraform.tfvars << EOF
ssh_public_key          = "ssh-rsa AAAA..."
postgres_admin_password = "YourSecurePassword123!"
EOF

terraform init
terraform plan
terraform apply
```

### Post-Deployment (on VM)

```bash
# SSH to VM (command shown in terraform output)
ssh azureuser@<public-ip>

# Wait for cloud-init to complete (~5 mins)
cloud-init status --wait

# Fetch certificate and upload to Kong
KEYVAULT_NAME=<from-output> /opt/kong/scripts/fetch-cert.sh

# Setup Kong route
/opt/kong/scripts/setup-kong-route.sh

# Test HTTPS
curl -k https://localhost:8443 -H 'Host: test.example.com'
```

### Verify Certificate

```bash
# Check certificate in Kong
curl http://localhost:8001/certificates

# Verify TLS certificate
openssl s_client -connect <public-ip>:8443 -servername test.example.com
```

### Tear Down Infrastructure

```bash
# Destroy all resources (will prompt for confirmation)
terraform destroy

# Skip confirmation prompt
terraform destroy -auto-approve
```

## Required Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `ssh_public_key` | SSH public key for VM access | Required |
| `postgres_admin_password` | PostgreSQL admin password | Required |
| `location` | Azure region | southeastasia |
| `vm_admin_username` | VM admin username | azureuser |

## Key Outputs

- `vm_public_ip`: Public IP for SSH and Kong access
- `vm_ssh_command`: Ready-to-use SSH command
- `kong_proxy_https_url`: HTTPS endpoint
- `test_https_command`: curl command to test setup
