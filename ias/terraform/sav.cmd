sudo php bin/magento setup:install --base-url=http://localhost/magento2 --db-host=magento-mariadb-server.mariadb.database.azure.com --db-name=mariadb_database --db-user=magento@magento-mariadb-server --db-password=blablabla123! --admin-firstname=admin --admin-lastname=admin --admin-email=admin@admin.com --admin-user=admin --admin-password=admin123 --language=en_US --currency=USD --timezone=America/Chicago --use-rewrites=1 --search-engine=elasticsearch7 --elasticsearch-host=2aaa992d3eef4ef8bbd75c9ddd77bd13.eastus.azure.elastic-cloud.com --elasticsearch-port=443 --elasticsearch-index-prefix=magento2 --elasticsearch-timeout=15
resource "azurerm_monitor_metric_alert" "alert-availability" {
  name                = "alert-availability"
  resource_group_name = azurerm_resource_group.rg.name
  scopes              = [local.files.id]
  description         = "Availability"
  target_resource_type = "microsoft.insights/webtests"

  criteria {
    metric_namespace = "microsoft.insights/webtests"
    metric_name      = "Availability"
    aggregation      = "Average"
    operator         = "LessThan"
    threshold        = 100
    dimension {
      name="Test name"
      operator = "Include"
      values=["requesthttp"]
    }
  }

  action {
    action_group_id = azurerm_monitor_action_group.group-monitor.id
  }
}