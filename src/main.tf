# Configure the Microsoft Azure Provider
provider "azurerm" {
    subscription_id = "fab6bd82-e9fb-4229-91d4-476d41c138fb"
    client_id       = "a8e8fcb7-ee3a-4260-8942-73671d830a1a"
    client_secret   = "5Kn8Q~HDr7T4SFNADYvjTXrMxqXZoK0K2vthoaBk"
    tenant_id       = "dc07ee3a-4d6e-436e-b3f4-29e1cc532ced"
    features {
    }
}

# Locate the existing custom/golden image
data "azurerm_image" "search" {
  name                = "windows-vm-def"
  resource_group_name = "Ratan-Terraform"
}

output "image_id" {
  value = "/subscriptions/fab6bd82-e9fb-4229-91d4-476d41c138fb/resourceGroups/RG-EASTUS-SPT-PLATFORM/providers/Microsoft.Compute/images/AZLXSPTDEVOPS01_Image"
}

# Create a Resource Group for the new Virtual Machine.
resource "azurerm_resource_group" "main" {
  name     = "Ratan-Terraform"
  location = "westeroupe"
}

# Create a Virtual Network within the Resource Group
resource "azurerm_virtual_network" "main" {
  name                = "RG-Vnet"
  address_space       = ["10.100.0.0/16"]
  resource_group_name = "${azurerm_resource_group.main.name}"
  location            = "${azurerm_resource_group.main.location}"
}

# Create a Subnet within the Virtual Network
resource "azurerm_subnet" "internal" {
  name                 = "RG-Terraform-snet-in"
  virtual_network_name = "${azurerm_virtual_network.main.name}"
  resource_group_name  = "${azurerm_resource_group.main.name}"
  address_prefixes       = ["10.100.2.0/24"]
}

# Create a Network Security Group with some rules
resource "azurerm_network_security_group" "main" {
  name                = "RG-QA-Test-Web-NSG"
  location            = "${azurerm_resource_group.main.location}"
  resource_group_name = "${azurerm_resource_group.main.name}"

  security_rule {
    name                       = "allow_SSH"
    description                = "Allow SSH access"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Create a network interface for VMs and attach the PIP and the NSG
resource "azurerm_network_interface" "main" {
  name                      = "myNIC"
  location                  = "${azurerm_resource_group.main.location}"
  resource_group_name       = "${azurerm_resource_group.main.name}"
  network_security_group_id = "${azurerm_network_security_group.main.id}"

  ip_configuration {
    name                          = "primary"
    subnet_id                     = "${azurerm_subnet.internal.id}"
    private_ip_address_allocation = "static"
    private_ip_address            = "${cidrhost("10.100.1.8/24", 4)}"
  }
}

# Create a new Virtual Machine based on the Golden Image
resource "azurerm_virtual_machine" "vm" {
  name                             = "AZLXSPTDEVOPS01"
  location                         = "${azurerm_resource_group.main.location}"
  resource_group_name              = "${azurerm_resource_group.main.name}"
  network_interface_ids            = ["${azurerm_network_interface.main.id}"]
  vm_size                          = "Standard_DS12_v2"
  delete_os_disk_on_termination    = true
  delete_data_disks_on_termination = true

  storage_image_reference {
    id = "${data.azurerm_image.search.id}"
  }

  storage_os_disk {
    name              = "AZLXSPTDEVOPS01-OS"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
}

  os_profile {
    computer_name  = "APPVM"
    admin_username = "admin"
    admin_password = "admin#2019"
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }
}