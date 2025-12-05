# Key Vault with RBAC authorization
resource "azurerm_key_vault" "main" {
  name                       = "kv-certpoc-${random_string.suffix.result}"
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 7
  purge_protection_enabled   = false
  enable_rbac_authorization  = true

  # Network access - allow only from VM subnet and Azure services
  network_acls {
    default_action             = "Deny"
    bypass                     = "AzureServices"
    virtual_network_subnet_ids = [azurerm_subnet.vm.id]
  }

  tags = var.tags
}

# RBAC: Terraform operator - Key Vault Certificates Officer
# Needed to create/manage the self-signed certificate
resource "azurerm_role_assignment" "terraform_certificates_officer" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Certificates Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

# RBAC: Managed Identity - Key Vault Secrets User
# Needed to download certificate with private key (stored as secret)
resource "azurerm_role_assignment" "mi_secrets_user" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.main.principal_id
}

# Self-signed certificate for testing
resource "azurerm_key_vault_certificate" "test" {
  name         = "test-certificate"
  key_vault_id = azurerm_key_vault.main.id

  certificate_policy {
    issuer_parameters {
      name = "Self"
    }

    key_properties {
      exportable = true
      key_size   = 2048
      key_type   = "RSA"
      reuse_key  = true
    }

    lifetime_action {
      action {
        action_type = "AutoRenew"
      }

      trigger {
        days_before_expiry = 30
      }
    }

    secret_properties {
      content_type = "application/x-pkcs12"
    }

    x509_certificate_properties {
      subject            = "CN=test.example.com"
      validity_in_months = 12

      subject_alternative_names {
        dns_names = ["test.example.com", "*.example.com"]
      }

      key_usage = [
        "digitalSignature",
        "keyEncipherment",
      ]

      extended_key_usage = ["1.3.6.1.5.5.7.3.1"] # serverAuth
    }
  }

  depends_on = [azurerm_role_assignment.terraform_certificates_officer]
}
