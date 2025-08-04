# Workshop: Bouw je eigen Enterprise Chatbot met Bicep (AZ-104)

Welkom bij deze hands-on workshop! In deze workshop ga je stap voor stap een enterprise-grade chatbotomgeving bouwen in Azure. Je leert werken met essentiële Azure services en past direct de kennis toe die je nodig hebt voor het **AZ-104 Azure Administrator** examen.

## Waarom deze workshop?

Tijdens het AZ-104 examen wordt je kennis getest over het beheren, beveiligen en automatiseren van Azure infrastructuur. In deze workshop oefen je deze vaardigheden door een complete, schaalbare en veilige chatbot-omgeving te bouwen met **Infrastructure as Code** (Bicep). Je werkt in een eigen, geïsoleerde omgeving en krijgt inzicht in het waarom en hoe van elke Azure service die je inzet.

## Wat ga je doen?

- Je start met een eenvoudige single-VM chatbot en transformeert deze naar een enterprise-architectuur.
- Je leert hoe je Azure resources opzet, beveiligt, monitort en beheert volgens best practices.
- Je werkt modulair: elke stap is een aparte module, zodat je precies ziet wat elk onderdeel doet.
- Je krijgt uitleg, opdrachten en reflectievragen bij elke module, zodat je actief leert en de link met het AZ-104 examen duidelijk is.

## Architectuur doelstelling

Het doel is om een bestaande single-VM chatbot-oplossing te transformeren naar een enterprise-architectuur. De belangrijkste bouwstenen zijn:

  * **Hoge Beschikbaarheid en Schaalbaarheid** door een Virtual Machine Scale Set (VMSS) en Availability Zones.
  * **Veilige Externe Toegang** via een Application Gateway met een Web Application Firewall (WAF).
  * **Gecentraliseerde Monitoring en Logging** met Azure Monitor en een Log Analytics Workspace.
  * **Geautomatiseerd Beheer** door de infrastructuur volledig als code te definiëren in modulaire Bicep-bestanden.

## Workshopstructuur

De infrastructuur is opgesplitst in drie functionele Bicep modules en een hoofd-deploymentbestand. Je rolt de modules één voor één uit, onderzoekt wat er gebeurt, en beantwoordt reflectievragen.

