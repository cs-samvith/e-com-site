# Complete Guide: Migrating from Azure AKS to Google Cloud GKE

## 📋 Table of Contents

1. [Azure to GCP Service Mapping](#azure-to-gcp-service-mapping)
2. [Prerequisites & Setup](#prerequisites--setup)
3. [Infrastructure as Code Options](#infrastructure-as-code-options)
4. [Step-by-Step Migration](#step-by-step-migration)
5. [GKE Cluster Setup](#gke-cluster-setup)
6. [CI/CD Pipeline (Cloud Build)](#cicd-pipeline-cloud-build)
7. [Deployment Strategy](#deployment-strategy)
8. [Monitoring & Logging](#monitoring--logging)
9. [Cost Optimization](#cost-optimization)
10. [Complete Migration Checklist](#complete-migration-checklist)

---

## Azure to GCP Service Mapping

### Core Services Comparison

| Azure Service                      | GCP Equivalent                          | Purpose                | Notes                                   |
| ---------------------------------- | --------------------------------------- | ---------------------- | --------------------------------------- |
| **Azure Kubernetes Service (AKS)** | **Google Kubernetes Engine (GKE)**      | Managed Kubernetes     | GKE has more K8s features out-of-box    |
| **Azure Container Registry (ACR)** | **Artifact Registry** (or GCR)          | Container registry     | Artifact Registry is newer, recommended |
| **Azure DevOps Pipelines**         | **Cloud Build**                         | CI/CD platform         | Cloud Build integrates tightly with GCP |
| **Azure Bicep/ARM Templates**      | **Terraform** or **Deployment Manager** | Infrastructure as Code | Terraform is preferred                  |
| **Azure Key Vault**                | **Secret Manager**                      | Secrets management     | Similar functionality                   |
| **Azure Load Balancer**            | **Cloud Load Balancing**                | Load balancing         | GCP has global load balancing           |
| **Azure Monitor**                  | **Cloud Monitoring** (Stackdriver)      | Monitoring             | Part of Operations Suite                |
| **Application Insights**           | **Cloud Trace + Cloud Profiler**        | APM/Tracing            | Distributed tracing                     |
| **Azure Log Analytics**            | **Cloud Logging**                       | Log aggregation        | Centralized logging                     |
| **Azure DNS**                      | **Cloud DNS**                           | DNS management         | Similar pricing                         |
| **Azure Storage**                  | **Cloud Storage**                       | Object storage         | Different pricing model                 |
| **Azure Database for PostgreSQL**  | **Cloud SQL**                           | Managed PostgreSQL     | Similar managed service                 |
| **Azure Redis Cache**              | **Memorystore for Redis**               | Managed Redis          | Similar managed service                 |
| **Azure Service Bus**              | **Cloud Pub/Sub**                       | Message queue          | Different architecture                  |
| **Azure Virtual Network**          | **VPC (Virtual Private Cloud)**         | Networking             | GCP VPCs are global by default          |
| **Azure Traffic Manager**          | **Cloud Load Balancing**                | Global routing         | GCP LB is inherently global             |
| **Azure Bastion**                  | **IAP (Identity-Aware Proxy)**          | Secure access          | Different approach                      |

### Your E-commerce Stack Mapping

**Current Azure Setup:**

```
Azure DevOps → ACR → AKS → Azure Monitor
     ↓              ↓     ↓
  Bicep        Images  Services
```

**Equivalent GCP Setup:**

```
Cloud Build → Artifact Registry → GKE → Cloud Monitoring
     ↓              ↓              ↓
 Terraform      Images         Services
```

### Detailed Service Comparison

#### Container Registry

**Azure Container Registry (ACR):**

```bash
az acr create --name myacr --resource-group rg --sku Basic
docker push myacr.azurecr.io/image:tag
```

**Google Artifact Registry:**

```bash
gcloud artifacts repositories create my-repo \
  --repository-format=docker \
  --location=us-central1

docker push us-central1-docker.pkg.dev/project-id/my-repo/image:tag
```

**Why Artifact Registry over GCR?**

- ✅ Unified registry (Docker, Maven, npm, Python)
- ✅ Better security features
- ✅ Regional and multi-regional support
- ✅ Vulnerability scanning built-in
- ✅ Future-proof (GCR is legacy)

#### CI/CD

**Azure DevOps:**

```yaml
# azure-pipelines.yml
stages:
  - stage: Build
    jobs:
      - job: BuildImage
        steps:
          - task: Docker@2
```

**Google Cloud Build:**

```yaml
# cloudbuild.yaml
steps:
  - name: "gcr.io/cloud-builders/docker"
    args: ["build", "-t", "image", "."]
```

**Cloud Build Advantages:**

- ✅ Native GCP integration
- ✅ Built-in caching
- ✅ Free tier (120 build-minutes/day)
- ✅ Kaniko support (no Docker daemon needed)
- ✅ Easier secret management

#### Secrets Management

**Azure Key Vault:**

```bash
az keyvault secret set --vault-name mykeyvault --name dbpassword --value "secret"
```

**GCP Secret Manager:**

```bash
echo -n "secret" | gcloud secrets create dbpassword --data-file=-
```

**Secret Manager Features:**

- ✅ Versioning
- ✅ Rotation
- ✅ Audit logging
- ✅ IAM integration
- ✅ Kubernetes integration (Workload Identity)

#### Database Services

**Azure Database for PostgreSQL:**

```bash
az postgres server create --name mydb --resource-group rg
```

**Cloud SQL:**

```bash
gcloud sql instances create mydb \
  --database-version=POSTGRES_14 \
  --tier=db-f1-micro \
  --region=us-central1
```

**Cloud SQL Advantages:**

- ✅ Automatic backups
- ✅ Point-in-time recovery
- ✅ Read replicas
- ✅ Private IP connectivity
- ✅ Connection proxy for security

---

## Prerequisites & Setup

### 1. Install GCP SDK (gcloud)

**macOS:**

```bash
# Using Homebrew
brew install google-cloud-sdk

# Initialize
gcloud init
```

**Linux:**

```bash
# Download SDK
curl https://sdk.cloud.google.com | bash

# Restart shell
exec -l $SHELL

# Initialize
gcloud init
```

**Windows:**

```powershell
# Download installer from:
# https://cloud.google.com/sdk/docs/install

# Run installer and follow prompts
```

### 2. Install Additional Tools

```bash
# Install kubectl (if not already installed)
gcloud components install kubectl

# Install gke-gcloud-auth-plugin (required for GKE)
gcloud components install gke-gcloud-auth-plugin

# Install Terraform
# macOS
brew install terraform

# Linux
wget https://releases.hashicorp.com/terraform/1.6.6/terraform_1.6.6_linux_amd64.zip
unzip terraform_1.6.6_linux_amd64.zip
sudo mv terraform /usr/local/bin/
```

### 3. Create GCP Project

```bash
# Set project ID (must be globally unique)
PROJECT_ID="ecommerce-learning-project"

# Create project
gcloud projects create $PROJECT_ID --name="E-commerce Learning"

# Set as default project
gcloud config set project $PROJECT_ID

# Get your billing account ID
gcloud billing accounts list

# Link billing to project
gcloud billing projects link $PROJECT_ID \
  --billing-account=BILLING_ACCOUNT_ID
```

### 4. Enable Required APIs

```bash
# Enable all necessary APIs
gcloud services enable \
  container.googleapis.com \
  artifactregistry.googleapis.com \
  cloudbuild.googleapis.com \
  compute.googleapis.com \
  secretmanager.googleapis.com \
  cloudresourcemanager.googleapis.com \
  sqladmin.googleapis.com \
  redis.googleapis.com \
  dns.googleapis.com \
  logging.googleapis.com \
  monitoring.googleapis.com

# Verify APIs are enabled
gcloud services list --enabled
```

### 5. Set Up Authentication

```bash
# Authenticate with GCP
gcloud auth login

# Set application default credentials (for Terraform)
gcloud auth application-default login

# Create service account for CI/CD
gcloud iam service-accounts create cloudbuild-sa \
  --display-name="Cloud Build Service Account"

# Grant necessary roles
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:cloudbuild-sa@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/container.developer"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:cloudbuild-sa@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/artifactregistry.writer"
```

---

## Infrastructure as Code Options

### Option 1: Terraform (Recommended) ⭐

**Why Terraform?**

- ✅ Cloud-agnostic (works with Azure, GCP, AWS)
- ✅ Large community
- ✅ Better state management
- ✅ Reusable modules
- ✅ Industry standard

**Pros:**

- Multi-cloud support
- Excellent documentation
- Rich ecosystem
- Version control friendly

**Cons:**

- Steeper learning curve than Deployment Manager
- State management complexity

**When to use:**

- ✅ Multi-cloud deployments
- ✅ Complex infrastructure
- ✅ Team already knows Terraform
- ✅ Want cloud-agnostic IaC

### Option 2: Google Cloud Deployment Manager

**Why Deployment Manager?**

- Native GCP tool
- Python/Jinja2 templates
- No state file management
- Direct GCP API integration

**Pros:**

- Native to GCP
- No additional tools needed
- Simpler for GCP-only

**Cons:**

- GCP-only
- Less mature than Terraform
- Smaller community

**When to use:**

- ✅ GCP-only deployment
- ✅ Simple infrastructure
- ✅ Don't want to learn Terraform

### Option 3: Pulumi

**Why Pulumi?**

- Infrastructure as actual code (Python, TypeScript, Go)
- Type safety
- Use existing programming skills

**Pros:**

- Real programming languages
- Better for developers
- Good testing support

**Cons:**

- Newer tool
- Smaller community
- Requires programming knowledge

**When to use:**

- ✅ Team prefers Python/TypeScript
- ✅ Want programmatic infrastructure
- ✅ Need complex logic in IaC

### Recommendation for Your Project

**Use Terraform** because:

1. You're learning - transferable skill
2. Multi-cloud (can use on Azure, GCP, AWS)
3. Industry standard
4. Better for resume
5. Rich GKE modules available

---

## Step-by-Step Migration

### Phase 1: Set Up GCP Foundation (Week 1)

#### Step 1.1: Create Terraform Project Structure

```bash
# Create directory structure
mkdir -p gcp-infrastructure/{modules,environments/{dev,staging,prod}}
cd gcp-infrastructure

# Initialize git
git init
```

**Directory structure:**

```
gcp-infrastructure/
├── modules/
│   ├── gke/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── artifact-registry/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── cloud-sql/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── networking/
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
├── environments/
│   ├── dev/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── terraform.tfvars
│   │   └── backend.tf
│   ├── staging/
│   │   └── ...
│   └── prod/
│       └── ...
└── README.md
```

#### Step 1.2: Create Terraform Backend

**environments/dev/backend.tf:**

```hcl
terraform {
  backend "gcs" {
    bucket = "ecommerce-terraform-state-dev"
    prefix = "terraform/state"
  }

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 5.0"
    }
  }

  required_version = ">= 1.6"
}
```

**Create GCS bucket for state:**

```bash
gsutil mb -p $PROJECT_ID -l us-central1 gs://ecommerce-terraform-state-dev
gsutil versioning set on gs://ecommerce-terraform-state-dev
```

#### Step 1.3: Create Networking Module

**modules/networking/main.tf:**

```hcl
resource "google_compute_network" "vpc" {
  name                    = var.network_name
  auto_create_subnetworks = false
  project                 = var.project_id
}

resource "google_compute_subnetwork" "gke_subnet" {
  name          = "${var.network_name}-gke-subnet"
  ip_cidr_range = var.subnet_cidr
  region        = var.region
  network       = google_compute_network.vpc.id
  project       = var.project_id

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = var.pods_cidr
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = var.services_cidr
  }

  private_ip_google_access = true
}

resource "google_compute_router" "router" {
  name    = "${var.network_name}-router"
  region  = var.region
  network = google_compute_network.vpc.id
  project = var.project_id
}

resource "google_compute_router_nat" "nat" {
  name                               = "${var.network_name}-nat"
  router                             = google_compute_router.router.name
  region                             = var.region
  project                            = var.project_id
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}
```

**modules/networking/variables.tf:**

```hcl
variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "us-central1"
}

variable "network_name" {
  description = "VPC Network name"
  type        = string
}

variable "subnet_cidr" {
  description = "CIDR for GKE subnet"
  type        = string
  default     = "10.0.0.0/20"
}

variable "pods_cidr" {
  description = "CIDR for pods"
  type        = string
  default     = "10.4.0.0/14"
}

variable "services_cidr" {
  description = "CIDR for services"
  type        = string
  default     = "10.8.0.0/20"
}
```

**modules/networking/outputs.tf:**

```hcl
output "network_name" {
  value = google_compute_network.vpc.name
}

output "network_self_link" {
  value = google_compute_network.vpc.self_link
}

output "subnet_name" {
  value = google_compute_subnetwork.gke_subnet.name
}

output "subnet_self_link" {
  value = google_compute_subnetwork.gke_subnet.self_link
}
```

#### Step 1.4: Create GKE Module

**modules/gke/main.tf:**

```hcl
resource "google_container_cluster" "primary" {
  name     = var.cluster_name
  location = var.region
  project  = var.project_id

  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count       = 1

  network    = var.network_self_link
  subnetwork = var.subnet_self_link

  # Enable Workload Identity
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # IP allocation policy for VPC-native cluster
  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  # Enable binary authorization
  binary_authorization {
    evaluation_mode = "PROJECT_SINGLETON_POLICY_ENFORCE"
  }

  # Network policy
  network_policy {
    enabled  = true
    provider = "PROVIDER_UNSPECIFIED"
  }

  # Maintenance window
  maintenance_policy {
    daily_maintenance_window {
      start_time = "03:00"
    }
  }

  # Addons
  addons_config {
    http_load_balancing {
      disabled = false
    }
    horizontal_pod_autoscaling {
      disabled = false
    }
    network_policy_config {
      disabled = false
    }
    gcp_filestore_csi_driver_config {
      enabled = true
    }
  }

  # Logging and monitoring
  logging_service    = "logging.googleapis.com/kubernetes"
  monitoring_service = "monitoring.googleapis.com/kubernetes"

  # Release channel
  release_channel {
    channel = var.release_channel
  }
}

resource "google_container_node_pool" "primary_nodes" {
  name       = "${var.cluster_name}-node-pool"
  location   = var.region
  cluster    = google_container_cluster.primary.name
  node_count = var.node_count
  project    = var.project_id

  autoscaling {
    min_node_count = var.min_node_count
    max_node_count = var.max_node_count
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    preemptible  = var.preemptible
    machine_type = var.machine_type
    disk_size_gb = var.disk_size_gb
    disk_type    = "pd-standard"

    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    service_account = var.service_account
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    labels = var.node_labels
    tags   = var.node_tags

    metadata = {
      disable-legacy-endpoints = "true"
    }

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }
  }
}
```

**modules/gke/variables.tf:**

```hcl
variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
}

variable "cluster_name" {
  description = "GKE Cluster name"
  type        = string
}

variable "network_self_link" {
  description = "VPC network self link"
  type        = string
}

variable "subnet_self_link" {
  description = "Subnet self link"
  type        = string
}

variable "node_count" {
  description = "Initial node count"
  type        = number
  default     = 3
}

variable "min_node_count" {
  description = "Minimum node count for autoscaling"
  type        = number
  default     = 1
}

variable "max_node_count" {
  description = "Maximum node count for autoscaling"
  type        = number
  default     = 10
}

variable "machine_type" {
  description = "Machine type for nodes"
  type        = string
  default     = "e2-medium"
}

variable "disk_size_gb" {
  description = "Disk size in GB"
  type        = number
  default     = 50
}

variable "preemptible" {
  description = "Use preemptible nodes"
  type        = bool
  default     = false
}

variable "release_channel" {
  description = "GKE release channel"
  type        = string
  default     = "REGULAR"
}

variable "service_account" {
  description = "Service account for nodes"
  type        = string
}

variable "node_labels" {
  description = "Labels for nodes"
  type        = map(string)
  default     = {}
}

variable "node_tags" {
  description = "Network tags for nodes"
  type        = list(string)
  default     = []
}
```

**modules/gke/outputs.tf:**

```hcl
output "cluster_name" {
  value = google_container_cluster.primary.name
}

output "cluster_endpoint" {
  value     = google_container_cluster.primary.endpoint
  sensitive = true
}

output "cluster_ca_certificate" {
  value     = google_container_cluster.primary.master_auth[0].cluster_ca_certificate
  sensitive = true
}

output "cluster_location" {
  value = google_container_cluster.primary.location
}
```

#### Step 1.5: Create Artifact Registry Module

**modules/artifact-registry/main.tf:**

```hcl
resource "google_artifact_registry_repository" "repo" {
  location      = var.location
  repository_id = var.repository_id
  description   = var.description
  format        = "DOCKER"
  project       = var.project_id

  cleanup_policies {
    id     = "delete-old-images"
    action = "DELETE"

    condition {
      tag_state  = "UNTAGGED"
      older_than = "2592000s" # 30 days
    }
  }

  cleanup_policies {
    id     = "keep-minimum-versions"
    action = "KEEP"

    most_recent_versions {
      keep_count = 10
    }
  }
}

# Grant GKE service account access
resource "google_artifact_registry_repository_iam_member" "gke_reader" {
  project    = var.project_id
  location   = var.location
  repository = google_artifact_registry_repository.repo.name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${var.gke_service_account}"
}
```

**modules/artifact-registry/variables.tf:**

```hcl
variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "location" {
  description = "Repository location"
  type        = string
  default     = "us-central1"
}

variable "repository_id" {
  description = "Repository ID"
  type        = string
}

variable "description" {
  description = "Repository description"
  type        = string
  default     = "Docker repository"
}

variable "gke_service_account" {
  description = "GKE service account email"
  type        = string
}
```

**modules/artifact-registry/outputs.tf:**

```hcl
output "repository_id" {
  value = google_artifact_registry_repository.repo.id
}

output "repository_name" {
  value = google_artifact_registry_repository.repo.name
}

output "repository_location" {
  value = google_artifact_registry_repository.repo.location
}
```

#### Step 1.6: Create Main Environment Configuration

**environments/dev/main.tf:**

```hcl
provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

# Create service account for GKE nodes
resource "google_service_account" "gke_nodes" {
  account_id   = "${var.cluster_name}-nodes"
  display_name = "GKE Nodes Service Account"
  project      = var.project_id
}

# Grant necessary roles
resource "google_project_iam_member" "gke_node_roles" {
  for_each = toset([
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/stackdriver.resourceMetadata.writer"
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.gke_nodes.email}"
}

# Networking
module "networking" {
  source = "../../modules/networking"

  project_id   = var.project_id
  region       = var.region
  network_name = var.network_name
  subnet_cidr  = var.subnet_cidr
  pods_cidr    = var.pods_cidr
  services_cidr = var.services_cidr
}

# GKE Cluster
module "gke" {
  source = "../../modules/gke"

  project_id        = var.project_id
  region            = var.region
  cluster_name      = var.cluster_name
  network_self_link = module.networking.network_self_link
  subnet_self_link  = module.networking.subnet_self_link

  node_count      = var.node_count
  min_node_count  = var.min_node_count
  max_node_count  = var.max_node_count
  machine_type    = var.machine_type
  disk_size_gb    = var.disk_size_gb
  preemptible     = var.preemptible
  release_channel = var.release_channel

  service_account = google_service_account.gke_nodes.email

  node_labels = {
    environment = var.environment
    managed_by  = "terraform"
  }

  node_tags = ["gke-node", var.environment]
}

# Artifact Registry
module "artifact_registry" {
  source = "../../modules/artifact-registry"

  project_id          = var.project_id
  location            = var.region
  repository_id       = "${var.project_name}-repo"
  description         = "Docker images for ${var.project_name}"
  gke_service_account = google_service_account.gke_nodes.email
}
```

**environments/dev/variables.tf:**

```hcl
variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "us-central1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "ecommerce"
}

variable "cluster_name" {
  description = "GKE Cluster name"
  type        = string
}

variable "network_name" {
  description = "VPC Network name"
  type        = string
}

variable "subnet_cidr" {
  description = "CIDR for GKE subnet"
  type        = string
  default     = "10.0.0.0/20"
}

variable "pods_cidr" {
  description = "CIDR for pods"
  type        = string
  default     = "10.4.0.0/14"
}

variable "services_cidr" {
  description = "CIDR for services"
  type        = string
  default     = "10.8.0.0/20"
}

variable "node_count" {
  description = "Initial node count"
  type        = number
  default     = 3
}

variable "min_node_count" {
  description = "Minimum node count"
  type        = number
  default     = 1
}

variable "max_node_count" {
  description = "Maximum node count"
  type        = number
  default     = 10
}

variable "machine_type" {
  description = "Machine type for nodes"
  type        = string
  default     = "e2-medium"
}

variable "disk_size_gb" {
  description = "Disk size in GB"
  type        = number
  default     = 50
}

variable "preemptible" {
  description = "Use preemptible nodes"
  type        = bool
  default     = true  # For dev environment
}

variable "release_channel" {
  description = "GKE release channel"
  type        = string
  default     = "REGULAR"
}
```

**environments/dev/terraform.tfvars:**

```hcl
project_id   = "ecommerce-learning-project"
region       = "us-central1"
environment  = "dev"
project_name = "ecommerce"
cluster_name = "ecommerce-gke-dev"
network_name = "ecommerce-vpc-dev"

# Node pool configuration
node_count     = 2
min_node_count = 1
max_node_count = 5
machine_type   = "e2-medium"
preemptible    = true  # Cost savings for dev

# Network configuration
subnet_cidr    = "10.0.0.0/20"
pods_cidr      = "10.4.0.0/14"
services_cidr  = "10.8.0.0/20"
```

**environments/dev/outputs.tf:**

```hcl
output "gke_cluster_name" {
  value = module.gke.cluster_name
}

output "gke_cluster_endpoint" {
  value     = module.gke.cluster_endpoint
  sensitive = true
}

output "artifact_registry_location" {
  value = module.artifact_registry.repository_location
}

output "artifact_registry_name" {
  value = module.artifact_registry.repository_name
}

output "configure_kubectl" {
  value = "gcloud container clusters get-credentials ${module.gke.cluster_name} --region ${var.region} --project ${var.project_id}"
}
```

#### Step 1.7: Deploy Infrastructure

```bash
# Navigate to dev environment
cd environments/dev

# Initialize Terraform
terraform init

# Plan deployment
terraform plan

# Apply configuration
terraform apply

# Get kubectl credentials
eval $(terraform output -raw configure_kubectl)

# Verify cluster access
kubectl get nodes
```

---

### Phase 2: Set Up CI/CD with Cloud Build (Week 2)

#### Step 2.1: Create Cloud Build Configuration

**cloudbuild.yaml:**

```yaml
# Cloud Build configuration for E-commerce microservices
# Supports building Python FastAPI and Node.js/Next.js services

options:
  machineType: "E2_HIGHCPU_8"
  logging: CLOUD_LOGGING_ONLY

substitutions:
  _REGION: "us-central1"
  _CLUSTER_NAME: "ecommerce-gke-dev"
  _NAMESPACE: "ecommerce"
  _IMAGE_TAG: "${SHORT_SHA}"

# Build product-service (Python FastAPI)
steps:
  # ============================================
  # TEST STAGE - Python Services
  # ============================================
  - name: "python:3.11"
    id: "test-product-service"
    entrypoint: "bash"
    args:
      - "-c"
      - |
        cd services/product-service
        pip install -r requirements.txt
        pip install -r requirements-dev.txt
        pytest --cov=app --cov-report=xml --cov-report=term --junitxml=junit.xml -v
    waitFor: ["-"]

  - name: "python:3.11"
    id: "test-user-service"
    entrypoint: "bash"
    args:
      - "-c"
      - |
        cd services/user-service
        pip install -r requirements.txt
        pip install -r requirements-dev.txt
        pytest --cov=app --cov-report=xml --cov-report=term --junitxml=junit.xml -v
    waitFor: ["-"]

  # ============================================
  # TEST STAGE - Frontend Service
  # ============================================
  - name: "node:18"
    id: "test-frontend-service"
    entrypoint: "bash"
    args:
      - "-c"
      - |
        cd services/frontend-service
        npm ci
        npm run test:coverage
    waitFor: ["-"]

  # ============================================
  # BUILD STAGE - Product Service
  # ============================================
  - name: "gcr.io/cloud-builders/docker"
    id: "build-product-service"
    args:
      - "build"
      - "-t"
      - "${_REGION}-docker.pkg.dev/$PROJECT_ID/ecommerce-repo/product-service:${_IMAGE_TAG}"
      - "-t"
      - "${_REGION}-docker.pkg.dev/$PROJECT_ID/ecommerce-repo/product-service:latest"
      - "-f"
      - "services/product-service/Dockerfile"
      - "services/product-service"
    waitFor: ["test-product-service"]

  - name: "gcr.io/cloud-builders/docker"
    id: "push-product-service"
    args:
      - "push"
      - "--all-tags"
      - "${_REGION}-docker.pkg.dev/$PROJECT_ID/ecommerce-repo/product-service"
    waitFor: ["build-product-service"]

  # ============================================
  # BUILD STAGE - User Service
  # ============================================
  - name: "gcr.io/cloud-builders/docker"
    id: "build-user-service"
    args:
      - "build"
      - "-t"
      - "${_REGION}-docker.pkg.dev/$PROJECT_ID/ecommerce-repo/user-service:${_IMAGE_TAG}"
      - "-t"
      - "${_REGION}-docker.pkg.dev/$PROJECT_ID/ecommerce-repo/user-service:latest"
      - "-f"
      - "services/user-service/Dockerfile"
      - "services/user-service"
    waitFor: ["test-user-service"]

  - name: "gcr.io/cloud-builders/docker"
    id: "push-user-service"
    args:
      - "push"
      - "--all-tags"
      - "${_REGION}-docker.pkg.dev/$PROJECT_ID/ecommerce-repo/user-service"
    waitFor: ["build-user-service"]

  # ============================================
  # BUILD STAGE - Frontend Service
  # ============================================
  - name: "gcr.io/cloud-builders/docker"
    id: "build-frontend-service"
    args:
      - "build"
      - "-t"
      - "${_REGION}-docker.pkg.dev/$PROJECT_ID/ecommerce-repo/frontend-service:${_IMAGE_TAG}"
      - "-t"
      - "${_REGION}-docker.pkg.dev/$PROJECT_ID/ecommerce-repo/frontend-service:latest"
      - "-f"
      - "services/frontend-service/Dockerfile"
      - "services/frontend-service"
    waitFor: ["test-frontend-service"]

  - name: "gcr.io/cloud-builders/docker"
    id: "push-frontend-service"
    args:
      - "push"
      - "--all-tags"
      - "${_REGION}-docker.pkg.dev/$PROJECT_ID/ecommerce-repo/frontend-service"
    waitFor: ["build-frontend-service"]

  # ============================================
  # SECURITY SCAN STAGE - Trivy
  # ============================================
  - name: "aquasec/trivy:latest"
    id: "scan-product-service"
    args:
      - "image"
      - "--severity"
      - "HIGH,CRITICAL"
      - "--format"
      - "table"
      - "${_REGION}-docker.pkg.dev/$PROJECT_ID/ecommerce-repo/product-service:${_IMAGE_TAG}"
    waitFor: ["push-product-service"]

  - name: "aquasec/trivy:latest"
    id: "scan-user-service"
    args:
      - "image"
      - "--severity"
      - "HIGH,CRITICAL"
      - "--format"
      - "table"
      - "${_REGION}-docker.pkg.dev/$PROJECT_ID/ecommerce-repo/user-service:${_IMAGE_TAG}"
    waitFor: ["push-user-service"]

  - name: "aquasec/trivy:latest"
    id: "scan-frontend-service"
    args:
      - "image"
      - "--severity"
      - "HIGH,CRITICAL"
      - "--format"
      - "table"
      - "${_REGION}-docker.pkg.dev/$PROJECT_ID/ecommerce-repo/frontend-service:${_IMAGE_TAG}"
    waitFor: ["push-frontend-service"]

  # ============================================
  # DEPLOY STAGE
  # ============================================
  - name: "gcr.io/cloud-builders/gke-deploy"
    id: "deploy-to-gke"
    args:
      - "run"
      - "--filename=kubernetes/"
      - "--location=${_REGION}"
      - "--cluster=${_CLUSTER_NAME}"
      - "--namespace=${_NAMESPACE}"
      - "--image=${_REGION}-docker.pkg.dev/$PROJECT_ID/ecommerce-repo/product-service:${_IMAGE_TAG}"
      - "--image=${_REGION}-docker.pkg.dev/$PROJECT_ID/ecommerce-repo/user-service:${_IMAGE_TAG}"
      - "--image=${_REGION}-docker.pkg.dev/$PROJECT_ID/ecommerce-repo/frontend-service:${_IMAGE_TAG}"
    waitFor:
      ["scan-product-service", "scan-user-service", "scan-frontend-service"]

timeout: 3600s

images:
  - "${_REGION}-docker.pkg.dev/$PROJECT_ID/ecommerce-repo/product-service:${_IMAGE_TAG}"
  - "${_REGION}-docker.pkg.dev/$PROJECT_ID/ecommerce-repo/user-service:${_IMAGE_TAG}"
  - "${_REGION}-docker.pkg.dev/$PROJECT_ID/ecommerce-repo/frontend-service:${_IMAGE_TAG}"
```

#### Step 2.2: Set Up Cloud Build Triggers

```bash
# Create trigger for main branch
gcloud builds triggers create github \
  --name="ecommerce-main" \
  --repo-name="ecommerce-learning-project" \
  --repo-owner="YOUR_GITHUB_USERNAME" \
  --branch-pattern="^main$" \
  --build-config="cloudbuild.yaml" \
  --substitutions="_REGION=us-central1,_CLUSTER_NAME=ecommerce-gke-dev,_NAMESPACE=ecommerce"

# Create trigger for feature branches (build only, no deploy)
gcloud builds triggers create github \
  --name="ecommerce-feature" \
  --repo-name="ecommerce-learning-project" \
  --repo-owner="YOUR_GITHUB_USERNAME" \
  --branch-pattern="^feature/.*$" \
  --build-config="cloudbuild-feature.yaml"
```

#### Step 2.3: Grant Cloud Build Permissions

```bash
# Get Cloud Build service account
PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format='value(projectNumber)')
CLOUD_BUILD_SA="${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com"

# Grant GKE access
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:${CLOUD_BUILD_SA}" \
  --role="roles/container.developer"

# Grant Artifact Registry access
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:${CLOUD_BUILD_SA}" \
  --role="roles/artifactregistry.writer"
```

---

### Phase 3: Migrate Application (Week 3)

#### Step 3.1: Update Kubernetes Manifests for GKE

**kubernetes/services/product-service.yaml:**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: product-service
  namespace: ecommerce
spec:
  replicas: 3
  selector:
    matchLabels:
      app: product-service
  template:
    metadata:
      labels:
        app: product-service
    spec:
      serviceAccountName: product-service-sa
      containers:
        - name: product-service
          image: us-central1-docker.pkg.dev/PROJECT_ID/ecommerce-repo/product-service:latest
          ports:
            - containerPort: 8081
          env:
            - name: DATABASE_URL
              valueFrom:
                secretKeyRef:
                  name: database-secrets
                  key: product-db-url
            - name: REDIS_URL
              value: "redis://redis-service:6379"
          resources:
            requests:
              memory: "256Mi"
              cpu: "250m"
            limits:
              memory: "512Mi"
              cpu: "500m"
          livenessProbe:
            httpGet:
              path: /api/health/products
              port: 8081
            initialDelaySeconds: 30
            periodSeconds: 10
          readinessProbe:
            httpGet:
              path: /api/health/products
              port: 8081
            initialDelaySeconds: 10
            periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: product-service
  namespace: ecommerce
spec:
  type: ClusterIP
  selector:
    app: product-service
  ports:
    - port: 8081
      targetPort: 8081
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: product-service-sa
  namespace: ecommerce
  annotations:
    iam.gke.io/gcp-service-account: product-service@PROJECT_ID.iam.gserviceaccount.com
```

Similar files for `user-service.yaml` and `frontend-service.yaml`.

#### Step 3.2: Create GCP-Specific Ingress

**kubernetes/ingress/ingress-gke.yaml:**

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ecommerce-ingress
  namespace: ecommerce
  annotations:
    kubernetes.io/ingress.class: "gce"
    # For HTTPS with Google-managed certificates
    networking.gke.io/managed-certificates: "ecommerce-cert"
    # Enable CDN
    cloud.google.com/neg: '{"ingress": true}'
    # Set backend timeout
    cloud.google.com/backend-config: '{"default": "backend-config"}'
spec:
  rules:
    - host: myapp.com
      http:
        paths:
          - path: /api/products
            pathType: Prefix
            backend:
              service:
                name: product-service
                port:
                  number: 8081
          - path: /api/users
            pathType: Prefix
            backend:
              service:
                name: user-service
                port:
                  number: 8080
          - path: /
            pathType: Prefix
            backend:
              service:
                name: frontend-service
                port:
                  number: 3000
---
apiVersion: networking.gke.io/v1
kind: ManagedCertificate
metadata:
  name: ecommerce-cert
  namespace: ecommerce
spec:
  domains:
    - myapp.com
    - www.myapp.com
---
apiVersion: cloud.google.com/v1
kind: BackendConfig
metadata:
  name: backend-config
  namespace: ecommerce
spec:
  timeoutSec: 300
  connectionDraining:
    drainingTimeoutSec: 60
  cdn:
    enabled: true
    cachePolicy:
      includeHost: true
      includeProtocol: true
      includeQueryString: false
```

#### Step 3.3: Deploy to GKE

```bash
# Create namespace
kubectl create namespace ecommerce

# Create secrets
kubectl create secret generic database-secrets \
  --from-literal=product-db-url="postgresql://..." \
  --from-literal=user-db-url="postgresql://..." \
  -n ecommerce

# Apply manifests
kubectl apply -f kubernetes/

# Verify deployment
kubectl get pods -n ecommerce
kubectl get svc -n ecommerce
kubectl get ingress -n ecommerce
```

---

## Complete Migration Checklist

### Pre-Migration

- [ ] Create GCP project
- [ ] Enable billing
- [ ] Enable required APIs
- [ ] Install gcloud SDK
- [ ] Install Terraform
- [ ] Set up authentication
- [ ] Review cost estimates

### Infrastructure Setup

- [ ] Create Terraform modules
- [ ] Configure backend (GCS)
- [ ] Create VPC network
- [ ] Create GKE cluster
- [ ] Create Artifact Registry
- [ ] Create service accounts
- [ ] Configure IAM roles
- [ ] Test Terraform apply

### CI/CD Setup

- [ ] Create Cloud Build configuration
- [ ] Set up GitHub integration
- [ ] Create build triggers
- [ ] Grant permissions
- [ ] Test build pipeline
- [ ] Configure notifications

### Application Migration

- [ ] Update Kubernetes manifests
- [ ] Update Docker registry URLs
- [ ] Configure Workload Identity
- [ ] Set up secrets
- [ ] Create ConfigMaps
- [ ] Deploy services
- [ ] Verify health checks

### DNS & SSL

- [ ] Update DNS records
- [ ] Configure Ingress
- [ ] Set up managed certificates
- [ ] Test HTTPS
- [ ] Enable CDN (optional)

### Monitoring & Logging

- [ ] Set up Cloud Monitoring
- [ ] Configure log aggregation
- [ ] Create dashboards
- [ ] Set up alerts
- [ ] Configure uptime checks

### Testing

- [ ] Functional testing
- [ ] Performance testing
- [ ] Security testing
- [ ] Disaster recovery testing

### Documentation

- [ ] Update architecture docs
- [ ] Document infrastructure
- [ ] Create runbooks
- [ ] Update team wiki

### Cleanup

- [ ] Verify everything works
- [ ] Decommission Azure resources
- [ ] Cancel Azure subscriptions
- [ ] Archive Azure documentation

---

## Cost Comparison & Optimization

### Estimated Monthly Costs

**Development Environment:**

```
GKE Cluster (2x e2-medium, preemptible): $30
Load Balancer: $18
Artifact Registry: $0.10/GB
Cloud Build: Free tier (120 min/day)
Cloud Monitoring: Free tier
Cloud Logging: First 50GB free
-----------------------------
Total: ~$50-70/month
```

**Production Environment:**

```
GKE Cluster (3x e2-standard-4): $150
Load Balancer: $18
Cloud SQL (db-n1-standard-1): $50
Memorystore Redis (1GB): $35
Artifact Registry: $2/GB
Cloud Build: $0.003/min
Monitoring & Logging: $50
-----------------------------
Total: ~$300-350/month
```

### Cost Optimization Tips

1. **Use Preemptible Nodes** (dev/staging)
2. **Enable Cluster Autoscaler**
3. **Use Spot VMs** for batch workloads
4. **Committed Use Discounts** (1-3 years)
5. **Resource Quotas** per namespace
6. **Clean up unused resources**
7. **Use Cloud Build free tier**
8. **Optimize image sizes**

---

## Summary: Azure vs GCP Tooling

| Need                   | Azure           | GCP               | Recommendation                            |
| ---------------------- | --------------- | ----------------- | ----------------------------------------- |
| **IaC**                | Bicep/ARM       | Terraform         | Use Terraform for portability             |
| **CI/CD**              | Azure Pipelines | Cloud Build       | Cloud Build (native integration)          |
| **Container Registry** | ACR             | Artifact Registry | Artifact Registry (modern)                |
| **Kubernetes**         | AKS             | GKE               | GKE (more K8s features)                   |
| **Secrets**            | Key Vault       | Secret Manager    | Secret Manager + Workload Identity        |
| **Monitoring**         | Azure Monitor   | Cloud Monitoring  | Cloud Monitoring (better K8s integration) |
| **Logging**            | Log Analytics   | Cloud Logging     | Cloud Logging (better for K8s)            |

**Key Takeaway:** GCP generally has better native Kubernetes integration, while Terraform provides the best IaC portability.
