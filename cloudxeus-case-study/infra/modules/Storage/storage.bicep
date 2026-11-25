@description('The name of the storage account(3-24 lowercase letters and numbers).')
param name string

@description('The location of the storage account, e.g., eastus.')
param location string


resource sa 'Microsoft.Storage/storageAccounts@2024-01-01' = {
  // checkov:skip=CKV_AZURE_59: Accepted risk. VMs download the IIS script from this account; public network access stays until a private endpoint is added
  // checkov:skip=CKV_AZURE_36: Trusted-services bypass only applies once network rules exist (see CKV_AZURE_59)
  name: name
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2024-01-01' = {
  parent: sa
  name: 'default'
}

resource scriptsContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2024-01-01' = {
  // checkov:skip=CKV_AZURE_34: False positive. publicAccess is explicitly 'None'
  parent: blobService
  name: 'scripts'
  properties: {
    publicAccess: 'None'
  }
}

output name string = sa.name
