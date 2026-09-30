@description('PubliC IP name')
param name string

param location string

@description('SKU: Standard required for Bastion')
param sku string = 'Standard'

param allocation string = 'Static'

resource pubip 'Microsoft.Network/publicIPAddresses@2024-01-01' = {
  name: name
  location: location
  properties: {
    publicIPAllocationMethod:allocation
  }
  sku: {
    name: sku
  }
}
output id string =pubip.id
