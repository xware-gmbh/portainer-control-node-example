#############################################################################
# RESOURCES DEFAULT
#############################################################################

resource "azurerm_resource_group" "default" {
  name     = local.full_rg_name
  location = var.location.CH.regionName
}

#############################################################################
# Storage Account & Storage Share
#############################################################################
resource "azurerm_storage_account" "default" {
  name                            = var.storage_name[terraform.workspace]
  resource_group_name             = azurerm_resource_group.default.name
  location                        = azurerm_resource_group.default.location
  account_kind                    = "Storage" # defaults "StorageV2"
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  allow_nested_items_to_be_public = false
  min_tls_version                  = "TLS1_2"

  tags = {
    Environment     = terraform.workspace
    Owner           = var.tag_owner
    ApplicationName = var.tag_application_name[terraform.workspace]
    CostCenter      = var.tag_costcenter
    DR              = var.tag_dr
  }
}

resource "azurerm_storage_share" "default-traefik" {
  name                 = join("-", [var.storage_share_name[terraform.workspace], "traefik"])
  storage_account_id   = azurerm_storage_account.default.id
  quota                = 50
}

resource "azurerm_storage_share" "default-portainer" {
  name                 = join("-", [var.storage_share_name[terraform.workspace], "portainer"])
  storage_account_id   = azurerm_storage_account.default.id
  quota                = 50
}

#############################################################################
# Write config files
#############################################################################

resource "local_file" "traefik-toml" {
  content = <<-EOT
                  defaultEntryPoints = ["http", "https"]
                  [acceslog]
                  [entryPoints]
                    [entryPoints.http]
                      address = ":80"
                      [entryPoints.http.http]
                      [entryPoints.http.http.redirections]
                        [entryPoints.http.http.redirections.entryPoint]
                          to = "https"
                          scheme = "https"
                    [entryPoints.https]
                      address = ":443"
                    [entryPoints.https.http.tls]
                      certResolver = "le"
                  [log]
                    level="DEBUG"
                  [api]
                    dashboard = false
                    insecure = false
                  [providers]
                  [providers.file]
                    directory = "/etc/traefik/services"
                    watch = true
                  [certificatesResolvers.le.acme]
                    storage = "/acme.json"
                    email = "${var.tag_owner}"
                    # Once you get things working, you should remove that whole line altogether.
                    #caServer = "https://acme-staging-v02.api.letsencrypt.org/directory"
                    caServer = "https://acme-v02.api.letsencrypt.org/directory"
                    [certificatesResolvers.le.acme.tlsChallenge]
                  EOT

  filename = "traefik.toml"

  provisioner "local-exec" {
    command = "az storage file upload --account-name ${azurerm_storage_account.default.name} --account-key ${azurerm_storage_account.default.primary_access_key} --share-name ${azurerm_storage_share.default-traefik.name} --source \"traefik.toml\" --path \"traefik.toml\""
  }

}

resource "local_file" "portainer-toml" {
  content = <<-EOT
                  [http]
                    # Add the router
                    [http.routers]
                      [http.routers.portainer]
                        entrypoints = ["https"]
                        service = "portainer"
                        rule = "Host(`${join("", [var.tag_application_name[terraform.workspace], ".${var.location.CH.regionUrl}"])}`)"
                      [http.routers.portainer.tls]
                        certResolver = "le"
                      # Define how to reach an existing service on our infrastructure
                      [http.services]
                        [http.services.portainer]
                          [http.services.portainer.loadBalancer]
                            [[http.services.portainer.loadBalancer.servers]]
                              # As we are in the same container group, container can talk to each other through localhost or 127.0.0.1
                              url = "http://127.0.0.1:9000"
                  EOT

  filename = "portainer.toml"

  provisioner "local-exec" {
    command = "az storage directory create --account-name ${azurerm_storage_account.default.name} --account-key ${azurerm_storage_account.default.primary_access_key} --share-name ${azurerm_storage_share.default-traefik.name} --name \"services\" --output none"
  }

  provisioner "local-exec" {
    command = "az storage file upload --account-name ${azurerm_storage_account.default.name} --account-key ${azurerm_storage_account.default.primary_access_key} --share-name ${azurerm_storage_share.default-traefik.name} --source \"portainer.toml\" --path \"services\\portainer.toml\""
  }
}

#############################################################################
# RESOURCES ACI Portainer
#############################################################################

resource "azurerm_user_assigned_identity" "aci_pull" {
  name                = "${terraform.workspace}-${var.tag_application_name[terraform.workspace]}-acr-mi"
  location            = azurerm_resource_group.default.location
  resource_group_name = azurerm_resource_group.default.name
}

resource "azurerm_container_group" "default" {
  name                = join("-", [terraform.workspace, var.tag_application_name[terraform.workspace]])
  location            = azurerm_resource_group.default.location
  resource_group_name = azurerm_resource_group.default.name
  ip_address_type     = "Public"
  dns_name_label      = var.tag_application_name[terraform.workspace]
  os_type             = "Linux"

  depends_on = [azurerm_role_assignment.aci_acr_pull]

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aci_pull.id]
  }

  image_registry_credential {
    user_assigned_identity_id = azurerm_user_assigned_identity.aci_pull.id
    server                    = data.azurerm_container_registry.existing.login_server
  }

  #############################################################################
  # traefik

  exposed_port {
    port     = 80
    protocol = "TCP"
  }

  exposed_port {
    port     = 443
    protocol = "TCP"
  }

  container {
    name     = "traefik"
    image    = var.traefik_image[terraform.workspace]
    cpu      = "0.2"
    memory   = "0.1"
    commands = ["sh", "-c", "touch acme.json && chmod 600 acme.json && traefik"]

    ports {
      port     = 80
      protocol = "TCP"
    }

    ports {
      port     = 443
      protocol = "TCP"
    }

    volume {
      name       = "traefik-config"
      mount_path = "/etc/traefik/"
      read_only  = true
      share_name = azurerm_storage_share.default-traefik.name

      storage_account_name = azurerm_storage_account.default.name
      storage_account_key  = azurerm_storage_account.default.primary_access_key
    }

  }

  #############################################################################
  # portainer

  exposed_port {
    port     = 8000
    protocol = "TCP"
  }

  container {
    name   = "portainer"
    image  = var.portainer_image[terraform.workspace]
    cpu    = "0.5"
    memory = "0.5"

    environment_variables = {
      AGENT_SECRET = "${var.agent_secret}"
    }

    ports {
      port     = 8000
      protocol = "TCP"
    }

    ports {
      port     = 9000
      protocol = "TCP"
    }

    volume {
      name       = "data"
      mount_path = "/data"
      read_only  = false
      share_name = azurerm_storage_share.default-portainer.name

      storage_account_name = azurerm_storage_account.default.name
      storage_account_key  = azurerm_storage_account.default.primary_access_key
    }
  }

  tags = {
    Environment     = terraform.workspace
    Owner           = var.tag_owner
    ApplicationName = var.tag_application_name[terraform.workspace]
    CostCenter      = var.tag_costcenter
    DR              = var.tag_dr
  }

}

#############################################################################
# Read existing ACR & Grant AcrPull to the ACI managed identity

data "azurerm_container_registry" "existing" {
  name                = var.acr_name
  resource_group_name = var.acr_resource_group_name
}

resource "azurerm_role_assignment" "aci_acr_pull" {
  scope                = data.azurerm_container_registry.existing.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_user_assigned_identity.aci_pull.principal_id
}
