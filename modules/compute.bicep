@description('Azure region for resources')
param location string

@description('Resource prefix for naming')
param resourcePrefix string

@description('VMSS subnet ID')
param vmssSubnetId string

@description('Application Gateway subnet ID')
param appGatewaySubnetId string

@description('VNet address prefix for IP calculations')
param vnetAddressPrefix string

@description('Key Vault name')
param keyVaultName string

@description('Azure OpenAI service name')
param azureOpenAIName string

@description('Admin username for VMs')
param adminUsername string

@description('SSH public key for VM authentication')
param adminSshPublicKey string

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

@description('CPU threshold for scale out')
@minValue(1)
@maxValue(100)
param scaleOutThreshold int = 75

@description('CPU threshold for scale in')
@minValue(1)
@maxValue(100)
param scaleInThreshold int = 25

var naming = {
  appGatewayPip: '${resourcePrefix}-appgw-pip'
  loadBalancer: '${resourcePrefix}-lb'
  vmss: '${resourcePrefix}-vmss'
  appGateway: '${resourcePrefix}-appgw'
  autoscale: '${resourcePrefix}-autoscale'
}

var vmssSubnetPrefix = cidrSubnet(vnetAddressPrefix, 24, 1)
var loadBalancerStaticIP = cidrHost(vmssSubnetPrefix, 4)

// Public IP Address for the Application Gateway
resource appGatewayPublicIp 'Microsoft.Network/publicIPAddresses@2021-02-01' = {
  name: naming.appGatewayPip
  location: location
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

// Internal Load Balancer
resource internalLoadBalancer 'Microsoft.Network/loadBalancers@2021-02-01' = {
  name: naming.loadBalancer
  location: location
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    frontendIPConfigurations: [
      {
        name: 'frontend'
        properties: {
          privateIPAllocationMethod: 'Static'
          privateIPAddress: loadBalancerStaticIP
          subnet: {
            id: vmssSubnetId
          }
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'backend'
      }
    ]
    probes: [
      {
        name: 'health-probe'
        properties: {
          protocol: 'Tcp'
          port: 8080
          intervalInSeconds: 15
          numberOfProbes: 2
        }
      }
    ]
    loadBalancingRules: [
      {
        name: 'lb-rule'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', naming.loadBalancer, 'frontend')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', naming.loadBalancer, 'backend')
          }
          probe: {
            id: resourceId('Microsoft.Network/loadBalancers/probes', naming.loadBalancer, 'health-probe')
          }
          protocol: 'Tcp'
          frontendPort: 8080
          backendPort: 8080
          idleTimeoutInMinutes: 4
          enableFloatingIP: false
        }
      }
    ]
  }
}

// Virtual Machine Scale Set
resource vmss 'Microsoft.Compute/virtualMachineScaleSets@2021-03-01' = {
  name: naming.vmss
  location: location
  zones: ['1', '2', '3']
  sku: {
    name: vmSku
    tier: 'Standard'
    capacity: minInstances
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    upgradePolicy: {
      mode: 'Manual'
    }
    virtualMachineProfile: {
      storageProfile: {
        imageReference: {
          publisher: 'Canonical'
          offer: '0001-com-ubuntu-server-jammy'
          sku: '22_04-lts-gen2'
          version: 'latest'
        }
        osDisk: {
          createOption: 'FromImage'
          caching: 'ReadWrite'
          managedDisk: {
            storageAccountType: 'Premium_LRS'
          }
        }
      }
      osProfile: {
        computerNamePrefix: 'chatbot'
        adminUsername: adminUsername
        linuxConfiguration: {
          disablePasswordAuthentication: true
          ssh: {
            publicKeys: [
              {
                path: '/home/${adminUsername}/.ssh/authorized_keys'
                keyData: adminSshPublicKey
              }
            ]
          }
        }
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
                        id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', internalLoadBalancer.name, 'backend')
                      }
                    ]
                  }
                }
              ]
            }
          }
        ]
      }
      extensionProfile: {
        extensions: [
          {
            name: 'CustomScript'
            properties: {
              publisher: 'Microsoft.Azure.Extensions'
              type: 'CustomScript'
              typeHandlerVersion: '2.1'
              autoUpgradeMinorVersion: true
              settings: {
                script: base64('''#!/bin/bash
apt-get update
apt-get install -y python3 python3-pip
pip3 install streamlit azure-keyvault-secrets azure-identity openai

# Create app directory
mkdir -p /opt/chatbot
cd /opt/chatbot

# Create the Streamlit app
cat > app.py << 'EOF'
import streamlit as st
import openai
from azure.keyvault.secrets import SecretClient
from azure.identity import DefaultAzureCredential

st.title("Enterprise Chatbot")

# Initialize Azure Key Vault client
credential = DefaultAzureCredential()
vault_url = f"https://${keyVaultName}.vault.azure.net/"
client = SecretClient(vault_url=vault_url, credential=credential)

try:
    # Get OpenAI API key from Key Vault
    api_key = client.get_secret("OpenAI-API-Key").value
    openai.api_key = api_key
    
    # Chat interface
    if "messages" not in st.session_state:
        st.session_state.messages = []
    
    for message in st.session_state.messages:
        with st.chat_message(message["role"]):
            st.markdown(message["content"])
    
    if prompt := st.chat_input("What is your question?"):
        st.session_state.messages.append({"role": "user", "content": prompt})
        with st.chat_message("user"):
            st.markdown(prompt)
        
        with st.chat_message("assistant"):
            response = openai.ChatCompletion.create(
                model="gpt-4",
                messages=st.session_state.messages
            )
            reply = response.choices[0].message.content
            st.markdown(reply)
            st.session_state.messages.append({"role": "assistant", "content": reply})

except Exception as e:
    st.error(f"Error: {str(e)}")
    st.info("Please ensure OpenAI API key is configured in Key Vault and a model is deployed.")
EOF

# Create systemd service
cat > /etc/systemd/system/chatbot.service << 'EOF'
[Unit]
Description=Chatbot Streamlit App
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/chatbot
ExecStart=/usr/local/bin/streamlit run app.py --server.port=8080 --server.address=0.0.0.0
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Enable and start the service
systemctl daemon-reload
systemctl enable chatbot.service
systemctl start chatbot.service
''')
              }
            }
          }
        ]
      }
    }
  }
}