```
.
├── main.bicep
├── deploy.sh
├── post-deploy.sh     # Automatiseert post-deployment stappen
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

1.  **Log Analytics Workspace**: Voor het centraliseren van alle logs en metrics (gebruikt `Microsoft.OperationalInsights/workspaces@2021-06-01`).
2.  **Network Security Group (NSG)** voor `snet-vmss`:
      * **Inbound Regel 1**: Sta verkeer toe van de `AzureLoadBalancer` tag op poort `8080`.
      * **Inbound Regel 2**: Sta SSH-verkeer (poort `22`) toe vanaf de `AzureBastionSubnet` (10.0.3.0/24).
3.  **Virtual Network (VNet)**:
      * Gebruik de `vnetAddressPrefix` parameter.
      * NSG wordt gekoppeld aan het `snet-vmss` subnet.
4.  **Subnetten** binnen het VNet:
      * `snet-appgateway` (Adres: `10.0.0.0/24`)
      * `snet-vmss` (Adres: `10.0.1.0/24`) - Met NSG gekoppeld
      * `snet-endpoints` (Adres: `10.0.2.0/24`)
      * `AzureBastionSubnet` (Adres: `10.0.3.0/24`) - Voor beheer.
5.  **Private DNS Zones**:
      * Zone 1: `privatelink.openai.azure.com`
      * Zone 2: `privatelink.vaultcore.azure.net`
      * **Virtual Network Links**: Koppel beide zones aan het VNet voor automatische DNS-registratie van de private endpoints.
6.  **Public IP voor Bastion**: Standard SKU met statische allocatie.
7.  **Azure Bastion**: Geconfigureerd voor het VNet en geplaatst in `AzureBastionSubnet`.

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
      * Geen access policies - gebruikt RBAC voor toegangsbeheer.
2.  **Private Endpoint voor Key Vault**:
      * Plaats in het `endpointsSubnetId`.
      * **Private DNS Zone Group**: Automatische koppeling aan de `privatelink.vaultcore.azure.net` DNS-zone.
3.  **Azure OpenAI Service**:
      * SKU: S0
      * Schakel `publicNetworkAccess` uit.
4.  **Private Endpoint voor OpenAI**:
      * Plaats in het `endpointsSubnetId`.
      * **Private DNS Zone Group**: Automatische koppeling aan de `privatelink.openai.azure.com` DNS-zone.
      * Gebruikt `account` als groupId voor de private link service connection.

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

1.  **Public IP Address** (Standard SKU, Regional tier) voor de Application Gateway met statische allocatie.
2.  **Internal Load Balancer** (Standard SKU, Regional tier):
      * **Frontend IP Configuration**: Dynamisch privaat IP-adres in `snet-vmss`.
      * **Backend Address Pool**: Wordt automatisch gevuld door de VMSS.
      * **Health Probe**: TCP-probe op poort `8080` (15s interval, 2 probes).
      * **Load Balancing Rule**: Verdeel verkeer van de frontend naar de backend pool op poort `8080`.
3.  **Virtual Machine Scale Set (VMSS)**:
      * **SKU**: `Standard_B2s`
      * **Image**: Ubuntu Server 22.04 LTS (`0001-com-ubuntu-server-jammy`, `22_04-lts-gen2`).
      * **Instance Count**: Start met 2 instances.
      * **Availability Zones**: Spreid de instances over zones 1, 2 en 3.
      * **Networking**: Koppel aan `vmssSubnetId` en de backend pool van de Internal Load Balancer.
      * **Identity**: Schakel een **System-Assigned Managed Identity** in.
      * **Authentication**: SSH-only (geen wachtwoord), gebruikt de `adminSshPublicKey` parameter.
      * **VM Extension (`CustomScript`)**: Inline script dat Python, Streamlit en de chatbot-app installeert en configureert als systemd service.
4.  **Autoscaling Settings** (aparte resource):
      * Schaal uit naar max. 5 instances als CPU > 75% voor 5 minuten.
      * Schaal in naar min. 2 instances als CPU < 25% voor 10 minuten.
5.  **RBAC Role Assignment**: Wijs de **Key Vault Secrets User** rol toe aan de **Managed Identity** van de VMSS.
6.  **Application Gateway** (WAF_v2 SKU):
      * **WAF**: Ingeschakeld met OWASP 3.2 ruleset in 'Prevention' mode.
      * **Frontend IP**: Koppel de Public IP.
      * **HTTP Listener**: Luister op poort 80.
      * **Backend Pool**: Verwijst naar het private IP-adres van de Internal Load Balancer.
      * **Backend HTTP Settings**: Poort 8080, HTTP protocol, 20s timeout.
      * **Routing Rule**: Koppel de listener aan de backend pool.

**Outputs:**

  * `appGatewayPublicIpAddress`: Het publieke IP-adres van de Application Gateway.

### 4\. `main.bicep`

**Doel:** Orkestreer de deployment van alle modules in de juiste volgorde.

**Parameters:**

  * `adminUsername`: `string` - Gebruikersnaam voor de VM's in de VMSS.
  * `adminSshPublicKey`: `string` - De publieke SSH-sleutel voor authenticatie.
  * `principalIdForKVAccess`: `string` - Object ID van de gebruiker voor Key Vault toegang (geen default waarde).

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

**Doel:** Vereenvoudig het deployment proces met error handling.

**Script logica:**

1.  **Error handling**: Script stopt bij fouten (`set -e`).
2.  Vraag om een `RESOURCE_GROUP` naam.
3.  Vraag om een `ADMIN_USERNAME` (default: `azureuser`).
4.  **SSH Key validatie**: Controleer of `~/.ssh/id_rsa.pub` bestaat, anders toon instructies.
5.  **User Principal ID**: Haal de object-ID van de ingelogde gebruiker op met error handling.
6.  **Deployment**: Voer het `az deployment group create` commando uit met alle parameters.

### 6\. `post-deploy.sh`

**Doel:** Automatiseer de post-deployment configuratie.

**Script logica:**

1.  Vraag om de `RESOURCE_GROUP` naam.
2.  **Resource Discovery**: Vind automatisch de Key Vault en OpenAI service namen.
3.  **OpenAI API Key**: Haal de API-sleutel op en voeg toe aan Key Vault als `OpenAI-API-Key`.
4.  **Model Deployment**: Implementeer automatisch het GPT-4 model in de OpenAI service.
5.  **URL Output**: Toon de chatbot toegangs-URL.

-----

## Deployment Instructies

### Stap 1: Voorbereiding

1. **Azure CLI**: Zorg dat je bent ingelogd: `az login`
2. **SSH Key**: Genereer een SSH key pair als je die nog niet hebt: `ssh-keygen -t rsa -b 4096`
3. **Resource Group**: Maak een resource group aan: `az group create --name <naam> --location westeurope`

### Stap 2: Deployment

1. **Hoofddeployment**: Voer `./deploy.sh` uit en volg de prompts
2. **Post-configuratie**: Voer `./post-deploy.sh` uit om de OpenAI configuratie te voltooien

### Stap 3: Verificatie

Na succesvolle deployment krijg je een URL waar de chatbot beschikbaar is. Het kan enkele minuten duren voordat de applicatie volledig operationeel is.

## Chatbot Applicatie Details

De geïmplementeerde chatbot is een **Streamlit-applicatie** die:

- **Azure Key Vault** gebruikt voor veilige opslag van de OpenAI API-sleutel
- **Managed Identity** gebruikt voor authenticatie met Azure services
- **OpenAI GPT-4** model gebruikt voor chat-functionaliteit
- Draait als **systemd service** op poort 8080
- **Session state** behoudt voor gesprekgeschiedenis

## Troubleshooting

- **Applicatie niet beschikbaar**: Controleer of de VMSS instances draaien en de custom script extension is voltooid
- **Authentication errors**: Zorg dat de Managed Identity de juiste RBAC-rechten heeft op de Key Vault
- **OpenAI errors**: Controleer of het GPT-4 model is geïmplementeerd en de API-sleutel correct is opgeslagen