#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p preuves
exec > >(tee preuves/j2-observations.log) 2>&1
k() { kubectl --context=kind-formation "$@"; }
s() { k -n shop "$@"; }
request() { s run "curl-$(date +%s)-$RANDOM" --image=curlimages/curl:8.12.1 --rm -i --restart=Never --command -- sh -ec "$1"; }
k get nodes -o wide
k get pods -n kube-system
k describe node formation-control-plane
k create deployment nginx --image=nginx:1.27 --replicas=2
k rollout status deploy/nginx --timeout=180s
k get pods -o wide
k delete pod "$(k get pods -l app=nginx -o jsonpath='{.items[0].metadata.name}')"
k rollout status deploy/nginx --timeout=180s
k scale deploy/nginx --replicas=4
k rollout status deploy/nginx --timeout=180s
k get pods -o wide
k delete deploy/nginx
docker exec formation-worker crictl ps
docker history demo-modulith-sb4:0.0.1
s rollout status deploy/modulith --timeout=240s
s run dns --image=busybox:1.37 --rm -i --restart=Never -- nslookup modulith.shop.svc.cluster.local
request 'curl -fsS -X POST "http://modulith/coffees?name=Arabica&price=5"; echo; curl -fsS http://modulith/coffees; echo; curl -fsS http://modulith/stocks/1; echo'
s delete pods -l app=modulith
s rollout status deploy/modulith --timeout=240s
request 'curl -fsS http://modulith/coffees; echo'
s patch deploy/modulith --type=json -p='[{"op":"replace","path":"/spec/template/spec/containers/0/readinessProbe/httpGet/path","value":"/actuator/health/readinesss"}]'
# Attente bornée d'un pod qui tourne sans être prêt, au lieu d'un délai arbitraire.
for attempt in $(seq 1 60); do
  if s get pods -o json | python3 -c 'import json,sys; p=json.load(sys.stdin)["items"]; sys.exit(0 if any(x["status"].get("phase")=="Running" and any(c["name"]=="modulith" and not c.get("ready",False) for c in x["status"].get("containerStatuses",[])) for x in p) else 1)'; then break; fi
  sleep 2
done
s get pods -o wide
s get endpointslices -o yaml
s apply -f stages/h2-deployment.yaml
s rollout status deploy/modulith --timeout=240s
s rollout restart deploy/modulith
s rollout status deploy/modulith --timeout=240s
s get rs
s rollout undo deploy/modulith
s rollout status deploy/modulith --timeout=240s
s scale deploy/modulith --replicas=3
s rollout status deploy/modulith --timeout=240s
request 'curl -fsS -X POST "http://modulith/coffees?name=Arabica&price=5"; echo; for i in $(seq 1 10); do curl -fsS http://modulith/coffees; echo; done'
s get pods,svc,endpointslices -o wide
