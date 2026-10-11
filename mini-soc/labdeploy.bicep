// Lean version of Microsoft's Defender for Cloud lab environment (Module 1):
// https://github.com/Azure/Microsoft-Defender-for-Cloud/blob/main/Labs/Modules/Module-1-Preparing-the-Environment.md
// Decompiled from labdeploy.json; AKS, Container Registry, App Service and Function App removed to cut cost.
// The open RDP/SSH rules and HTTP-allowed storage are deliberate: they give Defender for Cloud findings to work with.

@description('Provide administrative user account for resources')
param username string = 'ascadmin'

@description('Provide password for resources')
@secure()
param password string

@allowed([
  'Standard_LRS'
  'Standard_ZRS'
  'Standard_GRS'
  'Standard_RAGRS'
  'Premium_LRS'
])
param storageAccountType string = 'Standard_LRS'
param resourceTags object = {
  Demo: 'ASC'
  ProvisionedBy: 'CxE'
}

var workspaceName = toLower('asclab-la-${uniqueString(subscription().subscriptionId)}')
var workspaceSKU = 'PerGB2018'
var vmNameWindows_var = 'asclab-win'
var vmNameLinux_var = 'asclab-linux'
var vmSize = 'Standard_D2als_v7'
var availabilitySetName = 'asclab-as'
var vNetName = 'asclab-vnet'
var vNetAddressPrefix = '192.168.0.0/16'
var subnetName = 'default'
var subnetAddressPrefix = '192.168.0.0/24'
var vNetId = vNet.id
var subnetRef = '${vNetId}/subnets/${subnetName}'
var nsgName = 'asclab-nsg'
var windowsOffer = 'WindowsServer'
var windowsSku = '2022-datacenter-azure-edition'
var windowsPublisher = 'MicrosoftWindowsServer'
var linuxOffer = '0001-com-ubuntu-server-jammy'
var linuxSku = '22_04-lts-gen2'
var linuxPublisher = 'Canonical'
var storageName = toLower('asclabsa${uniqueString(subscription().subscriptionId)}')
var kvName = toLower('asclab-kv-${uniqueString(subscription().subscriptionId)}')
var sqlServerName = toLower('asclab-sql-${uniqueString(subscription().subscriptionId)}')
var sqlDatabaseName = 'asclab-db'

resource workspace 'Microsoft.OperationalInsights/workspaces@2015-11-01-preview' = {
  location: resourceGroup().location
  name: workspaceName
  properties: {
    sku: {
      name: workspaceSKU
    }
  }
}

resource workspaceName_System 'Microsoft.OperationalInsights/workspaces/dataSources@2015-11-01-preview' = {
  parent: workspace
  name: 'System'
  kind: 'WindowsEvent'
  properties: {
    eventLogName: 'System'
    eventTypes: [
      {
        eventType: 'Error'
      }
      {
        eventType: 'Warning'
      }
    ]
  }
}

resource workspaceName_Application 'Microsoft.OperationalInsights/workspaces/dataSources@2015-11-01-preview' = {
  parent: workspace
  name: 'Application'
  kind: 'WindowsEvent'
  properties: {
    eventLogName: 'Application'
    eventTypes: [
      {
        eventType: 'Error'
      }
      {
        eventType: 'Warning'
      }
    ]
  }
}

resource workspaceName_Syslog 'Microsoft.OperationalInsights/workspaces/datasources@2015-11-01-preview' = {
  parent: workspace
  name: 'Syslog'
  kind: 'LinuxSyslog'
  properties: {
    syslogName: 'syslog'
    syslogSeverities: [
      {
        severity: 'emerg'
      }
      {
        severity: 'alert'
      }
      {
        severity: 'crit'
      }
      {
        severity: 'err'
      }
      {
        severity: 'warning'
      }
    ]
  }
}

resource workspaceName_SyslogCollection 'Microsoft.OperationalInsights/workspaces/dataSources@2015-11-01-preview' = {
  parent: workspace
  name: 'SyslogCollection'
  kind: 'LinuxSyslogCollection'
  properties: {
    state: 'Enabled'
  }
}

resource nsg 'Microsoft.Network/networkSecurityGroups@2017-03-01' = {
  name: nsgName
  location: resourceGroup().location
  tags: resourceTags
  properties: {
    securityRules: [
      {
        name: 'AllowRDP'
        properties: {
          access: 'Allow'
          description: 'Inbound RDP rule'
          direction: 'Inbound'
          destinationAddressPrefix: '*'
          protocol: 'Tcp'
          destinationPortRange: '3389'
          sourcePortRange: '*'
          priority: 500
          sourceAddressPrefix: '*'
        }
      }
      {
        name: 'AllowSSH'
        properties: {
          access: 'Allow'
          description: 'Inbound SSH rule'
          direction: 'Inbound'
          destinationAddressPrefix: '*'
          protocol: 'Tcp'
          destinationPortRange: '22'
          sourcePortRange: '*'
          priority: 501
          sourceAddressPrefix: '*'
        }
      }
    ]
  }
}

