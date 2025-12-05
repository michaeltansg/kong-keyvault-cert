# Key Vault
resource "azurerm_key_vault" "main" {
  name                       = "kv-certpoc-${random_string.suffix.result}"
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 7
  purge_protection_enabled   = false

  tags = var.tags
}

# Access policy for current user (Terraform operator)
resource "azurerm_key_vault_access_policy" "terraform" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  certificate_permissions = [
    "Create",
    "Delete",
    "Get",
    "Import",
    "List",
    "Update",
    "Recover",
    "Purge",
  ]

  secret_permissions = [
    "Get",
    "List",
    "Set",
    "Delete",
    "Purge",
  ]

  key_permissions = [
    "Get",
    "List",
    "Create",
  ]
}

# Access policy for Managed Identity (VM)
resource "azurerm_key_vault_access_policy" "managed_identity" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_user_assigned_identity.main.principal_id

  certificate_permissions = [
    "Get",
    "List",
  ]

  secret_permissions = [
    "Get",
    "List",
  ]
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

  depends_on = [azurerm_key_vault_access_policy.terraform]
}
