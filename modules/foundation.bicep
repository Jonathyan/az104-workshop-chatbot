@description('Azure region for resources')
param location string

@description('Resource prefix for naming')
param resourcePrefix string

@description('VNet address prefix')
param vnetAddressPrefix string = '10.0.0.0/16'

@description('Log Analytics retention in days')
@minValue(30)
@maxValue(730)
param logRetentionDays int = 30

var naming = {
  vnet: '${resourcePrefix}-vnet'
  nsg: '${resourcePrefix}-nsg'
  law: '${resourcePrefix}-law'
  bastion: '${resourcePrefix}-bastion'
  bastionPip: '${resourcePrefix}-bastion-pip'
}

var subnetConfig = {
  appgateway: {
    name: 'snet-appgateway'
    addressPrefix: cidrSubnet(vnetAddressPrefix, 24, 0)
  }
  vmss: {
    name: 'snet-vmss'
    addressPrefix: cidrSubnet(vnetAddressPrefix, 24, 1)
  }
  endpoints: {
    name: 'snet-endpoints'
    addressPrefix: cidrSubnet(vnetAddressPrefix, 24, 2)
  }
  bastion: {
    name: 'AzureBastionSubnet'
    addressPrefix: cidrSubnet(vnetAddressPrefix, 24, 3)
  }
}

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2021-06-01' = {
  name: naming.law
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: logRetentionDays
  }
}

resource nsg 'Microsoft.Network/networkSecurityGroups@2021-02-01' = {
  name: naming.nsg
  location: location
  properties: {
    securityRules: [
      {
        name: 'Allow-LoadBalancer'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: 'AzureLoadBalancer'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '8080'
        }
      }
      {
        name: 'Allow-SSH'
        properties: {
          priority: 200
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: subnetConfig.bastion.addressPrefix
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '22'
        }
      }
    ]
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2021-02-01' = {
  name: naming.vnet
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: subnetConfig.appgateway.name
        properties: {
          addressPrefix: subnetConfig.appgateway.addressPrefix
        }
      }
      {
        name: subnetConfig.vmss.name
        properties: {
          addressPrefix: subnetConfig.vmss.addressPrefix
          networkSecurityGroup: {
            id: nsg.id
          }
        }
      }
      {
        name: subnetConfig.endpoints.name
        properties: {
          addressPrefix: subnetConfig.endpoints.addressPrefix
        }
      }
      {
        name: subnetConfig.bastion.name
        properties: {
          addressPrefix: subnetConfig.bastion.addressPrefix
        }
      }
    ]
  }
}

resource privateDnsZone1 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.openai.azure.com'
  location: 'global'
}

resource privateDnsZone2 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.vaultcore.azure.net'
  location: 'global'
}

resource dnsZoneLink1 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: privateDnsZone1
  name: '${naming.vnet}-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnet.id
    }
  }
}

resource dnsZoneLink2 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: privateDnsZone2
  name: '${naming.vnet}-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnet.id
    }
  }
}

resource bastionPublicIp 'Microsoft.Network/publicIPAddresses@2021-02-01' = {
  name: naming.bastionPip
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource azureBastion 'Microsoft.Network/bastionHosts@2021-02-01' = {
  name: naming.bastion
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'bastionIpConfig'
        properties: {
          subnet: {
            id: '${vnet.id}/subnets/${subnetConfig.bastion.name}'
          }
          publicIPAddress: {
            id: bastionPublicIp.id
          }
        }
      }
    ]
  }
}

output vnetId string = vnet.id
output vnetName string = vnet.name
output appGatewaySubnetId string = '${vnet.id}/subnets/${subnetConfig.appgateway.name}'
output vmssSubnetId string = '${vnet.id}/subnets/${subnetConfig.vmss.name}'
output endpointsSubnetId string = '${vnet.id}/subnets/${subnetConfig.endpoints.name}'
output logAnalyticsWorkspaceId string = logAnalytics.id