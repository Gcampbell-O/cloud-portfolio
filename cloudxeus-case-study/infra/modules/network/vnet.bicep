@description('The name of the virtual network.')
param name string

@description('The location of the virtual network, e.g., eastus.')
param location string 

@description('The list of address prefixes for the virtual network.')
param addressPrefixes array 

@description('subnets to create for the virtual network.')
param subnets array



resource vnet 'Microsoft.Network/virtualNetworks@2024-01-01' = {
  name: name
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: addressPrefixes
    }
  }
}

output subnetIds array = [
  for s in subnets :{
    name: s.name
    id:resourceId('Microsoft.Network/virtualNetworks/subnets', name, s.name)
  }
]

output vnetId string = vnet.id
