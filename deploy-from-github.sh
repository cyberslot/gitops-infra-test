#!/bin/bash
# deploy-from-github.sh
# One-liner script to deploy Kargo from GitHub repository
# Usage: curl -s https://raw.githubusercontent.com/your-org/your-repo/main/argocd-appset/deploy-from-github.sh | bash

set -euo pipefail

# Configuration
REPO_URL="https://github.com/your-org/your-repo"  # CHANGE THIS
BRANCH="main"
SCRIPT_PATH="argocd-appset/generate-kargo-applicationset.sh"
TEMP_DIR="/tmp/kargo-deploy-$$"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

# Functions
log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

cleanup() {
    log "Cleaning up temporary files..."
    rm -rf "$TEMP_DIR"
}

trap cleanup EXIT

# Main execution
main() {
    log "🚀 Starting Kargo deployment from GitHub..."
    
    # Check dependencies
    log "Checking dependencies..."
    command -v git >/dev/null 2>&1 || error "git is required but not installed"
    command -v kubectl >/dev/null 2>&1 || error "kubectl is required but not installed"
    command -v openssl >/dev/null 2>&1 || error "openssl is required but not installed"
    command -v htpasswd >/dev/null 2>&1 || error "htpasswd is required but not installed"
    
    # Clone repository
    log "Cloning repository..."
    git clone --branch "$BRANCH" --depth 1 "$REPO_URL" "$TEMP_DIR"
    
    # Verify script exists
    if [[ ! -f "$TEMP_DIR/$SCRIPT_PATH" ]]; then
        error "Script not found at $SCRIPT_PATH"
    fi
    
    # Make script executable
    chmod +x "$TEMP_DIR/$SCRIPT_PATH"
    
    # Execute deployment
    log "🔐 Generating Kargo credentials and deploying ApplicationSet..."
    cd "$TEMP_DIR/$(dirname "$SCRIPT_PATH")"
    ./$(basename "$SCRIPT_PATH") | kubectl apply -f -
    
    log "✅ Kargo ApplicationSet deployed successfully!"
    
    # Verify deployment
    log "🔍 Verifying deployment..."
    if kubectl get applicationset infra-apps -n argocd >/dev/null 2>&1; then
        log "✅ ApplicationSet created successfully"
    else
        warn "ApplicationSet not found - deployment may still be in progress"
    fi
    
    # Show status
    log "📊 Current status:"
    kubectl get applicationset infra-apps -n argocd 2>/dev/null || warn "ApplicationSet not yet available"
    kubectl get applications -n argocd 2>/dev/null || warn "Applications not yet available"
    
    log "🎉 Deployment complete!"
    log "ℹ️  Check the kubectl logs above for the generated admin password"
    log "ℹ️  Monitor deployment: kubectl get applications -n argocd -w"
}

# Handle command line arguments
case "${1:-}" in
    --help|-h)
        echo "Usage: $0 [--help]"
        echo ""
        echo "Deploy Kargo from GitHub repository with generated credentials"
        echo ""
        echo "Environment variables:"
        echo "  REPO_URL    - GitHub repository URL (default: $REPO_URL)"
        echo "  BRANCH      - Git branch to use (default: $BRANCH)"
        echo ""
        echo "Example:"
        echo "  curl -s https://raw.githubusercontent.com/your-org/your-repo/main/argocd-appset/deploy-from-github.sh | bash"
        echo "  REPO_URL=https://github.com/custom/repo bash deploy-from-github.sh"
        exit 0
        ;;
    *)
        # Override defaults with environment variables if provided
        REPO_URL="${REPO_URL:-$REPO_URL}"
        BRANCH="${BRANCH:-$BRANCH}"
        main
        ;;
esac
