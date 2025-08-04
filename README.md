# Workshop: Bouw je eigen Enterprise Chatbot met Bicep (AZ-104)

🎯 **Leerdoel**: Bouw een enterprise-grade chatbot infrastructuur met Azure en leer Bicep best practices

## 📚 Wat ga je leren?

### AZ-104 Exam Skills:
- **Virtual Networks & Subnets**: Netwerk segmentatie en security
- **Load Balancing**: Internal LB + Application Gateway architectuur
- **Virtual Machine Scale Sets**: Auto-scaling en high availability
- **Azure Key Vault**: Secrets management met RBAC
- **Private Endpoints**: Secure PaaS connectivity
- **Azure Bastion**: Secure VM management
- **Monitoring**: Log Analytics en autoscaling metrics

### Bicep Best Practices:
- **Parameterisatie**: Flexibele, herbruikbare templates
- **Modulaire architectuur**: Foundation → Backend → Compute
- **Naming conventions**: Consistente resource naamgeving
- **Validation**: Input validatie met decorators
- **Environment management**: Dev/Test/Prod configuraties

## 🏗️ Architectuur Overzicht

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Foundation    │    │     Backend      │    │     Compute     │
│                 │    │                  │    │                 │
│ • VNet/Subnets  │───▶│ • Key Vault      │───▶│ • VMSS          │
│ • NSG Rules     │    │ • OpenAI Service │    │ • Load Balancer │
│ • DNS Zones     │    │ • Private        │    │ • App Gateway   │
│ • Bastion       │    │   Endpoints      │    │ • Autoscaling   │
│ • Log Analytics │    │                  │    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

### 🔒 Security Features:
- **Zero Trust**: Alle PaaS services via private endpoints
- **WAF Protection**: OWASP 3.2 ruleset tegen web attacks
- **RBAC**: Managed Identity voor Key Vault toegang
- **Network Segmentation**: Dedicated subnets per functie

### 📈 Scalability Features:
- **Auto-scaling**: CPU-based scaling (2-5 instances)
- **Availability Zones**: Multi-zone deployment
- **Load Balancing**: Internal LB + Application Gateway

## 📁 Project Structuur

```
.
├── main.bicep              # 🎯 Orchestrator - roept modules aan
├── main.bicepparam         # ⚙️  Environment parameters
├── deploy.sh              # 🚀 Deployment script
├── post-deploy.sh         # 🔧 Post-deployment configuratie
└── modules/
    ├── foundation.bicep   # 🏗️  Netwerk & basis infrastructuur
    ├── backend.bicep      # 🔐 PaaS services (Key Vault, OpenAI)
    └── compute.bicep      # 💻 Applicatie hosting (VMSS, App Gateway)
```

### 🎓 Leer Aanpak:
1. **Bestudeer** elke module voordat je deployed
2. **Begrijp** de parameters en hun impact
3. **Experimenteer** met verschillende configuraties
4. **Reflecteer** op de AZ-104 exam topics

---

# 📖 Module Deep Dive

## 🎯 Leer Strategie
Voor elke module:
1. **Lees** de specificaties
2. **Bekijk** de code in de module
3. **Identificeer** de AZ-104 exam topics
4. **Deploy** en **verifieer** het resultaat

## Specificaties per Bicep-bestand

### 1️⃣ `modules/foundation.bicep` - Netwerk Foundation

**🎯 AZ-104 Topics:** Virtual Networks, Subnets, NSGs, Private DNS, Azure Bastion

**Doel:** Creëer de basis netwerk infrastructuur die alle andere services gebruiken.

**🔧 Key Parameters:**
- `resourcePrefix`: Naming convention (bijv. `dev-chatbot`)
- `vnetAddressPrefix`: VNet CIDR (default: `10.0.0.0/16`)
- `logRetentionDays`: Log Analytics retention (30-730 dagen)

