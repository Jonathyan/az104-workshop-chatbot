# Enterprise chatbot bouwen met Bicep

Ter voorbereiding van het AZ-104 examen bouwen we een chatbot waarbij je in een geisoleerde omgeving vragen kunt stellen aan je 'eigen' ChatGPT. Dit document beschrijft de technische vereisten om dit te bouwen met een veilige, schaalbare en robuuste Azure chatbot-infrastructuur met behulp van Bicep. Volg de onderstaande specificaties nauwkeurig om de modulaire Bicep-bestanden te genereren.

Voor een goede leerervaring, is het aanbevolen om de modules 1 voor 1 uit te rollen en te snappen wat elk component in een module precies doet. Gebruik bijv. je eigen persoonlijke ChatGPT of vergelijkbaars die je zelf al hebt om te bevragen wat een service is en waarom je het zou gebruiken.

## Architectuur doelstelling

Het doel is om een bestaande single-VM chatbot-oplossing te transformeren naar een enterprise-architectuur. De belangrijkste verbeteringen zijn:

  * **Hoge Beschikbaarheid en Schaalbaarheid** door een Virtual Machine Scale Set (VMSS) en Availability Zones.
  * **Veilige Externe Toegang** via een Application Gateway met een Web Application Firewall (WAF).
  * **Gecentraliseerde Monitoring en Logging** met Azure Monitor en een Log Analytics Workspace.
  * **Geautomatiseerd Beheer** door de infrastructuur volledig als code te definiëren in modulaire Bicep-bestanden.

## Bicep modulaire structuur

De infrastructuur wordt opgesplitst in drie functionele modules en een hoofd-deploymentbestand.

```
.
├── main.bicep
├── deploy.sh
└── modules/
    ├── foundation.bicep   # Netwerk, logging, en backup
    ├── backend.bicep      # PaaS-diensten (Key Vault, OpenAI)
    └── compute.bicep      # Applicatiehosting (VMSS, App Gateway)
```

-----

## Specificaties per Bicep-bestand

### 1\. `modules/foundation.bicep`

**Doel:** Creëer de basisinfrastructuur voor netwerken, logging en back-up. Deze resources veranderen zelden.

**Parameters:**

  * `location`: `string` - De Azure-regio voor de resources.
  * `vnetAddressPrefix`: `string` (default: `'10.0.0.0/16'`) - Het adresbereik voor het VNet.

**Resources:**

1.  **Log Analytics Workspace**: Voor het centraliseren van alle logs en metrics.
2.  **Virtual Network (VNet)**:
      * Gebruik de `vnetAddressPrefix` parameter.
3.  **Subnetten** binnen het VNet:
      * `snet-appgateway` (Adres: `10.0.0.0/24`)
      * `snet-vmss` (Adres: `10.0.1.0/24`)
      * `snet-endpoints` (Adres: `10.0.2.0/24`)
      * `AzureBastionSubnet` (Adres: `10.0.3.0/24`) - Voor beheer.
4.  **Network Security Group (NSG)** voor `snet-vmss`:
      * **Inbound Regel 1**: Sta verkeer toe van de `AzureLoadBalancer` tag op poort `8080`.
      * **Inbound Regel 2**: Sta SSH-verkeer (poort `22`) toe vanaf de `AzureBastionSubnet`.
5.  **Private DNS Zones**:
      * Zone 1: `privatelink.openai.azure.com`
      * Zone 2: `privatelink.vaultcore.azure.net`
      * Koppel beide zones aan het VNet voor automatische DNS-registratie van de private endpoints.
6.  **Azure Bastion**: Geconfigureerd voor het VNet en geplaatst in `AzureBastionSubnet`. Vereist een Public IP.

**Outputs:**

  * `vnetId`: De resource ID van het VNet.
  * `vnetName`: De naam van het VNet.
  * `appGatewaySubnetId`: De resource ID van `snet-appgateway`.
  * `vmssSubnetId`: De resource ID van `snet-vmss`.
  * `endpointsSubnetId`: De resource ID van `snet-endpoints`.
  * `logAnalyticsWorkspaceId`: De resource ID van de Log Analytics Workspace.

### 2\. `modules/backend.bicep`

**Doel:** Creëer de beveiligde PaaS-backenddiensten.

**Parameters:**

  * `location`: `string`
  * `vnetName`: `string`
  * `endpointsSubnetId`: `string`
  * `principalIdForKVAccess`: `string` - De Object ID van de gebruiker/principal die Key Vault geheimen mag beheren.

**Resources:**

1.  **Azure Key Vault**:
      * Schakel `publicNetworkAccess` uit.
      * Schakel `enableRbacAuthorization` in.
2.  **Private Endpoint voor Key Vault**:
      * Plaats in het `endpointsSubnetId`.
      * Koppel aan de `privatelink.vaultcore.azure.net` DNS-zone.
3.  **Azure OpenAI Service**:
      * Schakel `publicNetworkAccess` uit.
4.  **Private Endpoint voor OpenAI**:
      * Plaats in het `endpointsSubnetId`.
      * Koppel aan de `privatelink.openai.azure.com` DNS-zone.

