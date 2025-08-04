param adminUsername string
param adminSshPublicKey string
param principalIdForKVAccess string = az ad signed-in-user show --query id -o tsv

var location = resourceGroup().location

module foundation 'modules/foundation.bicep' = {
  name: 'foundation'
  params: {
    location: location
    vnetAddressPrefix: '10.0.0.0/16'
  }
}

module backend 'modules/backend.bicep' = {
  name: 'backend'
  params: {
    location: location
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
    vmssSubnetId: foundation.outputs.vmssSubnetId
    appGatewaySubnetId: foundation.outputs.appGatewaySubnetId
    keyVaultName: backend.outputs.keyVaultName
    azureOpenAIName: backend.outputs.azureOpenAIName
    adminUsername: adminUsername
    adminSshPublicKey: adminSshPublicKey
  }
}

output chatbotAccessUrl string = 'http://${compute.outputs.appGatewayPublicIpAddress}'