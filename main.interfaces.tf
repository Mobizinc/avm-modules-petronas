# Applying Management Lock to the Virtual Network if specified.
resource "azurerm_management_lock" "this" {
  count = (var.lock != null ? 1 : 0)

  lock_level = var.lock.kind
  name       = coalesce(var.lock.name, "lock-${var.lock.kind}")
  scope      = azapi_resource.vnet.id
  notes      = var.lock.kind == "CanNotDelete" ? "Cannot delete the resource or its child resources." : "Cannot delete or modify the resource or its child resources."

  depends_on = [
    azapi_resource.vnet
  ]
}

# Assigning Roles to the Virtual Network based on the provided configurations.
resource "azurerm_role_assignment" "vnet_level" {
  for_each = var.role_assignments

  principal_id                           = each.value.principal_id
  scope                                  = azapi_resource.vnet.id
  condition                              = each.value.condition
  condition_version                      = each.value.condition_version
  delegated_managed_identity_resource_id = each.value.delegated_managed_identity_resource_id
  role_definition_id                     = strcontains(lower(each.value.role_definition_id_or_name), lower(local.role_definition_resource_substring)) ? each.value.role_definition_id_or_name : null
  role_definition_name                   = strcontains(lower(each.value.role_definition_id_or_name), lower(local.role_definition_resource_substring)) ? null : each.value.role_definition_id_or_name
  skip_service_principal_aad_check       = each.value.skip_service_principal_aad_check

  depends_on = [
    azapi_resource.vnet
  ]
}

# Create diagonostic settings for the virtual network
resource "azurerm_monitor_diagnostic_setting" "example" {
  for_each = {
    for key, value in var.diagnostic_settings : key => value
    if value.workspace_resource_id != null || value.storage_account_resource_id != null || value.event_hub_authorization_rule_resource_id != null
  }

  name                           = each.value.name != null ? each.value.name : "defaultDiagnosticSetting"
  target_resource_id             = azapi_resource.vnet.id
  eventhub_authorization_rule_id = each.value.event_hub_authorization_rule_resource_id != null ? each.value.event_hub_authorization_rule_resource_id : null
  eventhub_name                  = each.value.event_hub_name != null ? each.value.event_hub_name : null
  log_analytics_workspace_id     = each.value.workspace_resource_id != null ? each.value.workspace_resource_id : null
  storage_account_id             = each.value.storage_account_resource_id != null ? each.value.storage_account_resource_id : null

  dynamic "enabled_log" {
    for_each = each.value.log_categories_and_groups
    content {
      category = enabled_log.value
    }
  }
  dynamic "metric" {
    for_each = each.value.metric_categories
    content {
      category = metric.value
      enabled  = true
    }
  }

  depends_on = [
    azapi_resource.vnet
  ]
}