**💡 Bicep Features:**
- `cidrSubnet()` functie voor automatische subnet berekening
- `naming` object voor consistente resource namen
- Decorators voor parameter validatie

**📦 Resources:**

| Resource | Purpose | AZ-104 Exam Topic |
|----------|---------|-------------------|
| **Log Analytics Workspace** | Centralized logging | Monitor and maintain Azure resources |
| **Network Security Group** | Subnet-level firewall | Configure and manage virtual networks |
| **Virtual Network** | Network isolation | Configure and manage virtual networks |
| **4 Subnets** | Network segmentation | Configure and manage virtual networks |
| **Private DNS Zones** | Private endpoint resolution | Configure and manage virtual networks |
| **Azure Bastion** | Secure VM access | Manage identities and governance |

**🔍 Subnet Layout:**
```
10.0.0.0/16 (VNet)
├── 10.0.0.0/24 (snet-appgateway)    # Application Gateway
├── 10.0.1.0/24 (snet-vmss)         # Virtual Machine Scale Set
├── 10.0.2.0/24 (snet-endpoints)    # Private Endpoints
└── 10.0.3.0/24 (AzureBastionSubnet) # Azure Bastion
```

**🛡️ Security Rules:**
- Allow Azure Load Balancer → Port 8080 (Health probes)
- Allow Bastion Subnet → Port 22 (SSH management)

**📤 Outputs:**
- `vnetId`, `vnetName`: Voor module dependencies
- `*SubnetId`: Subnet references voor andere modules
- `logAnalyticsWorkspaceId`: Voor monitoring configuratie

### 2️⃣ `modules/backend.bicep` - Secure PaaS Services

**🎯 AZ-104 Topics:** Key Vault, Cognitive Services, Private Endpoints, RBAC

**Doel:** Deploy beveiligde PaaS services zonder public internet toegang.

**🔧 Key Parameters:**
- `resourcePrefix`: Voor consistente naming
- `principalIdForKVAccess`: User Object ID voor Key Vault RBAC
- `endpointsSubnetId`: Subnet voor private endpoints

**🔐 Security Design:**
- **Zero Public Access**: Alle services via private endpoints
- **RBAC Authorization**: Geen legacy access policies
- **DNS Integration**: Automatische private DNS registratie

**📦 Resources:**

| Resource | Configuration | AZ-104 Exam Topic |
|----------|---------------|-------------------|
| **Key Vault** | RBAC-only, no public access | Manage identities and governance |
| **OpenAI Service** | S0 SKU, private only | Deploy and manage Azure compute resources |
| **Private Endpoints** | DNS zone integration | Configure and manage virtual networks |

**🔗 Private Connectivity:**
```
VMSS → Private Endpoint → Key Vault
                       → OpenAI Service
```

**💡 Learning Points:**
- **Private Endpoints**: Hoe PaaS services veilig te verbinden
- **DNS Zone Groups**: Automatische DNS registratie
- **RBAC vs Access Policies**: Modern authorization model

**📤 Outputs:**
- `keyVaultName`: Voor RBAC configuratie in compute module
- `azureOpenAIName`: Voor post-deployment script

### 3️⃣ `modules/compute.bicep` - Application Platform

**🎯 AZ-104 Topics:** VMSS, Load Balancers, Application Gateway, Auto-scaling, Managed Identity

**Doel:** Deploy schaalbare, highly available applicatie infrastructuur.

**🔧 Key Parameters:**
- `vmSku`: VM size (default: `Standard_B2s`)
- `minInstances`/`maxInstances`: Auto-scaling grenzen
- `scaleOutThreshold`/`scaleInThreshold`: CPU thresholds
- `adminSshPublicKey`: SSH public key voor VM toegang

**📈 Scaling Strategy:**
- **Scale Out**: CPU > 75% voor 5 minuten → +1 instance
- **Scale In**: CPU < 25% voor 10 minuten → -1 instance
- **Zones**: Spread over 3 availability zones

**📦 Resources:**