// Autoscaling settings
resource autoscaleSettings 'Microsoft.Insights/autoscalesettings@2021-05-01-preview' = {
  name: naming.autoscale
  location: location
  properties: {
    profiles: [
      {
        name: 'default'
        capacity: {
          minimum: string(minInstances)
          maximum: string(maxInstances)
          default: string(minInstances)
        }
        rules: [
          {
            metricTrigger: {
              metricName: 'Percentage CPU'
              metricNamespace: 'Microsoft.Compute/virtualMachineScaleSets'
              metricResourceUri: vmss.id
              timeGrain: 'PT1M'
              statistic: 'Average'
              timeWindow: 'PT5M'
              timeAggregation: 'Average'
              operator: 'GreaterThan'
              threshold: scaleOutThreshold
            }
            scaleAction: {
              direction: 'Increase'
              type: 'ChangeCount'
              value: '1'
              cooldown: 'PT5M'
            }
          }
          {
            metricTrigger: {
              metricName: 'Percentage CPU'
              metricNamespace: 'Microsoft.Compute/virtualMachineScaleSets'
              metricResourceUri: vmss.id
              timeGrain: 'PT1M'
              statistic: 'Average'
              timeWindow: 'PT10M'
              timeAggregation: 'Average'
              operator: 'LessThan'
              threshold: scaleInThreshold
            }
            scaleAction: {
              direction: 'Decrease'
              type: 'ChangeCount'
              value: '1'
              cooldown: 'PT10M'
            }
          }
        ]
      }
    ]
    enabled: true
    targetResourceUri: vmss.id
  }
}

// Key Vault RBAC role assignment
resource keyVaultSecretsUser 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(keyVaultName, vmss.id, 'Key Vault Secrets User')
  scope: resourceId('Microsoft.KeyVault/vaults', keyVaultName)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6')
    principalId: vmss.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// Application Gateway
resource appGateway 'Microsoft.Network/applicationGateways@2021-02-01' = {
  name: naming.appGateway
  location: location
  properties: {
    sku: {
      name: 'WAF_v2'
      tier: 'WAF_v2'
      capacity: 2
    }
    webApplicationFirewallConfiguration: {
      enabled: true
      firewallMode: 'Prevention'
      ruleSetType: 'OWASP'
      ruleSetVersion: '3.2'
    }
    gatewayIPConfigurations: [
      {
        name: 'appGatewayIpConfig'
        properties: {
          subnet: {
            id: appGatewaySubnetId
          }
        }
      }
    ]
    frontendIPConfigurations: [
      {
        name: 'appGwPublicFrontendIp'
        properties: {
          publicIPAddress: {
            id: appGatewayPublicIp.id
          }
        }
      }
    ]
    frontendPorts: [
      {
        name: 'port_80'
        properties: {
          port: 80
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'backend-pool'
        properties: {
          backendAddresses: [
            {
              ipAddress: loadBalancerStaticIP
            }
          ]
        }
      }
    ]
    backendHttpSettingsCollection: [
      {
        name: 'http-settings'
        properties: {
          port: 8080
          protocol: 'Http'
          cookieBasedAffinity: 'Disabled'
          pickHostNameFromBackendAddress: false
          requestTimeout: 20
        }
      }
    ]
    httpListeners: [
      {
        name: 'http-listener'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', naming.appGateway, 'appGwPublicFrontendIp')
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', naming.appGateway, 'port_80')
          }
          protocol: 'Http'
        }
      }
    ]
    requestRoutingRules: [
      {
        name: 'routing-rule'
        properties: {
          ruleType: 'Basic'
          httpListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', naming.appGateway, 'http-listener')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', naming.appGateway, 'backend-pool')
          }
          backendHttpSettings: {
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', naming.appGateway, 'http-settings')
          }
        }
      }
    ]
  }
  dependsOn: [
    internalLoadBalancer
  ]
}

output appGatewayPublicIpAddress string = appGatewayPublicIp.properties.ipAddress