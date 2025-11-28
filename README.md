# Private AKS Cluster con Terraform

Questa configurazione crea un cluster Azure Kubernetes Service (AKS) **completamente privato** seguendo le best practice di sicurezza.

## 🔒 Caratteristiche di Sicurezza

### Cluster Completamente Privato
- **API Server Privato**: Accessibile solo tramite private endpoint nella VNet
- **Nessun FQDN Pubblico**: `private_cluster_public_fqdn_enabled = false`
- **User Defined Routing (UDR)**: Tutto il traffico passa attraverso route table personalizzate
- **Private DNS Zone**: Risoluzione DNS privata per il cluster
- **Network Policy**: Calico per controllo del traffico tra pod

### Sicurezza Aggiuntiva
- **Azure AD Integration**: Autenticazione e RBAC gestiti da Azure AD
- **Local Accounts Disabilitati**: Solo accesso tramite Azure AD
- **Azure Policy**: Policy enforcement automatico
- **Key Vault Secrets Provider**: Integrazione sicura con Azure Key Vault
- **Network Security Groups**: Controllo del traffico di rete
- **System Assigned Identity**: Nessuna gestione manuale di credenziali

## 📋 Prerequisiti

### Software Richiesto
- [Terraform](https://www.terraform.io/downloads.html) >= 1.5.0
- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) >= 2.50.0
- [kubectl](https://kubernetes.io/docs/tasks/tools/)

### Accesso Azure
```bash
# Login ad Azure
az login

# Imposta la subscription corretta
az account set --subscription "<SUBSCRIPTION_ID>"

# Verifica la subscription attiva
az account show
```

### Terraform Cloud (se configurato)
- Account su [Terraform Cloud](https://app.terraform.io/)
- Token di autenticazione configurato

## 🚀 Deployment

### 1. Preparazione

```bash
# Clone del repository
git clone <your-repo>
cd terraform/

# Copia e personalizza le variabili
cp terraform.tfvars.example terraform.tfvars
```

### 2. Personalizza terraform.tfvars

Modifica `terraform.tfvars` con i tuoi valori:

```hcl
resource_group_name = "rg-mycompany-aks"
location            = "westeurope"
project_name        = "myapp"

# Network
vnet_address_space          = "10.240.0.0/16"
aks_subnet_address_prefix   = "10.240.1.0/24"

# AKS
aks_node_count     = 3
aks_vm_size        = "Standard_D4s_v3"

# Azure AD Admin Groups
aks_admin_group_object_ids = [
  "12345678-1234-1234-1234-123456789012"  # ID del tuo gruppo Azure AD
]
```

**Come trovare l'Object ID del gruppo Azure AD:**
```bash
az ad group show --group "Nome-Del-Tuo-Gruppo" --query id -o tsv
```

### 3. Inizializza Terraform

```bash
terraform init
```

### 4. Valida la configurazione

```bash
terraform validate
```

### 5. Pianifica le modifiche

```bash
terraform plan -out=tfplan
```

### 6. Applica la configurazione

```bash
terraform apply tfplan
```

L'installazione richiede circa 10-15 minuti.

## 🔐 Accesso al Cluster

### IMPORTANTE: Il cluster è privato!

Il cluster AKS è **completamente privato** e l'API server **NON è accessibile da Internet**. Per accedere al cluster, hai bisogno di:

### Opzione 1: Jumpbox/Bastion Host

Crea una VM nella stessa VNet (o in una VNet in peering):

```bash
# Crea una VM nella VNet
az vm create \
  --resource-group <resource-group-name> \
  --name vm-aks-jumpbox \
  --image Ubuntu2204 \
  --vnet-name <vnet-name> \
  --subnet <subnet-name> \
  --admin-username azureuser \
  --generate-ssh-keys

# Connettiti alla VM
az ssh vm --resource-group <resource-group-name> --name vm-aks-jumpbox
```

Dalla VM, installa Azure CLI e kubectl, quindi:

```bash
# Login ad Azure
az login

# Ottieni le credenziali del cluster
az aks get-credentials \
  --resource-group <resource-group-name> \
  --name <aks-cluster-name>

# Verifica l'accesso
kubectl get nodes
```

### Opzione 2: Azure Bastion

```bash
# Crea Azure Bastion nella VNet
az network bastion create \
  --name bastion-aks \
  --resource-group <resource-group-name> \
  --vnet-name <vnet-name> \
  --location <location>
```

### Opzione 3: VPN Gateway

Configura un VPN Gateway per connetterti alla VNet da remoto:

```bash
# Crea VPN Gateway (richiede tempo, ~30-45 minuti)
az network vnet-gateway create \
  --name vpn-gateway-aks \
  --resource-group <resource-group-name> \
  --vnet <vnet-name> \
  --gateway-type Vpn \
  --vpn-type RouteBased \
  --sku VpnGw1 \
  --location <location>
```

### Opzione 4: Azure DevOps Self-Hosted Agent

Per CI/CD, usa un self-hosted agent nella VNet:

1. Crea una VM nella VNet
2. Installa l'Azure DevOps agent
3. Configura le pipeline per usare questo agent

## 🏗️ Architettura

```
┌─────────────────────────────────────────────────────────┐
│                    Virtual Network                      │
│                   (10.240.0.0/16)                       │
│                                                         │
│  ┌──────────────────────────┐  ┌────────────────────┐   │
│  │   AKS Nodes Subnet       │  │  Private Endpoints │   │
│  │   (10.240.1.0/24)        │  │  Subnet            │   │
│  │                          │  │  (10.240.2.0/24)   │   │
│  │  ┌────┐ ┌────┐ ┌────┐    │  │                    │   |
│  │  │Node│ │Node│ │Node│    │  │  ┌──────────────┐  │   |
│  │  └────┘ └────┘ └────┘    │  │  │AKS Private   │  │   |
│  │         │                │  │  │Endpoint      │  │   │
│  │         │                │  │  └──────────────┘  │   │
│  │    ┌────▼────┐           │  │                    │   │
│  │    │   NSG   │           │  └────────────────────┘   │
│  │    └─────────┘           │                           │
│  │    ┌─────────┐           │                           │
│  │    │Route TB │           │                           │
│  │    └─────────┘           │                           │
│  └──────────────────────────┘                           │
│                                                         │
│  ┌──────────────────────────────────────────────────┐   │
│  │         Private DNS Zone                         │   │
│  │  privatelink.{location}.azmk8s.io                │   │
│  └──────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
                        │
                        │ VPN/Bastion/Jumpbox
                        │
                   ┌────▼────┐
                   │  Admin  │
                   │  Access │
                   └─────────┘
```

## 📊 Monitoring

Il cluster include:

- **Log Analytics Workspace**: Raccolta centralizzata dei log
- **OMS Agent**: Integrato nel cluster
- **Azure Monitor**: Metriche e alerting

Visualizza i log:

```bash
# Tramite Azure CLI
az monitor log-analytics query \
  --workspace <workspace-id> \
  --analytics-query "ContainerLog | take 100"

# Tramite Azure Portal
# Vai a: AKS Cluster -> Insights -> Logs
```

## 🔧 Manutenzione

### Upgrade del Cluster

```bash
# Verifica le versioni disponibili
az aks get-upgrades \
  --resource-group <resource-group-name> \
  --name <aks-cluster-name>

# Aggiorna la versione in variables.tf
# Poi applica le modifiche
terraform plan
terraform apply
```

### Scaling dei Nodi

Modifica in `terraform.tfvars`:
```hcl
aks_node_count     = 5
aks_max_node_count = 10
```

Poi applica:
```bash
terraform apply
```

### Backup

I workload Kubernetes possono essere backuppati con:
- [Velero](https://velero.io/)
- Azure Backup per AKS

## 🧹 Distruzione dell'Infrastruttura

**ATTENZIONE**: Questo comando eliminerà tutte le risorse!

```bash
terraform destroy
```

## 📝 Note Importanti

### CIDR Planning

Assicurati che i CIDR non si sovrappongano:

- **VNet CIDR**: `10.240.0.0/16`
- **AKS Subnet**: `10.240.1.0/24`
- **PE Subnet**: `10.240.2.0/24`
- **Service CIDR**: `10.0.0.0/16` (diverso dalla VNet!)
- **DNS Service IP**: `10.0.0.10` (dentro Service CIDR)

### Costi

Questa configurazione include:

- AKS cluster (gratuito, paghi solo i nodi)
- VM nodes (Standard_D2s_v3 o superiore)
- Load Balancer Standard
- Log Analytics Workspace
- Private DNS Zone
- Eventuale Bastion/VPN Gateway (se configurato)

Stima: ~€200-500/mese per un cluster di sviluppo con 2-3 nodi.

### Limitazioni

- **Nessun accesso pubblico**: Richiede VPN/Bastion/Jumpbox
- **CI/CD**: Serve self-hosted agent nella VNet
- **DNS**: Richiede configurazione DNS privata corretta

## 🆘 Troubleshooting

### Non riesco ad accedere al cluster

```bash
# Verifica di essere nella VNet o connesso tramite VPN
nslookup <cluster-fqdn>

# Verifica la connettività
kubectl cluster-info
```

### Errori durante il deployment

```bash
# Verifica i log di Terraform
terraform plan -out=tfplan
terraform show tfplan

# Verifica le risorse su Azure
az resource list --resource-group <resource-group-name>
```

### I pod non partono

```bash
# Verifica i pod
kubectl get pods --all-namespaces

# Descrivi un pod problematico
kubectl describe pod <pod-name> -n <namespace>

# Verifica i log
kubectl logs <pod-name> -n <namespace>
```

## 📚 Risorse Utili

- [AKS Private Cluster Documentation](https://docs.microsoft.com/en-us/azure/aks/private-clusters)
- [Terraform AKS Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/kubernetes_cluster)
- [AKS Best Practices](https://docs.microsoft.com/en-us/azure/aks/best-practices)
- [Kubernetes Documentation](https://kubernetes.io/docs/home/)

## 🤝 Contributi

Per contribuire o segnalare problemi, apri una issue o pull request.

## 📄 License

Questo progetto è rilasciato sotto licenza MIT.