| Resource | Purpose | AZ-104 Exam Topic |
|----------|---------|-------------------|
| **VMSS** | Scalable compute platform | Deploy and manage Azure compute resources |
| **Internal Load Balancer** | Backend load distribution | Configure and manage virtual networks |
| **Application Gateway** | WAF + external load balancing | Configure and manage virtual networks |
| **Autoscale Settings** | CPU-based scaling | Monitor and maintain Azure resources |
| **Managed Identity** | Secure service authentication | Manage identities and governance |

**🏗️ Architecture Flow:**
```
Internet → App Gateway (WAF) → Internal LB → VMSS Instances
                                              ↓
                                         Managed Identity
                                              ↓
                                          Key Vault
```

**💡 Advanced Features:**
- **cidrHost()**: Berekent statisch IP voor load balancer
- **Custom Script Extension**: Installeert Streamlit app
- **Managed Identity**: Passwordless Key Vault toegang

**📤 Outputs:**
- `appGatewayPublicIpAddress`: Chatbot toegangs-URL

### 4️⃣ `main.bicep` - Orchestrator

**🎯 AZ-104 Topics:** Resource Dependencies, Parameter Management, Module Orchestration

**Doel:** Coördineer de deployment van alle modules met juiste dependencies.

**🔧 Parameters met Validation:**
```bicep
@allowed(['dev', 'test', 'prod'])
param environment string = 'dev'

@minValue(1) @maxValue(10)
param minInstances int = 2
```

**📋 Deployment Flow:**
1. **Foundation** → Netwerk basis
2. **Backend** → PaaS services (depends on Foundation)
3. **Compute** → Applicatie platform (depends on Foundation + Backend)

**🔄 Module Dependencies:**
```bicep
Foundation (VNet) → Backend (Private Endpoints) → Compute (VMSS)
```

**📤 Final Output:**
- `chatbotAccessUrl`: Complete HTTP URL naar de chatbot

### 5️⃣ `main.bicepparam` - Parameter File

**🎯 Bicep Best Practice:** Environment-specific configuration

**Voordelen:**
- Type-safe parameter definitie
- IntelliSense support
- Gekoppeld aan template schema

### 6️⃣ Deployment Scripts

**`deploy.sh`** - Interactive deployment:
- Resource group creation/selection
- Environment configuration (dev/test/prod)
- SSH key validation
- Parameter file + runtime overrides

**`post-deploy.sh`** - Automated configuration:
- OpenAI API key management
- GPT-4 model deployment
- Service discovery and URL output

---

# 🚀 Hands-on Workshop

## Stap 1: Voorbereiding (5 min)

### ✅ Prerequisites Checklist:
```bash
# 1. Azure CLI login
az login
az account show  # Verify correct subscription

# 2. SSH Key generatie
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa
# Press Enter for all prompts (no passphrase)

# 3. Verify SSH key
ls -la ~/.ssh/id_rsa.pub
```

## Stap 2: Code Exploratie (10 min)

### 🔍 Bestudeer de Templates:
1. **Open `main.bicep`** - Bekijk de parameters en decorators
2. **Open `main.bicepparam`** - Zie de default configuratie
3. **Open `modules/foundation.bicep`** - Zoek de `cidrSubnet()` functie
4. **Open `modules/compute.bicep`** - Vind de autoscaling configuratie

### 💡 Reflectie Vragen:
- Welke AZ-104 exam topics zie je in elke module?
- Hoe zorgt de `naming` variable voor consistentie?
- Waarom gebruiken we private endpoints?

## Stap 3: Deployment (15 min)

### 🚀 Deploy de Infrastructure:
```bash
# Maak executable
chmod +x deploy.sh post-deploy.sh

# Start deployment
./deploy.sh
```

**Deployment Keuzes:**
- **Resource Group**: Nieuw aanmaken of bestaande gebruiken
- **Environment**: `dev` (aanbevolen voor workshop)
- **VM SKU**: `Standard_B2s` (cost-effective)
- **Admin Username**: `azureuser` (default)

