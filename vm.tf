# Network Interface for VM
resource "azurerm_network_interface" "vm" {
  name                = "nic-vm"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = var.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.vm.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm.id
  }
}

# Associate NSG with NIC
resource "azurerm_network_interface_security_group_association" "vm" {
  network_interface_id      = azurerm_network_interface.vm.id
  network_security_group_id = azurerm_network_security_group.vm.id
}

# Linux Virtual Machine
resource "azurerm_linux_virtual_machine" "main" {
  name                = "vm-kong-poc"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  size                = "Standard_B2s"
  admin_username      = var.vm_admin_username

  network_interface_ids = [
    azurerm_network_interface.vm.id
  ]

  admin_ssh_key {
    username   = var.vm_admin_username
    public_key = var.ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.main.id]
  }

  custom_data = base64encode(templatefile("${path.module}/cloud-init.yaml", {
    postgres_host      = azurerm_postgresql_flexible_server.main.fqdn
    postgres_user      = var.postgres_admin_username
    postgres_password  = var.postgres_admin_password
    postgres_database  = azurerm_postgresql_flexible_server_database.kong.name
    keyvault_name      = azurerm_key_vault.main.name
    identity_client_id = azurerm_user_assigned_identity.main.client_id
    vm_admin_username  = var.vm_admin_username
  }))

  tags = var.tags

  depends_on = [
    azurerm_postgresql_flexible_server_database.kong
  ]
}
