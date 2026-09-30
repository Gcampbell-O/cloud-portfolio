param location string
param vnet object
param storageAccountName string
param nsg object


@secure()
param winWebAdminPassword string
param bastion object
param winWebConfig object = {
  baseName: 'winweb'
  vmSize: 'Standard_B2s'
  count: 1
  adminUsername: 'azureadmin'
}
param linuxWebConfig object
@secure()
param linuxWebAdminPassword string
param testvnet object
param lbName string

var vnetNsgAttachments = map(filter(vnet.subnets, s => s.name != 'AzureBastionSubnet'), s => {
  vnetName: vnet.name
  subnetName: s.name
  addressPrefix: s.addressPrefix
})

var nsgAttachments = concat(vnetNsgAttachments, [
  {
    vnetName: testvnet.name
    subnetName: testvnet.subnets[0].name
    addressPrefix: testvnet.subnets[0].addressPrefix
  }
])

var bastionSubnetAttachment = map(filter(vnet.subnets, s => s.name == 'AzureBastionSubnet'), s => {
  vnetName: vnet.name
  subnetName: s.name
  addressPrefix: s.addressPrefix
})

var bastionNsgRules = [
  {
    name: 'AllowHttpsInbound'
    properties: {
      description: 'Allow HTTPS inbound from Internet to Bastion'
      priority: 100
      direction: 'Inbound'
      access: 'Allow'
      protocol: 'Tcp'
      sourcePortRange: '*'
      destinationPortRange: '443'
      sourceAddressPrefix: 'Internet'
      destinationAddressPrefix: '*'
    }
  }
  {
    name: 'AllowGatewayManagerInbound'
    properties: {
      description: 'Allow Bastion control plane'
      priority: 110
      direction: 'Inbound'
      access: 'Allow'
      protocol: 'Tcp'
      sourcePortRange: '*'
      destinationPortRange: '443'
      sourceAddressPrefix: 'GatewayManager'
      destinationAddressPrefix: '*'
    }
  }
  {
    name: 'AllowAzureLoadBalancerInbound'
    properties: {
      description: 'Allow Azure Load Balancer health probes'
      priority: 120
      direction: 'Inbound'
      access: 'Allow'
      protocol: 'Tcp'
      sourcePortRange: '*'
      destinationPortRange: '443'
      sourceAddressPrefix: 'AzureLoadBalancer'
      destinationAddressPrefix: '*'
    }
  }
  {
    name: 'AllowBastionHostCommunicationInbound'
    properties: {
      description: 'Allow Bastion instance-to-instance communication'
      priority: 130
      direction: 'Inbound'
      access: 'Allow'
      protocol: '*'
      sourcePortRange: '*'
      destinationPortRanges: [
        '8080'
        '5701'
      ]
      sourceAddressPrefix: 'VirtualNetwork'
      destinationAddressPrefix: 'VirtualNetwork'
    }
  }
  {
    name: 'AllowSshRdpOutbound'
    properties: {
      description: 'Allow Bastion to reach target VMs via RDP/SSH'
      priority: 100
      direction: 'Outbound'
      access: 'Allow'
      protocol: '*'
      sourcePortRange: '*'
      destinationPortRanges: [
        '22'
        '3389'
      ]
      sourceAddressPrefix: '*'
      destinationAddressPrefix: 'VirtualNetwork'
    }
  }
  {
    name: 'AllowAzureCloudOutbound'
    properties: {
      description: 'Allow Bastion control plane outbound'
      priority: 110
      direction: 'Outbound'
      access: 'Allow'
      protocol: 'Tcp'
      sourcePortRange: '*'
      destinationPortRange: '443'
      sourceAddressPrefix: '*'
      destinationAddressPrefix: 'AzureCloud'
    }
  }
  {
    name: 'AllowBastionHostCommunicationOutbound'
    properties: {
      description: 'Allow Bastion instance-to-instance communication'
      priority: 120
      direction: 'Outbound'
      access: 'Allow'
      protocol: '*'
      sourcePortRange: '*'
      destinationPortRanges: [
        '8080'
        '5701'
      ]
      sourceAddressPrefix: 'VirtualNetwork'
      destinationAddressPrefix: 'VirtualNetwork'
    }
  }
  {
    name: 'AllowGetSessionInformationOutbound'
    properties: {
      description: 'Allow Bastion certificate/session validation'
      priority: 130
      direction: 'Outbound'
      access: 'Allow'
      protocol: 'Tcp'
      sourcePortRange: '*'
      destinationPortRange: '80'
      sourceAddressPrefix: '*'
      destinationAddressPrefix: 'Internet'
    }
  }
]