### ⏱️ Deployment Timeline:
- **Foundation Module**: ~3 minuten (VNet, Bastion)
- **Backend Module**: ~5 minuten (Key Vault, OpenAI)
- **Compute Module**: ~7 minuten (VMSS, App Gateway)

## Stap 4: Post-Configuration (5 min)

### 🔧 Configureer OpenAI:
```bash
./post-deploy.sh
```

**Wat gebeurt er:**
1. OpenAI API key → Key Vault secret
2. GPT-4 model deployment
3. Chatbot URL output

## Stap 5: Verificatie & Testing (10 min)

### ✅ Controleer de Deployment:

1. **Azure Portal Verificatie:**
   - Resource Group → Bekijk alle resources
   - VMSS → Controleer instance count en zones
   - Application Gateway → Bekijk backend health
   - Key Vault → Controleer RBAC assignments

2. **Chatbot Testing:**
   ```
   Open: http://<APP_GATEWAY_IP>
   Test: "Hello, how are you?"
   ```

3. **Scaling Testing:**
   ```bash
   # Genereer CPU load op VMSS
   # Bekijk scaling in Azure Portal
   ```

---

# 🎓 Learning Outcomes

## AZ-104 Exam Mapping

| Workshop Component | AZ-104 Skill |
|-------------------|---------------|
| VNet + Subnets | Configure and manage virtual networks (25-30%) |
| NSG Rules | Configure and manage virtual networks (25-30%) |
| VMSS + Auto-scaling | Deploy and manage Azure compute resources (25-30%) |
| Load Balancers | Configure and manage virtual networks (25-30%) |
| Key Vault + RBAC | Manage identities and governance (15-20%) |
| Private Endpoints | Configure and manage virtual networks (25-30%) |
| Monitoring + Alerts | Monitor and maintain Azure resources (10-15%) |

## Bicep Best Practices Geleerd

✅ **Parameterisatie**: Flexibele, herbruikbare templates  
✅ **Modulaire Architectuur**: Separation of concerns  
✅ **Naming Conventions**: Consistente resource naamgeving  
✅ **Input Validation**: Decorators voor parameter validatie  
✅ **Calculated Values**: `cidrSubnet()` en `cidrHost()` functies  

---

# 🔧 Troubleshooting Guide

## Deployment Issues

**❌ SSH Key Not Found:**
```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa
```

**❌ Resource Group Doesn't Exist:**
- Deploy script offers to create new RG
- Or manually: `az group create --name myRG --location westeurope`

**❌ Insufficient Permissions:**
```bash
az role assignment create --assignee $(az ad signed-in-user show --query id -o tsv) \
  --role "Contributor" --scope "/subscriptions/$(az account show --query id -o tsv)"
```

## Application Issues

**❌ Chatbot Not Responding:**
1. Check VMSS instances: `az vmss list-instances`
2. Check custom script extension logs
3. Verify GPT-4 model deployment

**❌ Authentication Errors:**
1. Verify Managed Identity has Key Vault Secrets User role
2. Check Key Vault RBAC assignments
3. Verify OpenAI API key in Key Vault

---

# 🎯 Next Steps

## Experiment Further:
1. **Scale Testing**: Genereer CPU load en bekijk auto-scaling
2. **Security Testing**: Test WAF rules met malicious requests
3. **Monitoring**: Setup alerts voor scaling events
4. **Multi-Environment**: Deploy naar test/prod met andere parameters

## Advanced Scenarios:
- **Blue/Green Deployment**: Gebruik deployment slots
- **Disaster Recovery**: Multi-region deployment
- **Cost Optimization**: Reserved instances, spot VMs
- **DevOps Integration**: Azure DevOps pipelines

**🏆 Gefeliciteerd! Je hebt een enterprise-grade chatbot infrastructuur gebouwd met Bicep best practices!**