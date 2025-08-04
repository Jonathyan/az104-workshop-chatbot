using 'main.bicep'

// Environment configuration
param environment = 'dev'
param workloadName = 'chatbot'

// Network configuration
param vnetAddressPrefix = '10.0.0.0/16'

// VM configuration
param adminUsername = 'azureuser'
param vmSku = 'Standard_B2s'

// Scaling configuration
param minInstances = 2
param maxInstances = 5

// Note: adminSshPublicKey and principalIdForKVAccess must be provided at deployment time