**Outputs:**

  * `keyVaultName`: De naam van de Key Vault.
  * `azureOpenAIName`: De naam van de Azure OpenAI-service.

### 3\. `modules/compute.bicep`

**Doel:** Creëer de rekenkracht en toegangspoort voor de applicatie.

**Parameters:**

  * `location`: `string`
  * `vmssSubnetId`: `string`
  * `appGatewaySubnetId`: `string`
  * `keyVaultName`: `string`
  * `azureOpenAIName`: `string`
  * `adminUsername`: `string` - Gebruikersnaam voor de VM's.
  * `adminSshPublicKey`: `string` - De publieke SSH-sleutel voor de beheerder.

**Resources:**

1.  **Public IP Address** (Standard SKU) voor de Application Gateway.
2.  **Internal Load Balancer** (Standard SKU):
      * **Frontend IP Configuration**: Een privaat IP-adres in `snet-vmss`.
      * **Backend Address Pool**: Leeg, wordt gevuld door de VMSS.
      * **Health Probe**: TCP-probe op poort `8080`.
      * **Load Balancing Rule**: Verdeel verkeer van de frontend naar de backend pool op poort `8080`.
3.  **Virtual Machine Scale Set (VMSS)**:
      * **SKU**: `Standard_B2s`
      * **Image**: Ubuntu Server 22.04 LTS.
      * **Instance Count**: Start met 2 instances.
      * **Availability Zones**: Spreid de instances over zones 1, 2 en 3.
      * **Networking**: Koppel aan `vmssSubnetId` en de backend pool van de Internal Load Balancer.
      * **Identity**: Schakel een **System-Assigned Managed Identity** in.
      * **Autoscaling**:
          * Schaal uit naar max. 5 instances als CPU \> 75% voor 5 minuten.
          * Schaal in naar min. 2 instances als CPU \< 25% voor 10 minuten.
      * **VM Extension (`CustomScript`)**: Gebruik een script dat de Streamlit-app installeert en een service configureert. Zie de `chatbot.service` configuratie in het originele document.
4.  **Key Vault Access Policy**: Wijs 'Get' en 'List' permissies voor secrets toe aan de **Managed Identity** van de VMSS.
5.  **Application Gateway** (Standard\_v2 / WAF\_v2 SKU):
      * **WAF**: Schakel de WAF in met de OWASP 3.2 ruleset en zet deze in 'Prevention' mode.
      * **Frontend IP**: Koppel de Public IP.
      * **HTTP Listener**: Luister op poort 80.
      * **Backend Pool**: Verwijs naar de frontend IP-configuratie van de Internal Load Balancer.
      * **Routing Rule**: Koppel de listener aan de backend pool.

**Outputs:**

  * `appGatewayPublicIpAddress`: Het publieke IP-adres van de Application Gateway.

### 4\. `main.bicep`

**Doel:** Orkestreer de deployment van alle modules in de juiste volgorde.

**Parameters:**

  * `adminUsername`: `string`
  * `adminSshPublicKey`: `string`
  * `principalIdForKVAccess`: `string` (met `az ad signed-in-user show --query id -o tsv` als default waarde).

**Logica:**

1.  **Definieer een `location` variabele**: `resourceGroup().location`.
2.  **Roep de `foundation` module aan**: Geef de `location` mee.
3.  **Roep de `backend` module aan**:
      * Gebruik outputs van de `foundation` module (bv. `endpointsSubnetId`, `vnetName`).
      * Geef de `principalIdForKVAccess` parameter door.
4.  **Roep de `compute` module aan**:
      * `dependsOn`: `[ foundation, backend ]` om de juiste volgorde af te dwingen.
      * Gebruik outputs van zowel `foundation` (subnet ID's) als `backend` (Key Vault- en OpenAI-namen).
      * Geef de admin-credentials door.

**Outputs:**

  * `chatbotAccessUrl`: Construeer een URL, bijvoorbeeld `'http://${compute.outputs.appGatewayPublicIpAddress}'`.

### 5\. `deploy.sh`

**Doel:** Vereenvoudig het deployment proces.

**Script logica:**

1.  Vraag om een `RESOURCE_GROUP` naam.
2.  Lees de SSH public key (`~/.ssh/id_rsa.pub`) in een variabele.
3.  Haal de object-ID van de ingelogde gebruiker op (`az ad signed-in-user show...`).
4.  Voer het `az deployment group create` commando uit op `main.bicep` en geef de variabelen als parameters mee.

-----

## Post-deployment stappen

Na de Bicep deployment zijn er nog twee handmatige stappen nodig:

1.  **Voeg OpenAI API-Key toe aan Key Vault**: Haal de API-sleutel van de OpenAI-service op en voeg deze als een secret (`OpenAI-API-Key`) toe aan de Key Vault.
2.  **Implementeer een Model in OpenAI**: Implementeer een model zoals 'gpt-4' in de Azure OpenAI-service. Zonder een geïmplementeerd model zal de chatbot niet werken.