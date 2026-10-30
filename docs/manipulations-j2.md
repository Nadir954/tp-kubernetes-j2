# Manipulations intermédiaires J2

À lancer après `bash scripts/j2.sh h2`. Les commandes visent explicitement le cluster du TP.

```bash
alias k='kubectl --context=kind-formation'
# TP 2.1 : réconciliation
k create deployment nginx --image=nginx:1.27 --replicas=2
k rollout status deploy/nginx --timeout=180s
k get pods -o wide
k delete pod "$(k get pods -l app=nginx -o jsonpath='{.items[0].metadata.name}')"
k scale deploy/nginx --replicas=4
k rollout status deploy/nginx --timeout=180s
k get pods -o wide
k delete deploy/nginx
# Système et runtime
k get nodes -o wide
k get pods -n kube-system
k describe node formation-control-plane
docker exec formation-worker crictl ps
# TP 2.2 : image
docker history demo-modulith-sb4:0.0.1
docker exec formation-worker crictl images
# TP 2.3 : DNS et réconciliation
k run dns -n shop --image=busybox:1.37 --rm -i --restart=Never -- nslookup modulith.shop.svc.cluster.local
k delete pods -n shop -l app=modulith
k rollout status deploy/modulith -n shop --timeout=240s
# Relancer le port-forward, puis GET /coffees : H2 est vide.
# TP 2.4 : readiness incorrecte
k patch deploy/modulith -n shop --type=json -p='[{"op":"replace","path":"/spec/template/spec/containers/0/readinessProbe/httpGet/path","value":"/actuator/health/readinesss"}]'
# Attendre le démarrage de Java : le nouveau pod reste 0/1, l'ancien reste prêt.
k get pods -n shop -o wide
k get endpointslices -n shop -o yaml
# Dans les EndpointSlices, regarder aussi conditions.ready : un pod non prêt peut
# figurer dans la liste mais n'est pas une destination de trafic éligible.
k apply -f stages/h2-deployment.yaml
k rollout status deploy/modulith -n shop --timeout=240s
k rollout restart deploy/modulith -n shop
k rollout status deploy/modulith -n shop --timeout=240s
k get rs -n shop
k rollout undo deploy/modulith -n shop
k rollout status deploy/modulith -n shop --timeout=240s
k scale deploy/modulith -n shop --replicas=3
k rollout status deploy/modulith -n shop --timeout=240s
k run curl-h2 -n shop --image=curlimages/curl:8.12.1 --rm -i --restart=Never -- sh -ec 'curl -fsS -X POST "http://modulith/coffees?name=Arabica&price=5"; echo; for i in $(seq 1 10); do curl -fsS http://modulith/coffees; echo; done'
```

Passer ensuite à `bash scripts/j2.sh postgres`, puis `bash scripts/verify-postgres.sh`. Captures utiles : trois nœuds Ready, historique mini TP, pod non prêt et conditions des EndpointSlices, listes variables sous H2, listes stables sous Postgres, PVC Bound, données toujours présentes après remplacement des pods. FreeLens lit le kubeconfig ; choisir `kind-formation`, namespace `shop`.
