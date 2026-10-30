#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mode=${1:-postgres}
[[ "$mode" == h2 || "$mode" == postgres ]] || { echo 'Usage: scripts/j2.sh [h2|postgres]'; exit 1; }
mkdir -p preuves
exec > >(tee "preuves/j2-$mode.log") 2>&1
if ! kind get clusters | grep -qx formation; then
  kind create cluster --name formation --config kind-cluster.yaml
fi
k() { kubectl --context=kind-formation -n shop "$@"; }
./mvnw verify spring-boot:build-image
kind load docker-image demo-modulith-sb4:0.0.1 --name formation
k apply -f k8s/namespace.yaml -f k8s/service.yaml
if [[ "$mode" == h2 ]]; then
  k apply -f stages/h2-deployment.yaml
else
  k apply -f k8s/db-secret.yaml -f k8s/db-config.yaml -f k8s/postgres-pvc.yaml -f k8s/postgres.yaml
  k rollout status deployment/postgres --timeout=180s
  # Initialiser le schéma avec un seul pod avant la montée à trois.
  sed 's/replicas: 3/replicas: 1/' k8s/deployment.yaml | k apply -f -
  k rollout status deployment/modulith --timeout=240s
  k apply -f k8s/deployment.yaml
fi
k rollout restart deployment/modulith
k rollout status deployment/modulith --timeout=240s
k get deploy,rs,pods,svc,pvc,endpointslices -o wide
