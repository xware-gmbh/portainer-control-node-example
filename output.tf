#############################################################################
# OUTPUTS
#############################################################################

output "app-fqdn" {
  value       = azurerm_container_group.default.fqdn
  description = "The fqdn of the app instance."
}