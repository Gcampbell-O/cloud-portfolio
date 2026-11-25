param lbBackendPoolId string

@description('URI to the script file (e.g., SAS URL from storage)')
param scriptUri string


@description('command to execute on the VM after the file is downloaded')
param scriptCommand string = 'powershell -ExecutionPolicy Bypass -File install-iis.ps1'

@description('azure region; e.g., eastus')
param location string

@description('The size of the virtual machine, e.g., Standard_D2s_v3.')
param vmSize string

@description('admin username for the virtual machine.')
param adminUsername string = 'azureuser'

// checkov:skip=CKV_AZURE_131: False positive. adminPassword is @secure() with no default value
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
          loadBalancerBackendAddressPools:[
            {
              id: lbBackendPoolId
            }
          ]
        }
      }
    ]
  }
}]

resource vms 'Microsoft.Compute/virtualMachines@2023-09-01' = [ for (vmName,i) in vmNames:{
  // checkov:skip=CKV_AZURE_92: False positive. osDisk sets managedDisk explicitly (Premium_LRS)
  // checkov:skip=CKV_AZURE_45: False positive. No customData; the script runs through the Custom Script Extension with protectedSettings
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
      windowsConfiguration: {
        enableAutomaticUpdates: true
        patchSettings: {
          patchMode: 'AutomaticByOS'
        }
      }
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftWindowsServer'
        offer: 'WindowsServer'
        sku: '2022-datacenter-azure-edition'
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

resource cse 'Microsoft.Compute/virtualMachines/extensions@2023-09-01' = [for (vmName, i) in vmNames: {
  parent: vms[i]
  name: 'installIIS'
  location: location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    // fileUris holds a SAS token, so it goes in protectedSettings (encrypted, not visible to VM readers)
    protectedSettings: {
      fileUris: [
        scriptUri
      ]
      commandToExecute: scriptCommand
    }
  }
}]
