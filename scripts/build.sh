#!/bin/bash

# OSC Config Build Script
# Builds all components locally for development

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OSC_CONFIG_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Build configuration
CONTAINER_TOOL=${CONTAINER_TOOL:-podman}
IMAGE_TAG=${IMAGE_TAG:-dev}
REGISTRY=${REGISTRY:-localhost}

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

# Check if git submodules are initialized
check_submodules() {
    log "Checking git submodules..."
    
    cd "$OSC_CONFIG_ROOT"
    
    if ! git submodule status | grep -q "^[[:space:]]"; then
        warn "Git submodules not initialized. Initializing now..."
        git submodule update --init --recursive
    fi
    
    success "Git submodules ready"
}

# Build CloudKit Operator
build_cloudkit_operator() {
    log "Building CloudKit Operator..."
    
    cd "$OSC_CONFIG_ROOT/components/cloudkit-operator"
    
    # Build the operator image
    if ! make image-build IMG="$REGISTRY/cloudkit-operator:$IMAGE_TAG"; then
        error "Failed to build CloudKit Operator"
    fi
    
    success "CloudKit Operator built successfully"
}

# Build Fulfillment Service
build_fulfillment_service() {
    log "Building Fulfillment Service..."
    
    cd "$OSC_CONFIG_ROOT/components/fulfillment-service"
    
    # Build the service image
    if [ -f "Containerfile" ]; then
        $CONTAINER_TOOL build -t "$REGISTRY/fulfillment-service:$IMAGE_TAG" -f Containerfile .
    elif [ -f "Dockerfile" ]; then
        $CONTAINER_TOOL build -t "$REGISTRY/fulfillment-service:$IMAGE_TAG" -f Dockerfile .
    else
        error "No Containerfile or Dockerfile found in fulfillment-service"
    fi
    
    success "Fulfillment Service built successfully"
}

# Build CloudKit AAP (just validation since it's Ansible)
build_cloudkit_aap() {
    log "Validating CloudKit AAP..."
    
    cd "$OSC_CONFIG_ROOT/components/cloudkit-aap"
    
    # Check if ansible-navigator is available for validation
    if command -v ansible-navigator >/dev/null 2>&1; then
        # Validate playbooks
        for playbook in playbook_*.yml; do
            if [ -f "$playbook" ]; then
                log "Validating $playbook..."
                ansible-navigator validate "$playbook" --mode stdout || warn "Validation issues in $playbook"
            fi
        done
    else
        warn "ansible-navigator not found. Skipping AAP validation."
    fi
    
    success "CloudKit AAP validation completed"
}

# Main build function
build_all() {
    log "Starting OSC Config build process..."
    log "Container tool: $CONTAINER_TOOL"
    log "Image tag: $IMAGE_TAG"
    log "Registry: $REGISTRY"
    
    check_submodules
    
    case "${1:-all}" in
        "cloudkit-operator"|"operator")
            build_cloudkit_operator
            ;;
        "fulfillment-service"|"fulfillment")
            build_fulfillment_service
            ;;
        "cloudkit-aap"|"aap")
            build_cloudkit_aap
            ;;
        "all")
            build_cloudkit_operator
            build_fulfillment_service
            build_cloudkit_aap
            ;;
        *)
            error "Unknown component: $1. Valid options: cloudkit-operator, fulfillment-service, cloudkit-aap, all"
            ;;
    esac
    
    success "Build process completed!"
}

# Show usage
show_usage() {
    cat << EOF
Usage: $0 [COMPONENT]

Build OSC Config components for local development

COMPONENTS:
  cloudkit-operator    Build only CloudKit Operator
  fulfillment-service  Build only Fulfillment Service  
  cloudkit-aap         Validate CloudKit AAP
  all                  Build all components (default)

ENVIRONMENT VARIABLES:
  CONTAINER_TOOL       Container tool to use (default: podman)
  IMAGE_TAG           Tag for built images (default: dev)
  REGISTRY            Registry prefix (default: localhost)

EXAMPLES:
  $0                                    # Build all components
  $0 cloudkit-operator                 # Build only operator
  IMAGE_TAG=latest $0                  # Build with latest tag
  CONTAINER_TOOL=docker $0             # Use docker instead of podman

EOF
}

# Parse command line arguments
case "${1:-}" in
    "-h"|"--help"|"help")
        show_usage
        exit 0
        ;;
    *)
        build_all "$1"
        ;;
esac