@description('Azure region for resources')
param location string

@description('Resource prefix for naming')
param resourcePrefix string

@description('VNet name for DNS zone references')
param vnetName string

@description('Endpoints subnet ID')
param endpointsSubnetId string

@description('Principal ID for Key Vault access')
param principalIdForKVAccess string

var naming = {
  keyVault: '${resourcePrefix}-kv-${uniqueString(resourceGroup().id)}'
  openAI: '${resourcePrefix}-openai-${uniqueString(resourceGroup().id)}'
  kvPrivateEndpoint: '${resourcePrefix}-kv-pe'
  openAIPrivateEndpoint: '${resourcePrefix}-openai-pe'
}

// Azure Key Vault
resource keyVault 'Microsoft.KeyVault/vaults@2021-04-01' = {
  name: naming.keyVault
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
  name: naming.kvPrivateEndpoint
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
  name: naming.openAI
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
  name: naming.openAIPrivateEndpoint
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