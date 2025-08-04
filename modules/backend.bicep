param location string
param vnetName string
param endpointsSubnetId string
param principalIdForKVAccess string

// Azure Key Vault
resource keyVault 'Microsoft.KeyVault/vaults@2021-04-01' = {
  name: '${uniqueString(resourceGroup().id)}-kv'
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    accessPolicies: [
      {
        tenantId: subscription().tenantId
        objectId: principalIdForKVAccess
        permissions: {
          secrets: [
            'get'
            'list'
          ]
        }
      }
    ]
    publicNetworkAccess: 'Disabled'
    enableRbacAuthorization: true
  }
}

// Private Endpoint for Key Vault
resource keyVaultPrivateEndpoint 'Microsoft.Network/privateEndpoints@2021-02-01' = {
  name: '${keyVault.name}-privateEndpoint'
  location: location
  properties: {
    subnet: {
      id: endpointsSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'keyVaultConnection'
        properties: {
          privateLinkServiceId: keyVault.id
          groupIds: [
            'vault'
          ]
        }
      }
    ]
  }
}

// Azure OpenAI Service
resource openAIService 'Microsoft.CognitiveServices/accounts@2021-04-30' = {
  name: '${uniqueString(resourceGroup().id)}-openai'
  location: location
  kind: 'OpenAI'
  sku: {
    name: 'S0'
    tier: 'S0'
  }
  properties: {
    publicNetworkAccess: 'Disabled'
  }
}

// Private Endpoint for OpenAI
resource openAIPrivateEndpoint 'Microsoft.Network/privateEndpoints@2021-02-01' = {
  name: '${openAIService.name}-privateEndpoint'
  location: location
  properties: {
    subnet: {
      id: endpointsSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: 'openAIConnection'
        properties: {
          privateLinkServiceId: openAIService.id
          groupIds: [
            'openai'
          ]
        }
      }
    ]
  }
}

output keyVaultName string = keyVault.name
output azureOpenAIName string = openAIService.name