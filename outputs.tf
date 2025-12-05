output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.main.name
}

output "vm_public_ip" {
  description = "Public IP address of the VM"
  value       = azurerm_public_ip.vm.ip_address
}

output "vm_ssh_command" {
  description = "SSH command to connect to the VM"
  value       = "ssh ${var.vm_admin_username}@${azurerm_public_ip.vm.ip_address}"
}

output "keyvault_name" {
  description = "Name of the Key Vault"
  value       = azurerm_key_vault.main.name
}

output "keyvault_url" {
  description = "URL of the Key Vault"
  value       = azurerm_key_vault.main.vault_uri
}

output "postgres_fqdn" {
  description = "FQDN of the PostgreSQL server"
  value       = azurerm_postgresql_flexible_server.main.fqdn
}

output "kong_admin_url" {
  description = "Kong Admin API URL"
  value       = "http://${azurerm_public_ip.vm.ip_address}:8001"
}

output "kong_proxy_http_url" {
  description = "Kong Proxy HTTP URL"
  value       = "http://${azurerm_public_ip.vm.ip_address}:8000"
}

output "kong_proxy_https_url" {
  description = "Kong Proxy HTTPS URL"
  value       = "https://${azurerm_public_ip.vm.ip_address}:8443"
}

output "managed_identity_client_id" {
  description = "Client ID of the managed identity"
  value       = azurerm_user_assigned_identity.main.client_id
}

output "test_https_command" {
  description = "Command to test HTTPS endpoint"
  value       = "curl -k https://${azurerm_public_ip.vm.ip_address}:8443 -H 'Host: test.example.com'"
}

output "verify_certificate_command" {
  description = "Command to verify the certificate"
  value       = "openssl s_client -connect ${azurerm_public_ip.vm.ip_address}:8443 -servername test.example.com"
}
