# Kong + Azure Key Vault Certificate PoC

Proof of concept for retrieving SSL/TLS certificates from Azure Key Vault and configuring Kong Gateway TLS termination via its Admin API.

## Architecture

```
Internet → Kong (8443 HTTPS) → Nginx (80 HTTP)
                │
    Certificate from Key Vault
                │
Azure Key Vault ← fetch-cert.sh (via Managed Identity)
```

## Components

| Component | Description |
|-----------|-------------|
| **Azure Key Vault** | Certificate storage (RBAC-enabled, VNet-restricted) |
| **Kong Gateway** | API gateway with TLS termination (Docker) |
| **Nginx** | Test upstream service (Docker) |
| **PostgreSQL Flexible Server** | Kong database (VNet integrated) |
| **Managed Identity** | Secure Key Vault access (Key Vault Secrets User role) |

## Prerequisites

- [Terraform](https://www.terraform.io/downloads) >= 1.0
- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) (for authentication)
- Azure subscription

## Quick Start

### 1. Generate SSH Key

```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/azure_vm_key
```

### 2. Configure Variables

```bash
cat > terraform.tfvars << EOF
ssh_public_key          = "$(cat ~/.ssh/azure_vm_key.pub)"
postgres_admin_password = "YourSecurePassword123!"
EOF
```

### 3. Deploy Infrastructure

```bash
az login
terraform init
terraform apply
```

### 4. Configure Kong (on VM)

```bash
# SSH to VM
ssh -i ~/.ssh/azure_vm_key azureuser@<vm-public-ip>

# Wait for cloud-init
cloud-init status --wait

# Fetch certificate from Key Vault and upload to Kong
KEYVAULT_NAME=<keyvault-name> /opt/kong/scripts/fetch-cert.sh

# Setup Kong route
/opt/kong/scripts/setup-kong-route.sh
```

### 5. Test

```bash
# From VM
curl -k https://localhost:8443 -H 'Host: test.example.com'

# From local machine
curl -k https://<vm-public-ip>:8443 -H 'Host: test.example.com'
```

## Browser Testing

Add to `/etc/hosts`:
```
<vm-public-ip>    test.example.com
```

Then visit: `https://test.example.com:8443`

## Security Features

- **RBAC**: Key Vault uses Azure RBAC (not Access Policies)
- **Least Privilege**: Managed Identity has only `Key Vault Secrets User` role
- **Network Isolation**: Key Vault restricted to VM subnet via service endpoint
- **SSL Required**: PostgreSQL connections require SSL

## Clean Up

```bash
terraform destroy
```

## License

MIT
