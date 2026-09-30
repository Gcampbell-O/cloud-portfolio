
@description('azure region; e.g., eastus')
param location string

@description('The size of the virtual machine, e.g., Standard_D2s_v3.')
param vmSize string

@description('admin username for the virtual machine.')
param adminUsername string = 'linuxadmin'

@secure()
@description('admin password for the virtual machine.')
param adminPassword string

param baseName string

@description('Target subnet resource ID')
param subnetId string

@description('How many VMs to create')
param count int

var indexes = [for i in range(1,count):i]
var vmNames = [for i in indexes: 'vm-${baseName}-${i}']
var nicNames= [for i in indexes: 'nic-${baseName}-${i}']

resource nics 'Microsoft.Network/networkInterfaces@2024-01-01' = [for (nicName,i) in nicNames:{
  name: nicName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: subnetId
          }
    
        }
      }
    ]
  }
}]

resource vms 'Microsoft.Compute/virtualMachines@2023-09-01' = [ for (vmName,i) in vmNames:{
  name: vmName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: adminPassword
      linuxConfiguration: {
        disablePasswordAuthentication:false
    }
  }

    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: 'ubuntu-24_04-lts'
        sku: 'server'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nics[i].id
          properties: {
            primary: true
          }
        }
      ]
    }
  }
}]
