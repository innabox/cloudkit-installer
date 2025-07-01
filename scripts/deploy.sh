#!/bin/bash

# OSC Config Deploy Script
# Deploys OSC platform to Kubernetes/OpenShift

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OSC_CONFIG_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Deploy configuration
KUBECTL_CMD=${KUBECTL_CMD:-kubectl}
ENVIRONMENT=${ENVIRONMENT:-development}

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
    exit 1
}

success() {
    echo -e "${GREEN}[SUCCESS] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

# Check if kubectl/oc is available and connected
check_kubectl() {
    log "Checking Kubernetes connection..."
    
    if ! command -v "$KUBECTL_CMD" >/dev/null 2>&1; then
        error "$KUBECTL_CMD not found. Please install kubectl or oc CLI"
    fi
    
    if ! $KUBECTL_CMD cluster-info >/dev/null 2>&1; then
        error "Cannot connect to Kubernetes cluster. Please check your kubeconfig"
    fi
    
    success "Kubernetes connection verified"
}

# Deploy a specific component
deploy_component() {
    local component=$1
    local overlay_path="$OSC_CONFIG_ROOT/overlays/$ENVIRONMENT/$component"
    
    if [ ! -d "$overlay_path" ]; then
        error "Component '$component' not found in environment '$ENVIRONMENT'"
    fi
    
    log "Deploying $component..."
    
    if ! $KUBECTL_CMD apply -k "$overlay_path"; then
        error "Failed to deploy $component"
    fi
    
    success "$component deployed successfully"
}

# Wait for deployment to be ready
wait_for_deployment() {
    local namespace=$1
    local deployment=$2
    local timeout=${3:-300}
    
    log "Waiting for deployment $deployment in namespace $namespace..."
    
    if ! $KUBECTL_CMD wait --for=condition=available deployment/"$deployment" -n "$namespace" --timeout="${timeout}s"; then
        warn "Deployment $deployment may not be fully ready"
    else
        success "Deployment $deployment is ready"
    fi
}

# Check deployment status
check_status() {
    log "Checking deployment status..."
    
    case "$ENVIRONMENT" in
        "development")
            local namespaces=("cloudkit-operator-dev" "fulfillment-service-dev" "cloudkit-aap-dev")
            ;;
        "production")
            local namespaces=("cloudkit-operator-system" "fulfillment-service-system" "cloudkit-aap-system")
            ;;
        *)
            error "Unknown environment: $ENVIRONMENT"
            ;;
    esac
    
    for ns in "${namespaces[@]}"; do
        if $KUBECTL_CMD get namespace "$ns" >/dev/null 2>&1; then
            log "Status for namespace: $ns"
            $KUBECTL_CMD get pods -n "$ns"
            echo
        fi
    done
}

# Deploy all components
deploy_all() {
    log "Starting OSC Config deployment..."
    log "Environment: $ENVIRONMENT"
    log "Kubectl command: $KUBECTL_CMD"
    
    check_kubectl
    
    # Deploy the entire environment
    local overlay_path="$OSC_CONFIG_ROOT/overlays/$ENVIRONMENT"
    
    if [ ! -d "$overlay_path" ]; then
        error "Environment '$ENVIRONMENT' not found"
    fi
    
    log "Deploying all components for $ENVIRONMENT environment..."
    
    if ! $KUBECTL_CMD apply -k "$overlay_path"; then
        error "Failed to deploy $ENVIRONMENT environment"
    fi
    
    success "All components deployed successfully"
    
    # Wait for key deployments
    case "$ENVIRONMENT" in
        "development")
            wait_for_deployment "cloudkit-operator-dev" "dev-controller-manager" 180
            wait_for_deployment "fulfillment-service-dev" "dev-fulfillment-service" 180
            ;;
        "production")
            wait_for_deployment "cloudkit-operator-system" "controller-manager" 300
            wait_for_deployment "fulfillment-service-system" "fulfillment-service" 300
            ;;
    esac
    
    check_status
}

# Undeploy components
undeploy() {
    log "Undeploying OSC Config..."
    
    local overlay_path="$OSC_CONFIG_ROOT/overlays/$ENVIRONMENT"
    
    if [ ! -d "$overlay_path" ]; then
        error "Environment '$ENVIRONMENT' not found"
    fi
    
    if ! $KUBECTL_CMD delete -k "$overlay_path"; then
        warn "Some resources may not have been deleted cleanly"
    fi
    
    success "OSC Config undeployed"
}

# Show usage
show_usage() {
    cat << EOF
Usage: $0 [COMMAND] [COMPONENT]

Deploy OSC Config platform to Kubernetes/OpenShift

COMMANDS:
  deploy               Deploy components (default)
  undeploy            Remove deployed components
  status              Show deployment status
  wait                Wait for deployments to be ready

COMPONENTS (for deploy command):
  cloudkit-operator    Deploy only CloudKit Operator
  fulfillment-service  Deploy only Fulfillment Service
  cloudkit-aap         Deploy only CloudKit AAP
  all                  Deploy all components (default)

ENVIRONMENT VARIABLES:
  ENVIRONMENT         Target environment: development, production (default: development)
  KUBECTL_CMD         Kubectl command to use (default: kubectl)

EXAMPLES:
  $0                                    # Deploy all to development
  $0 deploy cloudkit-operator          # Deploy only operator
  ENVIRONMENT=production $0             # Deploy all to production
  KUBECTL_CMD=oc $0                     # Use OpenShift CLI
  $0 status                            # Check deployment status
  $0 undeploy                          # Remove all deployments

EOF
}

# Parse command line arguments
COMMAND=${1:-deploy}
COMPONENT=${2:-all}

case "$COMMAND" in
    "deploy")
        case "$COMPONENT" in
            "cloudkit-operator"|"operator")
                deploy_component "cloudkit-operator"
                ;;
            "fulfillment-service"|"fulfillment")
                deploy_component "fulfillment-service"
                ;;
            "cloudkit-aap"|"aap")
                deploy_component "cloudkit-aap"
                ;;
            "all")
                deploy_all
                ;;
            *)
                error "Unknown component: $COMPONENT"
                ;;
        esac
        ;;
    "undeploy"|"remove"|"delete")
        undeploy
        ;;
    "status"|"check")
        check_kubectl
        check_status
        ;;
    "wait")
        check_kubectl
        case "$ENVIRONMENT" in
            "development")
                wait_for_deployment "cloudkit-operator-dev" "dev-controller-manager" 300
                wait_for_deployment "fulfillment-service-dev" "dev-fulfillment-service" 300
                ;;
            "production")
                wait_for_deployment "cloudkit-operator-system" "controller-manager" 300
                wait_for_deployment "fulfillment-service-system" "fulfillment-service" 300
                ;;
        esac
        ;;
    "-h"|"--help"|"help")
        show_usage
        exit 0
        ;;
    *)
        error "Unknown command: $COMMAND. Use '$0 --help' for usage information."
        ;;
esac