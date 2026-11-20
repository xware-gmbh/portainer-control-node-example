#############################################################################
# GENERAL VARIABLES
#############################################################################

variable "tenant_id" {
  description = "The Azure tenant ID."
}

variable "subscription_id" {
  description = "The Azure subscription ID."
}

variable "client_id" {
  description = "The Azure Service Principal client ID."
}

variable "client_secret" {
  description = "The Azure Service Principal client secret."
}

variable "location" {
  type = map(object({
    regionName = string
    regionCode = string
    regionUrl  = string
  }))
  default = {
    EU = {
      regionName = "West Europe"
      regionCode = "westeurope"
      regionUrl  = "westeurope.azurecontainer.io"
    }
    CH = {
      regionName = "Switzerland North"
      regionCode = "switzerlandnorth"
      regionUrl  = "switzerlandnorth.azurecontainer.io"
    }
  }
}

variable "resource_group_name" {
  type    = string
  default = "rg-aci-kstjj-001"
}
locals {
  full_rg_name = join("-", [terraform.workspace, var.resource_group_name])
}

#############################################################################
# Azure Container Instance VARIABLES
#############################################################################

variable "acr_name" {
  description = "Name of the existing Azure Container Registry"
  type        = string
  default     = "jjscontainers"
}

variable "acr_resource_group_name" {
  description = "Resource group where the ACR resides"
  type        = string
  default     = "rg-default-kstjj-001"
}

variable "storage_name" {
  # only letters and numbers!
  type = map(string)
  default = {
    TST = "stacikstjj001tst"
    PRD = "stacikstjj001prd"
  }
}
variable "storage_share_name" {
  type = map(string)
  default = {
    TST = "shstacikstjj001tst"
    PRD = "shstacikstjj001prd"
  }
}

# Source: https://hub.docker.com/_/traefik/tags?page=1&name=2.
variable "traefik_image" {
  type = map(string)
  default = {
    TST = "jjscontainers.azurecr.io/traefik:v2.11.28"
    PRD = "jjscontainers.azurecr.io/traefik:v2.11.28"
  }
}

# Source: https://hub.docker.com/r/portainer/portainer-ee/tags?page=1
#
# Download backup from Portainer settings before updateing!!!!
#
variable "portainer_image" {
  type = map(string)
  default = {
    TST = "jjscontainers.azurecr.io/portainer/portainer-ee:2.32.0-linux-amd64"
    PRD = "jjscontainers.azurecr.io/portainer/portainer-ee:2.32.0-linux-amd64"
  }
}

variable "agent_secret" {}

#############################################################################
# TAGS
#
# tag_environment = terraform.workspace
#
#############################################################################
variable "tag_owner" {
  default = "jan.jambor@xwr.ch"
}
variable "tag_application_name" {
  type = map(string)
  default = {
    TST = "aci-test-portainer"
    PRD = "aci-portainer"
  }
}
variable "tag_costcenter" {
  default = "jj"
}
variable "tag_dr" {
  default = "essential"
}