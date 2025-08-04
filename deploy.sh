#!/bin/bash

# Prompt for the resource group name
read -p "Enter the name of the RESOURCE_GROUP: " RESOURCE_GROUP

# Read the SSH public key
SSH_PUBLIC_KEY=$(cat ~/.ssh/id_rsa.pub)

# Retrieve the object ID of the logged-in user
PRINCIPAL_ID=$(az ad signed-in-user show --query id -o tsv)

# Execute the deployment command
az deployment group create --resource-group $RESOURCE_GROUP --template-file main.bicep --parameters adminSshPublicKey="$SSH_PUBLIC_KEY" principalIdForKVAccess="$PRINCIPAL_ID"