
param name string
param location string
@description('Array of security rules to be applied to the NSG.')
param rules array

@description('subnets to attach the NSG to.')
param attachments array

resource nsg 'Microsoft.Network/networkSecurityGroups@2024-01-01' = {
  name: name
  location: location
  properties: {
    securityRules: [
    for r in rules: r 
    ]
  }
}

@batchSize(1)
resource subnetAssoc 'Microsoft.Network/virtualNetworks/subnets@2024-01-01' = [
  for a in attachments: {
    name: '${a.vnetName}/${a.subnetName}'
    properties: {
      addressPrefix: a.addressPrefix
      networkSecurityGroup:{
        id: nsg.id
      }
    }
  
  }

]
