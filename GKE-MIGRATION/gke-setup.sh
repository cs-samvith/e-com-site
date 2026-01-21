#!/bin/bash

# ============================================
# Complete GKE Setup Script
# Automates the entire GCP infrastructure setup
# ============================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=========================================="
echo "GCP/GKE Setup Script"
echo -e "==========================================${NC}"
echo ""

# ============================================
# Configuration
# ============================================

read -p "Enter GCP Project ID: " PROJECT_ID
read -p "Enter GCP Region (default: us-central1): " REGION
REGION=${REGION:-us-central1}

read -p "Enter Cluster Name (default: ecommerce-gke-dev): " CLUSTER_NAME
CLUSTER_NAME=${CLUSTER_NAME:-ecommerce-gke-dev}

read -p "Enter Environment (dev/staging/prod): " ENVIRONMENT
ENVIRONMENT=${ENVIRONMENT:-dev}

echo ""
echo -e "${BLUE}Configuration:${NC}"
echo "  Project ID: $PROJECT_ID"
echo "  Region: $REGION"
echo "  Cluster Name: $CLUSTER_NAME"
echo "  Environment: $ENVIRONMENT"
echo ""

read -p "Proceed with setup? (y/n): " CONFIRM
if [ "$CONFIRM" != "y" ]; then
    echo "Setup cancelled."
    exit 0
fi

# ============================================
# Step 1: Prerequisites Check
# ============================================

echo ""
echo -e "${BLUE}Step 1: Checking Prerequisites${NC}"

# Check gcloud
if ! command -v gcloud &> /dev/null; then
    echo -e "${RED}❌ gcloud not found. Please install Google Cloud SDK first.${NC}"
    echo "Visit: https://cloud.google.com/sdk/docs/install"
    exit 1
fi
echo -e "${GREEN}✅ gcloud found${NC}"

# Check kubectl
if ! command -v kubectl &> /dev/null; then
    echo -e "${YELLOW}⚠️  kubectl not found. Installing...${NC}"
    gcloud components install kubectl
fi
echo -e "${GREEN}✅ kubectl found${NC}"

# Check terraform
if ! command -v terraform &> /dev/null; then
    echo -e "${YELLOW}⚠️  terraform not found.${NC}"
    read -p "Install Terraform? (y/n): " INSTALL_TF
    if [ "$INSTALL_TF" = "y" ]; then
        # macOS
        if [[ "$OSTYPE" == "darwin"* ]]; then
            brew install terraform
        # Linux
        else
            wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
            echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
            sudo apt update && sudo apt install terraform
        fi
    else
        echo -e "${RED}❌ Terraform required for infrastructure setup${NC}"
        exit 1
    fi
fi
echo -e "${GREEN}✅ terraform found${NC}"

# ============================================
# Step 2: GCP Authentication
# ============================================

echo ""
echo -e "${BLUE}Step 2: GCP Authentication${NC}"

# Check if already authenticated
CURRENT_ACCOUNT=$(gcloud config get-value account 2>/dev/null)
if [ -z "$CURRENT_ACCOUNT" ]; then
    echo "Authenticating with GCP..."
    gcloud auth login
else
    echo -e "${GREEN}✅ Already authenticated as: $CURRENT_ACCOUNT${NC}"
fi

# Set default credentials for Terraform
gcloud auth application-default login

# ============================================
# Step 3: Create/Configure Project
# ============================================

echo ""
echo -e "${BLUE}Step 3: Project Setup${NC}"

# Check if project exists
if gcloud projects describe $PROJECT_ID &>/dev/null; then
    echo -e "${GREEN}✅ Project $PROJECT_ID exists${NC}"
else
    echo "Creating project $PROJECT_ID..."
    gcloud projects create $PROJECT_ID --name="E-commerce Learning Project"
    
    # Link billing
    BILLING_ACCOUNTS=$(gcloud billing accounts list --format="value(name)")
    if [ -z "$BILLING_ACCOUNTS" ]; then
        echo -e "${RED}❌ No billing accounts found${NC}"
        echo "Please set up billing at: https://console.cloud.google.com/billing"
        exit 1
    fi
    
    BILLING_ACCOUNT=$(echo "$BILLING_ACCOUNTS" | head -n 1)
    echo "Linking billing account: $BILLING_ACCOUNT"
    gcloud billing projects link $PROJECT_ID --billing-account=$BILLING_ACCOUNT
fi

# Set as default project
gcloud config set project $PROJECT_ID
echo -e "${GREEN}✅ Project configured${NC}"

# ============================================
# Step 4: Enable APIs
# ============================================

echo ""
echo -e "${BLUE}Step 4: Enabling Required APIs${NC}"

