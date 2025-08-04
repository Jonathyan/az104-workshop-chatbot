param location string
param vmssSubnetId string
param appGatewaySubnetId string
param keyVaultName string
param azureOpenAIName string
param adminUsername string
param adminSshPublicKey string

// Public IP Address for the Application Gateway
resource appGatewayPublicIp 'Microsoft.Network/publicIPAddresses@2021-02-01' = {
  name: 'appGatewayPublicIp'
  location: location
  sku: {
    name: 'Standard'
    tier: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

// Internal Load Balancer
resource internalLoadBalancer 'Microsoft.Network/loadBalancers@2021-02-01' = {
  name: 'internalLoadBalancer'
  location: location
  sku: {
    name: 'Standard'
    tier: 'Standard'
  }
  properties: {
    frontendIPConfigurations: [
      {
        name: 'frontendConfig'
        properties: {
          privateIPAllocationMethod: 'Static'
          privateIPAddress: '10.0.1.4' // Example static IP
          subnet: {
            id: vmssSubnetId
          }
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'backendPool'
        properties: {}
      }
    ]
    loadBalancingRules: [
      {
        name: 'loadBalancingRule'
        properties: {
          frontendIPConfiguration: {
            id: internalLoadBalancer.frontendIPConfigurations[0].id
          }
          backendAddressPool: {
            id: internalLoadBalancer.backendAddressPools[0].id
          }
          protocol: 'Tcp'
          frontendPort: 8080
          backendPort: 8080
          idleTimeoutInMinutes: 4
          enableFloatingIP: false
        }
      }
    ]
    healthProbes: [
      {
        name: 'healthProbe'
        properties: {
          protocol: 'Tcp'
          port: 8080
          intervalInSeconds: 15
          numberOfProbes: 2
        }
      }
    ]
  }
}

// Virtual Machine Scale Set (VMSS)
resource vmScaleSet 'Microsoft.Compute/virtualMachineScaleSets@2021-03-01' = {
  name: 'chatbotVMSS'
  location: location
  sku: {
    name: 'Standard_B2s'
    tier: 'Standard'
    capacity: 2
  }
  properties: {
    upgradePolicy: {
      mode: 'Manual'
    }
    virtualMachineProfile: {
      storageProfile: {
        imageReference: {
          publisher: 'Canonical'
          offer: 'UbuntuServer'
          sku: '18.04-LTS'
          version: 'latest'
        }
      }
      osProfile: {
        computerNamePrefix: 'chatbot'
        adminUsername: adminUsername
        adminPassword: 'YourPasswordHere' // Use a secure method to handle passwords
        customData: 'echo "Hello World"'
      }
      networkProfile: {
        networkInterfaceConfigurations: [
          {
            name: 'nic'
            properties: {
              primary: true
              ipConfigurations: [
                {
                  name: 'ipconfig'
                  properties: {
                    subnet: {
                      id: vmssSubnetId
                    }
                    loadBalancerBackendAddressPools: [
                      {
                        id: internalLoadBalancer.backendAddressPools[0].id
                      }
                    ]
                  }
                }
              ]
            }
          }
        ]
      }
      identity: {
        type: 'SystemAssigned'
      }
      extensionProfile: {
        extensions: [
          {
            name: 'customScript'
            properties: {
              publisher: 'Microsoft.Azure.Extensions'
              type: 'CustomScript'
              settings: {
                scriptUri: 'https://path-to-your-script.sh'
              }
            }
          }
        ]
      }
    }
  }
}

// Key Vault Access Policy
resource keyVaultAccessPolicy 'Microsoft.KeyVault/vaults/accessPolicies@2021-04-01' = {
  name: keyVaultName
  properties: {
    accessPolicies: [
      {
        tenantId: subscription().tenantId
        objectId: vmScaleSet.identity.principalId
        permissions: {
          secrets: [
            'get'
            'list'
          ]
        }
      }
    ]
  }
}

// Application Gateway
resource appGateway 'Microsoft.Network/applicationGateways@2021-02-01' = {
  name: 'chatbotAppGateway'
  location: location
  sku: {
    name: 'Standard_v2'
    tier: 'Standard_v2'
    capacity: 2
  }
  properties: {
    frontendIPConfigurations: [
      {
        name: 'frontendIpConfig'
        properties: {
          publicIPAddress: {
            id: appGatewayPublicIp.id
          }
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'backendPool'
        properties: {
          backendAddresses: [
            {
              fqdn: 'internalLoadBalancer'
            }
          ]
        }
      }
    ]
    httpListeners: [
      {
        name: 'httpListener'
        properties: {
          frontendIPConfiguration: {
            id: appGateway.frontendIPConfigurations[0].id
          }
          frontendPort: {
            id: appGateway.frontendPorts[0].id
          }
          protocol: 'Http'
        }
      }
    ]
    requestRoutingRules: [
      {
        name: 'routingRule'
        properties: {
          ruleType: 'Basic'
          httpListener: {
            id: appGateway.httpListeners[0].id
          }
          backendAddressPool: {
            id: appGateway.backendAddressPools[0].id
          }
          backendHttpSettings: {
            id: appGateway.backendHttpSettingsCollection[0].id
          }
        }
      }
    ]
  }
}

// Outputs
output appGatewayPublicIpAddress string = appGatewayPublicIp.properties.ipAddress