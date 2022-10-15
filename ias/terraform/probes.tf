

# MONITORING
# AZURE APPLICATION INSIGHT (MESURE DE PERFORMANCE DE L'APPLICATION)
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/application_insights

resource "azurerm_application_insights" "insight" {
  name                = "insights-magento"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  application_type    = "web"

}
# STEP 1 CREATION D'UN COMPTE DE STOCKAGE
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_account
resource "azurerm_storage_account" "storage-monitor" {
  name                     = "stamonitor"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}
# STEP 2 CREATION DU GROUPE QUI SERA MONITORER
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/monitor_action_group

resource "azurerm_monitor_action_group" "group-monitor" {
  name                = "group-monitor"
  resource_group_name = azurerm_resource_group.rg.name
  short_name          = "monitor-grp"

   email_receiver {
    name          = "sendtoadmin"
    email_address = "ryanomagento@gmail.com"
  }
}

# MISE EN PLACE DE L'ALERTE POUR LA VM "BDD"
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/monitor_metric_alert

resource "azurerm_monitor_metric_alert" "alert-stock" {
  name                = "alert-stock-capacity"
  resource_group_name = azurerm_resource_group.rg.name
  scopes              = [azurerm_storage_account.storage-bdd.id]
  description         = "Space alert"
  target_resource_type = "Microsoft.Storage/storageAccounts"
  frequency = "PT1H"
  window_size = "PT12H"

  criteria {
    metric_namespace = "Microsoft.Storage/storageAccounts"
    metric_name      = "UsedCapacity"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 450000
  }

  action {
    action_group_id = azurerm_monitor_action_group.group-monitor.id
  }
}


resource "azurerm_application_insights_web_test" "example" {
  name                    = "tf-test-appinsights-webtest"
  location                = azurerm_resource_group.rg.location
  resource_group_name     = azurerm_resource_group.rg.name
  application_insights_id = azurerm_application_insights.insight.id
  kind                    = "ping"
  frequency               = 300
  timeout                 = 60
  enabled                 = true
  geo_locations           = ["us-tx-sn1-azr", "us-il-ch1-azr"]

  configuration = <<XML
<WebTest Name="WebTest1" Id="ABD48585-0831-40CB-9069-682EA6BB3583" Enabled="True" CssProjectStructure="" CssIteration="" Timeout="0" WorkItemIds="" xmlns="http://microsoft.com/schemas/VisualStudio/TeamTest/2010" Description="" CredentialUserName="" CredentialPassword="" PreAuthenticate="True" Proxy="default" StopOnError="False" RecordedResultFile="" ResultsLocale="">
  <Items>
    <Request Method="GET" Guid="a5f10126-e4cd-570d-961c-cea43999a200" Version="1.1" Url="http://microsoft.com" ThinkTime="0" Timeout="300" ParseDependentRequests="True" FollowRedirects="True" RecordResult="True" Cache="False" ResponseTimeGoal="0" Encoding="utf-8" ExpectedHttpStatusCode="200" ExpectedResponseUrl="" ReportingName="" IgnoreHttpStatusCode="False" />
  </Items>
</WebTest>
XML

}


# CREATION D'UNE RESSOURCE QUI GENERE UN TEMPLATE AU FORMAT JSON
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/template_deployment

resource "azurerm_resource_group_template_deployment" "example" {
  name                = "arm-deploy"
  resource_group_name = azurerm_resource_group.rg.name
  deployment_mode     = "Incremental"

  template_content = <<DEPLOY
{
    "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "webtests_requesthttp_insights_app_name": {
            "defaultValue": "requesthttp-insights-app",
            "type": "String"
        }
    },
    "variables": {},
    "resources": [
        {
            "type": "Microsoft.Insights/webtests",
            "apiVersion": "2022-06-15",
            "name": "[parameters('webtests_requesthttp_insights_app_name')]",
            "location": "eastus2",
            "tags": {
                "hidden-link:${azurerm_application_insights.insight.id}": "Resource"
            },
            "properties": {
                "SyntheticMonitorId": "[parameters('webtests_requesthttp_insights_app_name')]",
                "Name": "requesthttp",
                "Enabled": true,
                "Frequency": 300,
                "Timeout": 120,
                "Kind": "standard",
                "RetryEnabled": true,
                "Locations": [
                    {
                        "Id": "us-va-ash-azr"
                    },
                    {
                        "Id": "us-ca-sjc-azr"
                    },
                    {
                        "Id": "us-fl-mia-edge"
                    },
                    {
                        "Id": "apac-sg-sin-azr"
                    },
                    {
                        "Id": "emea-ru-msa-edge"
                    }
                ],
                "Request": {
                    "RequestUrl": "https://${var.fqdn}.${var.resource_group_location}.cloudapp.azure.com",
                    "HttpVerb": "GET",
                    "ParseDependentRequests": false
                },
                "ValidationRules": {
                    "ExpectedHttpStatusCode": 200,
                    "SSLCheck": false
                }
            }
        }
    ]
}
DEPLOY
}



resource "azurerm_monitor_metric_alert" "alert-availability" {
  name                = "alert-availability"
  resource_group_name = azurerm_resource_group.rg.name
  scopes              = [azurerm_application_insights.insight.id]
  description         = "Availability"

  criteria {
    metric_namespace = "Microsoft.Insights/components"
    metric_name      = "availabilityResults/availabilityPercentage"
    aggregation      = "Average"
    operator         = "LessThan"
    threshold        = 100
    dimension {
      name="availabilityResult/name"
      operator = "Include"
      values=["requesthttp"]
    }
  }

  action {
    action_group_id = azurerm_monitor_action_group.group-monitor.id
  }
}

