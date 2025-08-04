@description('Environment name (dev, test, prod)')
@allowed(['dev', 'test', 'prod'])
param environment string = 'dev'

@description('Workload name for resource naming')
param workloadName string = 'chatbot'

@description('Admin username for VMs')
param adminUsername string = 'azureuser'

@description('SSH public key for VM authentication')
param adminSshPublicKey string

@description('Principal ID for Key Vault access')
param principalIdForKVAccess string

@description('VNet address prefix')
param vnetAddressPrefix string = '10.0.0.0/16'

@description('VM SKU for VMSS instances')
param vmSku string = 'Standard_B2s'

@description('Minimum number of VMSS instances')
@minValue(1)
@maxValue(10)
param minInstances int = 2

@description('Maximum number of VMSS instances')
@minValue(1)
@maxValue(100)
param maxInstances int = 5

var location = resourceGroup().location
var resourcePrefix = '${environment}-${workloadName}'

module foundation 'modules/foundation.bicep' = {
  name: 'foundation'
  params: {
    location: location
    resourcePrefix: resourcePrefix
    vnetAddressPrefix: vnetAddressPrefix
  }
}

module backend 'modules/backend.bicep' = {
  name: 'backend'
  params: {
    location: location
    resourcePrefix: resourcePrefix
    vnetName: foundation.outputs.vnetName
    endpointsSubnetId: foundation.outputs.endpointsSubnetId
    principalIdForKVAccess: principalIdForKVAccess
  }
}

module compute 'modules/compute.bicep' = {
  name: 'compute'
  dependsOn: [
    foundation
    backend
  ]
  params: {
    location: location
    resourcePrefix: resourcePrefix
    vmssSubnetId: foundation.outputs.vmssSubnetId
    appGatewaySubnetId: foundation.outputs.appGatewaySubnetId
    vnetAddressPrefix: vnetAddressPrefix
    keyVaultName: backend.outputs.keyVaultName
    azureOpenAIName: backend.outputs.azureOpenAIName
    adminUsername: adminUsername
    adminSshPublicKey: adminSshPublicKey
    vmSku: vmSku
    minInstances: minInstances
    maxInstances: maxInstances
  }
}

output chatbotAccessUrl string = 'http://${compute.outputs.appGatewayPublicIpAddress}'