#!/usr/bin/env bash
set -eu

echo ">>> Starting Minikube with Docker driver..."
minikube start --driver=docker
minikube status

# Force builds into Minikube's Docker daemon
echo ">>> Configuring Docker to use Minikube's environment..."
eval "$(minikube -p minikube docker-env)"

# Build local images
IMAGES=("backend:latest" "transactions:latest" "studentportfolio:latest")
for img in "${IMAGES[@]}"; do
  name="${img%%:*}"
  echo ">>> Building image: ${img}"
  docker build -t "${img}" "./${name}"
done

# Verify images inside Minikube's Docker
echo ">>> Verifying images inside Minikube Docker..."
minikube ssh -- docker images | egrep 'backend|transactions|studentportfolio' || true

# Create required secrets (idempotent: re-applies if already exists)
echo ">>> Creating Kubernetes secrets..."
kubectl create secret generic backend-secret \
  --from-literal=secret-key=${BACKEND_SECRET_KEY:-defaultsecret} \
  --dry-run=client -o yaml | kubectl apply -f -

# Apply all manifests
echo ">>> Applying Kubernetes manifests..."
kubectl apply -f k8s/

# Restart deployments to pick up local images
echo ">>> Restarting deployments..."
kubectl rollout restart deploy backend transactions studentportfolio nginx

# Wait for pods to be ready
echo ">>> Waiting for pods to reach Ready state..."
# kubectl wait --for=condition=ready pod --all --timeout=300s --ignore-not-found

kubectl wait --for=condition=ready pod -l app=nginx --timeout=300s
kubectl wait --for=condition=ready pod -l app=backend --timeout=300s
kubectl wait --for=condition=ready pod -l app=transactions --timeout=300s
kubectl wait --for=condition=ready pod -l app=studentportfolio --timeout=300s


# Show pod status
echo ">>> Current pod status:"
kubectl get pods -o wide

# Show services
echo ">>> Current services:"
kubectl get svc



# Launch application
echo ">>> Launching application via Minikube service..."
minikube service nginx --url

