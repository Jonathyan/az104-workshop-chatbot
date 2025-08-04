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
    publicNetworkAccess: 'Disabled'
    enableRbacAuthorization: true
  }
}

// Private Endpoint for Key Vault
resource keyVaultPrivateEndpoint 'Microsoft.Network/privateEndpoints@2021-02-01' = {
  name: '${keyVault.name}-pe'
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

resource keyVaultDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2021-02-01' = {
  parent: keyVaultPrivateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatelink-vaultcore-azure-net'
        properties: {
          privateDnsZoneId: resourceId('Microsoft.Network/privateDnsZones', 'privatelink.vaultcore.azure.net')
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
  name: '${openAIService.name}-pe'
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
            'account'
          ]
        }
      }
    ]
  }
}

resource openAIDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2021-02-01' = {
  parent: openAIPrivateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatelink-openai-azure-com'
        properties: {
          privateDnsZoneId: resourceId('Microsoft.Network/privateDnsZones', 'privatelink.openai.azure.com')
        }
      }
    ]
  }
}

output keyVaultName string = keyVault.name
output azureOpenAIName string = openAIService.name