resource vmNameWindows_pip 'Microsoft.Network/publicIPAddresses@2018-08-01' = {
  name: '${vmNameWindows_var}-pip'
  location: resourceGroup().location
  tags: resourceTags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: toLower('${vmNameWindows_var}${uniqueString(subscription().subscriptionId)}')
    }
  }
}

resource vmNameLinux_pip 'Microsoft.Network/publicIPAddresses@2018-08-01' = {
  name: '${vmNameLinux_var}-pip'
  location: resourceGroup().location
  tags: resourceTags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: toLower('${vmNameLinux_var}${uniqueString(subscription().subscriptionId)}')
    }
  }
}

resource vNet 'Microsoft.Network/virtualNetworks@2018-08-01' = {
  name: vNetName
  location: resourceGroup().location
  tags: resourceTags
  properties: {
    addressSpace: {
      addressPrefixes: [
        vNetAddressPrefix
      ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: subnetAddressPrefix
          networkSecurityGroup: {
            id: nsg.id
          }
        }
      }
    ]
  }
}

resource vmNameWindows_nic 'Microsoft.Network/networkInterfaces@2018-04-01' = {
  name: '${vmNameWindows_var}-nic'
  location: resourceGroup().location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: vmNameWindows_pip.id
          }
          subnet: {
            id: subnetRef
          }
        }
      }
    ]
  }
}

resource vmNameLinux_nic 'Microsoft.Network/networkInterfaces@2018-04-01' = {
  name: '${vmNameLinux_var}-nic'
  location: resourceGroup().location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: vmNameLinux_pip.id
          }
          subnet: {
            id: subnetRef
          }
        }
      }
    ]
  }
}

resource availabilitySet 'Microsoft.Compute/availabilitySets@2018-10-01' = {
  name: availabilitySetName
  location: resourceGroup().location
  properties: {
    platformFaultDomainCount: 2
    platformUpdateDomainCount: 3
  }
  sku: {
    name: 'Aligned'
  }
}

resource vmNameWindows 'Microsoft.Compute/virtualMachines@2018-10-01' = {
  name: vmNameWindows_var
  location: resourceGroup().location
  tags: resourceTags
  properties: {
    availabilitySet: {
      id: availabilitySet.id
    }
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: vmNameWindows_var
      adminUsername: username
      adminPassword: password
    }
    storageProfile: {
      imageReference: {
        publisher: windowsPublisher
        offer: windowsOffer
        version: 'latest'
        sku: windowsSku
      }
      osDisk: {
        name: '${vmNameWindows_var}-osdisk'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
        caching: 'ReadWrite'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: vmNameWindows_nic.id
        }
      ]
    }
  }
}

resource vmNameLinux 'Microsoft.Compute/virtualMachines@2018-10-01' = {
  name: vmNameLinux_var
  location: resourceGroup().location
  tags: resourceTags
  properties: {
    availabilitySet: {
      id: availabilitySet.id
    }
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: vmNameLinux_var
      adminUsername: username
      adminPassword: password
    }
    storageProfile: {
      imageReference: {
        publisher: linuxPublisher
        offer: linuxOffer
        version: 'latest'
        sku: linuxSku
      }
      osDisk: {
        name: '${vmNameLinux_var}-osdisk'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Standard_LRS'
        }
        caching: 'ReadWrite'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: vmNameLinux_nic.id
        }
      ]
    }
  }
}

resource storage 'Microsoft.Storage/storageAccounts@2019-06-01' = {
  name: storageName
  location: resourceGroup().location
  sku: {
    name: storageAccountType
  }
  tags: resourceTags
  kind: 'StorageV2'
  properties: {
    supportsHttpsTrafficOnly: false
  }
}

resource kv 'Microsoft.KeyVault/vaults@2016-10-01' = {
  name: kvName
  location: resourceGroup().location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    accessPolicies: []
    enabledForDeployment: false
    enabledForDiskEncryption: false
    enabledForTemplateDeployment: false
  }
  tags: resourceTags
}

resource sqlServer 'Microsoft.Sql/servers@2015-05-01-preview' = {
  name: sqlServerName
  location: resourceGroup().location
  tags: resourceTags
  properties: {
    administratorLogin: username
    administratorLoginPassword: password
  }
}

resource sqlServerName_AllowAzureIPs 'Microsoft.Sql/servers/firewallrules@2015-05-01-preview' = {
  parent: sqlServer
  name: 'AllowAzureIPs'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

resource sqlServerName_sqlDatabase 'Microsoft.Sql/servers/databases@2017-03-01-preview' = {
  parent: sqlServer
  name: sqlDatabaseName
  location: resourceGroup().location
  tags: resourceTags
  sku: {
    name: 'Basic'
    tier: 'Basic'
    capacity: 5
  }
  properties: {
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    sampleName: 'AdventureWorksLT'
    maxSizeBytes: 104857600
  }
}

output log_analytics_workspace string = workspaceName
output virtual_network string = vNetName
output subnet string = subnetName
output network_security_group string = nsgName
output windows_virtual_machine string = vmNameWindows_var
output linux_virtual_machine string = vmNameLinux_var
output key_vault string = kvName
output sql_database string = sqlDatabaseName