module devnet 'infra/modules/network/vnet.bicep' = {
  name: 'dev-network'
  params: {
    name: vnet.name
    location: location
    addressPrefixes: vnet.addressPrefixes
    subnets: vnet.subnets
  }
}

module storage 'infra/modules/Storage/storage.bicep' = {
  name: 'strgdevxeus'
  params: {
    name: storageAccountName
    location: location
  }
}

module sharednsg 'infra/modules/Security/nsg.bicep' = {
  name: 'nsg-dev-shared-eus'
  params: {
    name: nsg.name
    location: location
    rules: nsg.rules
    attachments: nsgAttachments
  }
  dependsOn:[devnet, testnet]
}

module winWeb 'infra/modules/compute/windowsVM.bicep' = {
  name: 'win-web-dev'
  params: {
    location: location
    baseName: winWebConfig.baseName
    vmSize: winWebConfig.vmSize
    count: winWebConfig.count
    adminUsername: winWebConfig.adminUsername
    subnetId: devnet.outputs.subnetIds[0].id
    adminPassword: winWebAdminPassword
    scriptUri: winWebConfig.scriptUri
    lbBackendPoolId:ilb.outputs.backendPoolId
  }

  dependsOn:[sharednsg, storage]
}

module ilb 'infra/modules/network/internalLB.bicep' ={
  name: 'ilb'
  params: {
    location:location
    lbName:lbName
    subnetId:devnet.outputs.subnetIds[0].id

  }

  dependsOn:[sharednsg]
}


module bastionNsg 'infra/modules/Security/nsg.bicep' = {
  name: 'nsg-bastion-eus'
  params: {
    name: 'nsg-bastion-eus'
    location: location
    rules: bastionNsgRules
    attachments: bastionSubnetAttachment
  }
  dependsOn:[devnet]
}

module basPip 'infra/modules/network/PubIP.bicep' = {
   name: 'bastion-ip'
   params: {
    name: bastion.?pipName ?? 'bastion-ip'
    location: location
    sku: bastion.?sku ?? 'Standard'
    allocation: bastion.?allocation ?? 'Static'
   }

}

module bastionhost 'infra/modules/Security/bastion.bicep'= {
  name: 'bastion'
  params:{
    name:bastion.name
    location:location
    subnetId:devnet.outputs.subnetIds[2].id
    publicIPId:basPip.outputs.id
  }
  dependsOn:[bastionNsg]
}

module testnet 'infra/modules/network/vnet.bicep' ={
    name: 'test-network'
  params: {
    name:testvnet.name
    location: location
    addressPrefixes:testvnet.addressPrefixes
    subnets:testvnet.subnets
  }
}

module linuxVm 'infra/modules/compute/linuxVM.bicep' = {
  name: 'linux-web-dev'
  params: {
    location: location
    baseName: linuxWebConfig.baseName
    vmSize: linuxWebConfig.vmSize
    subnetId: testnet.outputs.subnetIds[0].id
    count: linuxWebConfig.count
    adminUsername: linuxWebConfig.adminUsername
    adminPassword: linuxWebAdminPassword
  }
  dependsOn:[sharednsg]
}

module vnetpeering 'infra/modules/network/vnetpeering.bicep' = {
  name: 'vnet-peering-dev-test'
  params: {
    localVnetName: vnet.name
    remoteVnetName: testvnet.name
    localVnetId: devnet.outputs.vnetId
    remoteVnetid: testnet.outputs.vnetId
  }
}