APIS=(
    "container.googleapis.com"
    "artifactregistry.googleapis.com"
    "cloudbuild.googleapis.com"
    "compute.googleapis.com"
    "secretmanager.googleapis.com"
    "cloudresourcemanager.googleapis.com"
    "logging.googleapis.com"
    "monitoring.googleapis.com"
    "dns.googleapis.com"
)

for API in "${APIS[@]}"; do
    echo "Enabling $API..."
    gcloud services enable $API
done

echo -e "${GREEN}✅ All APIs enabled${NC}"

# ============================================
# Step 5: Create Service Accounts
# ============================================

echo ""
echo -e "${BLUE}Step 5: Creating Service Accounts${NC}"

# Cloud Build service account
SA_EMAIL="cloudbuild-sa@${PROJECT_ID}.iam.gserviceaccount.com"
if gcloud iam service-accounts describe $SA_EMAIL &>/dev/null; then
    echo -e "${GREEN}✅ Service account already exists${NC}"
else
    echo "Creating Cloud Build service account..."
    gcloud iam service-accounts create cloudbuild-sa \
        --display-name="Cloud Build Service Account"
    
    # Grant roles
    gcloud projects add-iam-policy-binding $PROJECT_ID \
        --member="serviceAccount:$SA_EMAIL" \
        --role="roles/container.developer"
    
    gcloud projects add-iam-policy-binding $PROJECT_ID \
        --member="serviceAccount:$SA_EMAIL" \
        --role="roles/artifactregistry.writer"
fi

echo -e "${GREEN}✅ Service accounts configured${NC}"

# ============================================
# Step 6: Create Terraform Backend Bucket
# ============================================

echo ""
echo -e "${BLUE}Step 6: Creating Terraform Backend${NC}"

BUCKET_NAME="${PROJECT_ID}-terraform-state-${ENVIRONMENT}"

if gsutil ls -b gs://$BUCKET_NAME &>/dev/null; then
    echo -e "${GREEN}✅ Terraform state bucket already exists${NC}"
else
    echo "Creating GCS bucket for Terraform state..."
    gsutil mb -p $PROJECT_ID -l $REGION gs://$BUCKET_NAME
    gsutil versioning set on gs://$BUCKET_NAME
    echo -e "${GREEN}✅ Terraform state bucket created${NC}"
fi

# ============================================
# Step 7: Initialize Terraform
# ============================================

echo ""
echo -e "${BLUE}Step 7: Setting Up Terraform${NC}"

# Create infrastructure directory
INFRA_DIR="gcp-infrastructure"
if [ ! -d "$INFRA_DIR" ]; then
    mkdir -p $INFRA_DIR
fi
cd $INFRA_DIR

# Download or create Terraform files
read -p "Do you have Terraform files ready? (y/n): " HAS_TF_FILES
if [ "$HAS_TF_FILES" != "y" ]; then
    echo "Creating basic Terraform structure..."
    
    # Create directory structure
    mkdir -p modules/{gke,networking,artifact-registry}
    mkdir -p environments/$ENVIRONMENT
    
    # Create minimal configuration
    cat > environments/$ENVIRONMENT/main.tf <<EOF
# This is a placeholder. Please use the complete Terraform modules
# from the migration guide.

provider "google" {
  project = "$PROJECT_ID"
  region  = "$REGION"
}

# TODO: Add modules for:
# - VPC/Networking
# - GKE Cluster
# - Artifact Registry
# - Service Accounts
EOF
    
    cat > environments/$ENVIRONMENT/backend.tf <<EOF
terraform {
  backend "gcs" {
    bucket = "$BUCKET_NAME"
    prefix = "terraform/state"
  }
  
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
  
  required_version = ">= 1.6"
}
EOF
    
    cat > environments/$ENVIRONMENT/variables.tf <<EOF
variable "project_id" {
  description = "GCP Project ID"
  type        = string
  default     = "$PROJECT_ID"
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "$REGION"
}

variable "cluster_name" {
  description = "GKE Cluster name"
  type        = string
  default     = "$CLUSTER_NAME"
}
EOF
    
    echo -e "${YELLOW}⚠️  Terraform files created but need to be completed.${NC}"
    echo "Please refer to the migration guide for complete Terraform modules."
fi

# Initialize Terraform
cd environments/$ENVIRONMENT
terraform init

echo -e "${GREEN}✅ Terraform initialized${NC}"

# ============================================
# Step 8: Deploy Infrastructure
# ============================================

echo ""
echo -e "${BLUE}Step 8: Deploying Infrastructure${NC}"

read -p "Deploy infrastructure with Terraform? (y/n): " DEPLOY
if [ "$DEPLOY" = "y" ]; then
    echo "Planning Terraform deployment..."
    terraform plan -out=tfplan
    
    echo ""
    read -p "Apply this plan? (y/n): " APPLY
    if [ "$APPLY" = "y" ]; then
        terraform apply tfplan
        echo -e "${GREEN}✅ Infrastructure deployed${NC}"
    else
        echo "Deployment cancelled."
    fi
