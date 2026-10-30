#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p preuves
exec > >(tee preuves/mini-tp.log) 2>&1
if [[ ${SKIP_CLUSTER_START:-0} != 1 ]]; then
  minikube start -p tp-rs --driver=docker --nodes=3 --cpus=2 --memory=2g
fi
kubectl --context=tp-rs get nodes
k() { kubectl --context=tp-rs -n tp-rs "$@"; }
for tag in 1.23 1.25 1.27; do
  docker pull "nginx:$tag"
  minikube image load "nginx:$tag" -p tp-rs
done
k create namespace tp-rs --dry-run=client -o yaml | k apply -f -
k apply -f mini-tp/deployment.yaml
snapshot() {
  k rollout status deployment/mon-site --timeout=180s
  k get deploy,rs,pods -o wide
  k get rs -o 'custom-columns=NAME:.metadata.name,DESIRED:.spec.replicas,IMAGE:.spec.template.spec.containers[0].image'
  k rollout history deployment/mon-site
}
snapshot
k set image deployment/mon-site nginx=nginx:1.25
snapshot
k rollout undo deployment/mon-site
snapshot
k set image deployment/mon-site nginx=nginx:1.27
k annotate deployment/mon-site kubernetes.io/change-cause='passage en nginx 1.27' --overwrite
snapshot
k patch deployment/mon-site -p '{"spec":{"revisionHistoryLimit":2}}'
k get rs
# Pas de suppression automatique : garder le cluster pour les captures.
