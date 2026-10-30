#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p preuves
exec > >(tee preuves/persistance.log) 2>&1
k() { kubectl --context=kind-formation -n shop "$@"; }
request() {
  k run "curl-$(date +%s)-$RANDOM" --image=curlimages/curl:8.12.1 --rm -i --restart=Never --command -- sh -ec "$1"
}
request 'curl -fsS -X POST "http://modulith/coffees?name=Arabica&price=5"; echo; for i in $(seq 1 10); do curl -fsS http://modulith/coffees; echo; done'
k exec deploy/postgres -- psql -U shop -d shop -c 'select * from coffee_entity; select * from stock_entity; select * from event_publication;'
before_count=$(k exec deploy/postgres -- psql -U shop -d shop -Atc "select count(*) from coffee_entity")
[[ "$before_count" -gt 0 ]]
k delete pod -l app=modulith
k delete pod -l app=postgres
k rollout status deployment/postgres --timeout=180s
k rollout status deployment/modulith --timeout=240s
request 'curl -fsS http://modulith/coffees; echo'
after_count=$(k exec deploy/postgres -- psql -U shop -d shop -Atc "select count(*) from coffee_entity")
[[ "$before_count" == "$after_count" ]]
echo "Persistance vérifiée : $after_count café(s) avant et après remplacement des pods."
