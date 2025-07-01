#!/bin/bash

# OSC Config Development Helper Script
# Complete development workflow: build, deploy, and manage local development

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OSC_CONFIG_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Development configuration
export ENVIRONMENT=development
export CONTAINER_TOOL=${CONTAINER_TOOL:-podman}
export IMAGE_TAG=${IMAGE_TAG:-dev}
export REGISTRY=${REGISTRY:-localhost}
export KUBECTL_CMD=${KUBECTL_CMD:-kubectl}

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

# Initialize development environment
init_dev() {
    log "Initializing OSC Config development environment..."
    
    cd "$OSC_CONFIG_ROOT"
    
    # Initialize git submodules
    log "Initializing git submodules..."
    git submodule update --init --recursive
    
    # Check prerequisites
    check_prerequisites
    
    success "Development environment initialized"
}

# Check development prerequisites
check_prerequisites() {
    log "Checking development prerequisites..."
    
    local missing_tools=()
    
    # Check container tool
    if ! command -v "$CONTAINER_TOOL" >/dev/null 2>&1; then
        missing_tools+=("$CONTAINER_TOOL")
    fi
    
    # Check kubectl/oc
    if ! command -v "$KUBECTL_CMD" >/dev/null 2>&1; then
        missing_tools+=("$KUBECTL_CMD")
    fi
    
    # Check kustomize
    if ! command -v kustomize >/dev/null 2>&1; then
        warn "kustomize not found. You can use 'kubectl apply -k' instead"
    fi
    
    # Check Go (for building)
    if ! command -v go >/dev/null 2>&1; then
        missing_tools+=("go")
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        error "Missing required tools: ${missing_tools[*]}"
    fi
    
    success "All prerequisites satisfied"
}

# Complete development workflow
dev_up() {
    log "Starting complete development workflow..."
    
    init_dev
    
    # Build all components
    log "Building all components..."
    "$SCRIPT_DIR/build.sh" all
    
    # Deploy to development environment
    log "Deploying to development environment..."
    "$SCRIPT_DIR/deploy.sh" deploy all
    
    success "Development environment is ready!"
    
    # Show connection information
    show_info
}

# Stop development environment
dev_down() {
    log "Stopping development environment..."
    
    "$SCRIPT_DIR/deploy.sh" undeploy
    
    success "Development environment stopped"
}

# Rebuild and redeploy a component
dev_update() {
    local component=${1:-all}
    
    log "Updating component: $component"
    
    # Build the component
    "$SCRIPT_DIR/build.sh" "$component"
    
    # Redeploy the component
    "$SCRIPT_DIR/deploy.sh" deploy "$component"
    
    success "Component $component updated"
}

# Show development environment information
show_info() {
    log "Development Environment Information"
    echo
    echo "=== Environment ==="
    echo "Environment: $ENVIRONMENT"
    echo "Container Tool: $CONTAINER_TOOL"
    echo "Image Tag: $IMAGE_TAG"
    echo "Registry: $REGISTRY"
    echo "Kubectl Command: $KUBECTL_CMD"
    echo
    
    echo "=== Services ==="
    if $KUBECTL_CMD get namespace cloudkit-operator-dev >/dev/null 2>&1; then
        echo "CloudKit Operator:"
        echo "  Namespace: cloudkit-operator-dev"
        echo "  Logs: $KUBECTL_CMD logs -n cloudkit-operator-dev deployment/dev-controller-manager -f"
    fi
    
    if $KUBECTL_CMD get namespace fulfillment-service-dev >/dev/null 2>&1; then
        echo "Fulfillment Service:"
        echo "  Namespace: fulfillment-service-dev"
        echo "  Logs: $KUBECTL_CMD logs -n fulfillment-service-dev deployment/dev-fulfillment-service -f"
        
        # Try to get service endpoint
        if $KUBECTL_CMD get service dev-fulfillment-service -n fulfillment-service-dev >/dev/null 2>&1; then
            local port_forward_cmd="$KUBECTL_CMD port-forward -n fulfillment-service-dev service/dev-fulfillment-service 8080:8080"
            echo "  HTTP API: $port_forward_cmd (then access http://localhost:8080)"
        fi
    fi
    
    echo
    echo "=== Useful Commands ==="
    echo "  Watch pods: $KUBECTL_CMD get pods -A -w"
    echo "  Dev status: $0 status"
    echo "  Update component: $0 update [component]"
    echo "  Stop environment: $0 down"
    echo
}

# Show logs for a component
show_logs() {
    local component=${1:-}
    
    if [ -z "$component" ]; then
        error "Please specify a component: cloudkit-operator, fulfillment-service"
    fi
    
    case "$component" in
        "cloudkit-operator"|"operator")
            $KUBECTL_CMD logs -n cloudkit-operator-dev deployment/dev-controller-manager -f
            ;;
        "fulfillment-service"|"fulfillment")
            $KUBECTL_CMD logs -n fulfillment-service-dev deployment/dev-fulfillment-service -f
            ;;
        *)
            error "Unknown component: $component"
            ;;
    esac
}

# Port forward to a service
port_forward() {
    local component=${1:-}
    local local_port=${2:-}
    
    case "$component" in
        "fulfillment-service"|"fulfillment")
            local_port=${local_port:-8080}
            log "Port forwarding fulfillment-service to localhost:$local_port"
            $KUBECTL_CMD port-forward -n fulfillment-service-dev service/dev-fulfillment-service "$local_port:8080"
            ;;
        *)
            error "Port forwarding not configured for component: $component"
            ;;
    esac
}

# Show usage
show_usage() {
    cat << EOF
Usage: $0 [COMMAND] [ARGS...]

OSC Config development helper script

COMMANDS:
  up                   Initialize, build, and deploy complete development environment
  down                 Stop and remove development environment
  init                 Initialize development environment (submodules, prerequisites)
  update [component]   Rebuild and redeploy component (default: all)
  status              Show development environment status
  info                Show connection and usage information
  logs [component]    Show logs for component
  port-forward [comp] [port]  Port forward to service
  
COMPONENTS:
  cloudkit-operator    CloudKit Operator
  fulfillment-service  Fulfillment Service
  cloudkit-aap         CloudKit AAP
  all                  All components

ENVIRONMENT VARIABLES:
  CONTAINER_TOOL       Container tool (default: podman)
  IMAGE_TAG           Image tag (default: dev)
  REGISTRY            Registry prefix (default: localhost)
  KUBECTL_CMD         Kubectl command (default: kubectl)

EXAMPLES:
  $0 up                        # Start complete dev environment
  $0 update cloudkit-operator  # Rebuild and redeploy operator
  $0 logs fulfillment-service  # Show fulfillment service logs
  $0 port-forward fulfillment  # Forward fulfillment service to localhost:8080
  $0 down                      # Stop dev environment

EOF
}

# Parse command line arguments
COMMAND=${1:-}

case "$COMMAND" in
    "up"|"start")
        dev_up
        ;;
    "down"|"stop")
        dev_down
        ;;
    "init"|"initialize")
        init_dev
        ;;
    "update"|"rebuild")
        dev_update "$2"
        ;;
    "status"|"check")
        "$SCRIPT_DIR/deploy.sh" status
        ;;
    "info"|"show")
        show_info
        ;;
    "logs"|"log")
        show_logs "$2"
        ;;
    "port-forward"|"forward")
        port_forward "$2" "$3"
        ;;
    "-h"|"--help"|"help"|"")
        show_usage
        exit 0
        ;;
    *)
        error "Unknown command: $COMMAND. Use '$0 --help' for usage information."
        ;;
esac