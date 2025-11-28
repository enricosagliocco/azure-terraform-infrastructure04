# Azure Terraform Infrastructure for a Private AKS Cluster

This project deploys a secure and private Azure Kubernetes Service (AKS) cluster using Terraform. The infrastructure is managed through GitOps principles, with CI/CD pipelines for automated deployment and destruction.

## Architecture

The Terraform configuration creates the following resources:

*   **Azure Resource Group**: A logical container for all the Azure resources.
*   **Virtual Network (VNet)**: An isolated network for the AKS cluster.
*   **Subnets**: Dedicated subnets for the AKS nodes and private endpoints.
*   **Private DNS Zone**: For private name resolution of the AKS cluster.
*   **Log Analytics Workspace**: For collecting and analyzing logs from the AKS cluster.
*   **Azure Kubernetes Service (AKS)**: A private AKS cluster with local accounts disabled and Azure AD integration enabled for enhanced security.

The AKS cluster is configured to be private, meaning the API server is not accessible from the public internet. Access to the cluster is only possible from within the VNet or through a peered network.

## Terraform Configuration

The Terraform code is located in the `terraform/` directory.

### Variables

The infrastructure is highly customizable through variables defined in `terraform/variables.tf`. You can override the default values by creating a `terraform.tfvars` file.

The main variables are:

| Variable                     | Description                                            | Default Value |
| ---------------------------- | ------------------------------------------------------ | ------------- |
| `resource_group_name`        | The name of the Azure Resource Group.                  | `rg-dev-eus`  |
| `location`                   | The Azure region where the resources will be created.  | `eastus`      |
| `project_name`               | The name of the project.                               | `dev`         |
| `environment`                | The environment name.                                  | `dev`         |
| `aks_name`                   | The name of the AKS cluster.                           | `aks-dev-eus` |
| `aks_admin_group_object_ids` | The object IDs of the Azure AD groups for AKS admins.  | `[]`          |

### Outputs

The Terraform configuration exports the following outputs:

| Output                | Description                            |
| --------------------- | -------------------------------------- |
| `resource_group_name` | The name of the Azure Resource Group.  |
| `aks_name`            | The name of the AKS cluster.           |
| `aks_kube_config`     | The Kubernetes configuration file for the AKS cluster (sensitive). |

## CI/CD Pipelines

The project includes two GitHub Actions workflows for CI/CD, located in the `.github/workflows/` directory.

### Deployment (`azure-terraform.yml`)

This workflow automates the deployment of the infrastructure. It is triggered on:

*   **Pull requests to `main`**: Runs `terraform plan` to show the changes.
*   **Pushes to `main`**: Runs `terraform apply` to deploy the changes.

The workflow uses the following secrets:

*   `AZURE_CREDENTIALS`: Azure service principal credentials for authentication.
*   `TF_CLOUD_TOKEN`: Terraform Cloud token for state management.
*   `ARM_CLIENT_ID`: The client ID of the service principal.
*   `ARM_CLIENT_SECRET`: The client secret of the service principal.
*   `ARM_SUBSCRIPTION_ID`: The Azure subscription ID.
*   `ARM_TENANT_ID`: The Azure tenant ID.

### Destruction (`terraform-destroy.yml`)

This workflow destroys all the resources created by Terraform. It is a manually triggered workflow to prevent accidental destruction of the infrastructure.

To run this workflow, you need to go to the "Actions" tab in the GitHub repository, select the "Terraform Destroy" workflow, and click "Run workflow".

## Manual Deployment

To deploy the infrastructure manually, you need to have Terraform and Azure CLI installed and configured.

1.  **Clone the repository:**
    ```bash
    git clone <repository-url>
    cd <repository-directory>/terraform
    ```

2.  **Initialize Terraform:**
    ```bash
    terraform init
    ```

3.  **Create a `terraform.tfvars` file** to override the default variables.

4.  **Run `terraform plan`** to see the changes:
    ```bash
    terraform plan
    ```

5.  **Run `terraform apply`** to deploy the infrastructure:
    ```bash
    terraform apply
    ```

## Destroy the Infrastructure

To destroy the infrastructure, you can either use the `terraform-destroy.yml` workflow or run the following command:

```bash
terraform destroy
```
