#!/bin/bash
set -e

echo "=== Post-Deployment Configuration ==="
echo ""

# Prompt for resource group name
read -p "Enter the RESOURCE_GROUP name: " RESOURCE_GROUP

# Get Key Vault name
KEY_VAULT_NAME=$(az keyvault list --resource-group "$RESOURCE_GROUP" --query "[0].name" -o tsv)
if [ -z "$KEY_VAULT_NAME" ]; then
    echo "Error: Could not find Key Vault in resource group $RESOURCE_GROUP"
    exit 1
fi

# Get OpenAI service name
OPENAI_NAME=$(az cognitiveservices account list --resource-group "$RESOURCE_GROUP" --query "[?kind=='OpenAI'].name" -o tsv)
if [ -z "$OPENAI_NAME" ]; then
    echo "Error: Could not find OpenAI service in resource group $RESOURCE_GROUP"
    exit 1
fi

echo "Found Key Vault: $KEY_VAULT_NAME"
echo "Found OpenAI Service: $OPENAI_NAME"
echo ""

# Step 1: Get OpenAI API key and add to Key Vault
echo "Step 1: Adding OpenAI API key to Key Vault..."
OPENAI_API_KEY=$(az cognitiveservices account keys list --name "$OPENAI_NAME" --resource-group "$RESOURCE_GROUP" --query "key1" -o tsv)

az keyvault secret set \
    --vault-name "$KEY_VAULT_NAME" \
    --name "OpenAI-API-Key" \
    --value "$OPENAI_API_KEY" \
    --output none

echo "✓ OpenAI API key added to Key Vault as 'OpenAI-API-Key'"

# Step 2: Deploy GPT-4 model
echo ""
echo "Step 2: Deploying GPT-4 model..."
az cognitiveservices account deployment create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$OPENAI_NAME" \
    --deployment-name "gpt-4" \
    --model-name "gpt-4" \
    --model-version "0613" \
    --model-format "OpenAI" \
    --sku-capacity 10 \
    --sku-name "Standard" \
    --output none

echo "✓ GPT-4 model deployed successfully"

# Get the chatbot access URL
echo ""
echo "Getting chatbot access URL..."
APP_GATEWAY_IP=$(az network public-ip show \
    --resource-group "$RESOURCE_GROUP" \
    --name "appgateway-pip" \
    --query "ipAddress" -o tsv)

echo ""
echo "=== Deployment Complete ==="
echo "Chatbot URL: http://$APP_GATEWAY_IP"
echo ""
echo "Note: It may take a few minutes for the application to be fully available."
echo "If you encounter issues, check the VMSS instances are running and the custom script extension has completed."