#!/bin/bash
set -e

# Prompt for the resource group name
read -p "Enter the name of the RESOURCE_GROUP: " RESOURCE_GROUP

# Validate resource group exists
if ! az group show --name "$RESOURCE_GROUP" >/dev/null 2>&1; then
    echo "Error: Resource group '$RESOURCE_GROUP' does not exist."
    echo "Please create it first: az group create --name '$RESOURCE_GROUP' --location westeurope"
    exit 1
fi

# Prompt for admin username
read -p "Enter admin username (default: azureuser): " ADMIN_USERNAME
ADMIN_USERNAME=${ADMIN_USERNAME:-azureuser}

# Read the SSH public key
if [ ! -f ~/.ssh/id_rsa.pub ]; then
    echo "Error: SSH public key not found at ~/.ssh/id_rsa.pub"
    echo "Please generate an SSH key pair first: ssh-keygen -t rsa -b 4096"
    exit 1
fi
SSH_PUBLIC_KEY=$(cat ~/.ssh/id_rsa.pub)

# Retrieve the object ID of the logged-in user (needed for Key Vault RBAC permissions)
PRINCIPAL_ID=$(az ad signed-in-user show --query id -o tsv 2>/dev/null)
if [ -z "$PRINCIPAL_ID" ]; then
    echo "Error: Failed to retrieve user principal ID. Please ensure you are logged in to Azure CLI."
    exit 1
fi

echo "Deploying with the following parameters:"
echo "Resource Group: $RESOURCE_GROUP"
echo "Admin Username: $ADMIN_USERNAME"
echo "Principal ID: $PRINCIPAL_ID"
echo ""

# Execute the deployment command
az deployment group create \
    --resource-group "$RESOURCE_GROUP" \
    --template-file main.bicep \
    --parameters \
        adminUsername="$ADMIN_USERNAME" \
        adminSshPublicKey="$SSH_PUBLIC_KEY" \
        principalIdForKVAccess="$PRINCIPAL_ID"