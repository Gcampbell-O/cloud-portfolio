@description('Local Vnet name (in this RG/subscription)')
param localVnetName string

param localVnetId string

@description('Remote Vnet name (in this RG/subscription)')
param remoteVnetName string

param remoteVnetid string

resource localToRemote 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2025-09-01' = {
name:'${localVnetName}/peer-${localVnetName}-to-${remoteVnetName}'
properties: {
  remoteVirtualNetwork: {id:remoteVnetid}
  allowVirtualNetworkAccess: true
  allowForwardedTraffic: false
  allowGatewayTransit: false
  useRemoteGateways: false
}

}

resource RemoteTolocal 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2025-09-01' = {
name:'${remoteVnetName}/peer-${remoteVnetName}-to-${localVnetName}'
properties: {
  remoteVirtualNetwork: {id:localVnetId}
  allowVirtualNetworkAccess: true
  allowForwardedTraffic: false
  allowGatewayTransit: false
  useRemoteGateways: false
}

}
