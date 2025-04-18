#############################################################################
# GENERAL VARIABLES
#############################################################################

variable location {
  type    = map(object({
    regionName  = string
    regionCode  = string
    regionUrl   = string
  }))
  default = {
    EU = {
      regionName  = "West Europe"
      regionCode  = "westeurope"
      regionUrl   = "westeurope.azurecontainer.io"
    }
    CH = {
      regionName  = "Switzerland North"
      regionCode  = "switzerlandnorth"
      regionUrl   = "switzerlandnorth.azurecontainer.io"
    }
  }
}

variable resource_group_name {
  type = string
  default = "rg-aci-kstjj-001"
}
locals {
  full_rg_name =  join("-", [terraform.workspace, var.resource_group_name])
}

#############################################################################
# Azure Container Instance VARIABLES
#############################################################################

variable storage_name {
  # only letters and numbers!
  type = map(string)
  default = {
    TST = "stacikstjj001tst"
    PRD = "stacikstjj001prd"
  }
}
variable storage_share_name {
  type = map(string)
  default = {
    TST = "shstacikstjj001tst"
    PRD = "shstacikstjj001prd"
  }
}

# Source: https://hub.docker.com/_/traefik/tags?page=1&name=2.
variable traefik_image {
  type = map(string)
  default = {
    TST = "traefik:v2.11.5"
    PRD = "traefik:v2.11.5"
  }
}

# Source: https://hub.docker.com/r/portainer/portainer-ee/tags?page=1
#
# Download backup from Portainer settings before updateing!!!!
#
variable portainer_image {
  type = map(string)
  default = {
    TST = "portainer/portainer-ee:linux-amd64-2.21.0"
    PRD = "portainer/portainer-ee:linux-amd64-2.21.0"
  }
}

variable agent_secret {}

#############################################################################
# TAGS
#
# tag_environment = terraform.workspace
#
#############################################################################
variable "tag_owner" {
  default     = "jan.jambor@xwr.ch"
}
variable "tag_application_name" {
  type = map(string)
  default = {
    TST = "aci-test-portainer"
    PRD = "aci-portainer"
  }
}
variable "tag_costcenter" {
  default     = "jj"
}
variable "tag_dr" {
  default     = "essential"
}