else
    echo "Skipping infrastructure deployment."
fi

# ============================================
# Step 9: Configure kubectl
# ============================================

echo ""
echo -e "${BLUE}Step 9: Configuring kubectl${NC}"

# Get cluster credentials
echo "Fetching GKE cluster credentials..."
gcloud container clusters get-credentials $CLUSTER_NAME \
    --region=$REGION \
    --project=$PROJECT_ID

# Verify connection
if kubectl get nodes &>/dev/null; then
    echo -e "${GREEN}✅ kubectl configured successfully${NC}"
    kubectl get nodes
else
    echo -e "${YELLOW}⚠️  Could not connect to cluster${NC}"
fi

# ============================================
# Step 10: Create Artifact Registry Repository
# ============================================

echo ""
echo -e "${BLUE}Step 10: Setting Up Artifact Registry${NC}"

REPO_NAME="ecommerce-repo"

if gcloud artifacts repositories describe $REPO_NAME \
    --location=$REGION &>/dev/null; then
    echo -e "${GREEN}✅ Artifact Registry repository already exists${NC}"
else
    echo "Creating Artifact Registry repository..."
    gcloud artifacts repositories create $REPO_NAME \
        --repository-format=docker \
        --location=$REGION \
        --description="Docker images for E-commerce application"
    echo -e "${GREEN}✅ Artifact Registry repository created${NC}"
fi

# Configure Docker
gcloud auth configure-docker ${REGION}-docker.pkg.dev

# ============================================
# Step 11: Set Up Cloud Build
# ============================================

echo ""
echo -e "${BLUE}Step 11: Setting Up Cloud Build${NC}"

read -p "Do you have a GitHub repository connected? (y/n): " HAS_REPO
if [ "$HAS_REPO" = "y" ]; then
    read -p "Enter GitHub repository owner: " REPO_OWNER
    read -p "Enter GitHub repository name: " REPO_NAME_GH
    
    echo "Creating Cloud Build trigger..."
    gcloud builds triggers create github \
        --name="${ENVIRONMENT}-build" \
        --repo-owner="$REPO_OWNER" \
        --repo-name="$REPO_NAME_GH" \
        --branch-pattern="^main$" \
        --build-config="cloudbuild.yaml" \
        --substitutions="_REGION=$REGION,_CLUSTER_NAME=$CLUSTER_NAME"
    
    echo -e "${GREEN}✅ Cloud Build trigger created${NC}"
else
    echo -e "${YELLOW}⚠️  Skipping Cloud Build setup${NC}"
    echo "You can set this up later at: https://console.cloud.google.com/cloud-build/triggers"
fi

# ============================================
# Step 12: Create Kubernetes Namespace
# ============================================

echo ""
echo -e "${BLUE}Step 12: Setting Up Kubernetes Namespace${NC}"

NAMESPACE="ecommerce"

if kubectl get namespace $NAMESPACE &>/dev/null; then
    echo -e "${GREEN}✅ Namespace already exists${NC}"
else
    echo "Creating namespace..."
    kubectl create namespace $NAMESPACE
    echo -e "${GREEN}✅ Namespace created${NC}"
fi

# ============================================
# Summary
# ============================================

echo ""
echo -e "${GREEN}=========================================="
echo "Setup Complete!"
echo -e "==========================================${NC}"
echo ""
echo "Your GCP infrastructure is ready!"
echo ""
echo -e "${BLUE}Configuration:${NC}"
echo "  Project ID: $PROJECT_ID"
echo "  Region: $REGION"
echo "  Cluster Name: $CLUSTER_NAME"
echo "  Namespace: $NAMESPACE"
echo ""
echo -e "${BLUE}Artifact Registry:${NC}"
echo "  Location: $REGION"
echo "  Repository: $REPO_NAME"
echo "  URL: ${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}"
echo ""
echo -e "${BLUE}Next Steps:${NC}"
echo "1. Update your Kubernetes manifests with new image URLs"
echo "2. Update your cloudbuild.yaml configuration"
echo "3. Push your code to trigger the first build"
echo "4. Deploy your application to GKE"
echo ""
echo -e "${BLUE}Useful Commands:${NC}"
echo "  # View cluster"
echo "  kubectl get nodes"
echo ""
echo "  # View namespaces"
echo "  kubectl get namespaces"
echo ""
echo "  # Build and push image"
echo "  docker build -t ${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/my-service:latest ."
echo "  docker push ${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/my-service:latest"
echo ""
echo "  # View Cloud Build logs"
echo "  gcloud builds list"
echo ""
echo "  # Access GCP Console"
echo "  https://console.cloud.google.com/kubernetes/list?project=${PROJECT_ID}"
echo ""
echo -e "${GREEN}Setup script completed successfully! 🎉${NC}"