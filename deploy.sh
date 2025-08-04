#!/bin/bash
set -e

# Ask if user wants to create new or use existing resource group
echo "Do you want to:"
echo "1) Create a new resource group"
echo "2) Use an existing resource group"
read -p "Enter your choice (1 or 2): " RG_CHOICE

if [ "$RG_CHOICE" = "1" ]; then
    read -p "Enter name for new resource group: " RESOURCE_GROUP
    read -p "Enter location (default: westeurope): " LOCATION
    LOCATION=${LOCATION:-westeurope}
    
    echo "Creating resource group '$RESOURCE_GROUP' in '$LOCATION'..."
    az group create --name "$RESOURCE_GROUP" --location "$LOCATION"
else
    read -p "Enter existing resource group name: " RESOURCE_GROUP
    
    if ! az group show --name "$RESOURCE_GROUP" >/dev/null 2>&1; then
        echo "Error: Resource group '$RESOURCE_GROUP' does not exist."
        exit 1
    fi
fi

# Prompt for environment and configuration
read -p "Enter environment (dev/test/prod, default: dev): " ENVIRONMENT
ENVIRONMENT=${ENVIRONMENT:-dev}

read -p "Enter admin username (default: azureuser): " ADMIN_USERNAME
ADMIN_USERNAME=${ADMIN_USERNAME:-azureuser}

read -p "Enter VM SKU (default: Standard_B2s): " VM_SKU
VM_SKU=${VM_SKU:-Standard_B2s}

# SSH Key handling
read -p "Enter SSH public key path (default: ~/.ssh/id_rsa.pub): " SSH_KEY_PATH
SSH_KEY_PATH=${SSH_KEY_PATH:-~/.ssh/id_rsa.pub}

# Expand tilde and validate
SSH_KEY_PATH=$(eval echo "$SSH_KEY_PATH")
if [ ! -f "$SSH_KEY_PATH" ]; then
    echo "Error: SSH public key not found at $SSH_KEY_PATH"
    echo "Please generate an SSH key pair first: ssh-keygen -t rsa -b 4096"
    exit 1
fi
SSH_PUBLIC_KEY=$(cat "$SSH_KEY_PATH")
echo "Using SSH key: $SSH_KEY_PATH"

# Retrieve the object ID of the logged-in user (needed for Key Vault RBAC permissions)
PRINCIPAL_ID=$(az ad signed-in-user show --query id -o tsv 2>/dev/null)
if [ -z "$PRINCIPAL_ID" ]; then
    echo "Error: Failed to retrieve user principal ID. Please ensure you are logged in to Azure CLI."
    exit 1
fi

echo "Deploying with the following parameters:"
echo "Resource Group: $RESOURCE_GROUP"
echo "Environment: $ENVIRONMENT"
echo "Admin Username: $ADMIN_USERNAME"
echo "VM SKU: $VM_SKU"
echo "Principal ID: $PRINCIPAL_ID"
echo ""

# Execute the deployment command
az deployment group create \
    --resource-group "$RESOURCE_GROUP" \
    --template-file main.bicep \
    --parameters main.bicepparam \
    --parameters \
        environment="$ENVIRONMENT" \
        adminUsername="$ADMIN_USERNAME" \
        vmSku="$VM_SKU" \
        adminSshPublicKey="$SSH_PUBLIC_KEY" \
        principalIdForKVAccess="$PRINCIPAL_ID"