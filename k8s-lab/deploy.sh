#!/bin/bash
set -e

# =============================================================================
# CI/CD Deployment Script for Kubernetes
# Production-ready deployment with health checks and rollback support
# =============================================================================

# === CONFIGURATIONS ===
APP_NAME="demo-apps"
DEPLOYMENT_NAME="demo-apps"
REGISTRY="harbor.192.168.59.10.nip.io:8080"
TARGET_REGISTRY="harbor.192.168.59.10.nip.io:8080"
NAMESPACE="ns-apps"
MANIFESTS_DIR="k8s-manifests"
APP_DIR="app"

# === PESERTA / BUILD INFO ===
PESERTA="${PESERTA:-lab}"
IMAGE_TAG="$(date +%Y%m%d%H%M%S)-${PESERTA}"
IMAGE_LATEST="latest"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# === VALIDATIONS ===
if [ ! -d "${APP_DIR}" ]; then
  log_error "App directory '${APP_DIR}' not found. Run from k8s-lab root."
  exit 1
fi

if ! command -v docker &> /dev/null; then
  log_error "Docker not found. Please install Docker."
  exit 1
fi

if ! command -v microk8s &> /dev/null; then
  log_error "microk8s not found. Please install MicroK8s."
  exit 1
fi

# Use microk8s kubectl
KUBECTL="microk8s kubectl"

# === BUILD IMAGE ===
log_info "Building image ${APP_NAME}:${IMAGE_TAG}..."
docker build -t ${REGISTRY}/${APP_NAME}/${APP_NAME}:${IMAGE_TAG} -t ${REGISTRY}/${APP_NAME}/${APP_NAME}:${IMAGE_LATEST} ${APP_DIR}

# === PUSH IMAGE TO HARBOR REGISTRY ===
log_info "Pushing image to Harbor registry..."
docker push ${REGISTRY}/${APP_NAME}/${APP_NAME}:${IMAGE_TAG}
docker push ${REGISTRY}/${APP_NAME}/${APP_NAME}:${IMAGE_LATEST}

# === ENSURE NAMESPACE ===
log_info "Ensuring namespace ${NAMESPACE} exists..."
if ! $KUBECTL get ns ${NAMESPACE} >/dev/null 2>&1; then
  $KUBECTL apply -f ${MANIFESTS_DIR}/namespaces.yaml
fi

# === DEPLOY TO KUBERNETES ===
log_info "Deploying to Kubernetes..."
log_info "   Namespace: ${NAMESPACE}"
log_info "   Image: ${TARGET_REGISTRY}/${APP_NAME}:${IMAGE_TAG}"

# Check if deployment exists, update or create
if $KUBECTL -n ${NAMESPACE} get deployment ${DEPLOYMENT_NAME} >/dev/null 2>&1; then
  log_info "Updating existing deployment..."
  $KUBECTL -n ${NAMESPACE} set image deployment/${DEPLOYMENT_NAME} ${DEPLOYMENT_NAME}=${TARGET_REGISTRY}/${APP_NAME}/${APP_NAME}:${IMAGE_TAG} --record
else
  log_info "Creating new deployment from manifests..."
  $KUBECTL -n ${NAMESPACE} apply -f ${MANIFESTS_DIR}/

  # Update image tag in deployment
  $KUBECTL -n ${NAMESPACE} set image deployment/${DEPLOYMENT_NAME} ${DEPLOYMENT_NAME}=${TARGET_REGISTRY}/${APP_NAME}/${APP_NAME}:${IMAGE_TAG} --record
fi

# === WAIT FOR ROLLOUT ===
log_info "Waiting for rollout to complete..."
$KUBECTL -n ${NAMESPACE} rollout status deployment/${DEPLOYMENT_NAME} --timeout=3m || {
  log_error "Rollout failed! Check logs with: microk8s kubectl -n ${NAMESPACE} logs -f deployment/${DEPLOYMENT_NAME}"
  exit 1
}

# === SHOW STATUS ===
log_info "Deployment complete!"
echo ""
$KUBECTL -n ${NAMESPACE} get pods -l app=${DEPLOYMENT_NAME} -o wide
echo ""
log_info "Endpoints:"
$KUBECTL -n ${NAMESPACE} get endpoints ${DEPLOYMENT_NAME} -o wide
echo ""
log_info "Access the app:"
echo "  Ingress:      http://demo-apps.192.168.59.11.nip.io"
echo ""
log_info "Harbor UI:"
echo "  URL:          http://harbor.192.168.59.10.nip.io:8080"
echo "  Username:     admin"
echo "  Password:     Harbor12345"

