# J2 — Modulith dans Kubernetes et mini TP ReplicaSets

Réalisation à partir du [projet J1](https://github.com/Nadir954/tp-modulith), commit `a3132893283dd6eab4ac2b3247018ff2528df489`. Le code catalogue/stock et le flux `CoffeeCreated` du premier TP sont repris, puis complétés pour J2. Les deux énoncés sont dans `sujets/`. Le [bilan des vérifications](docs/execution.md) précise les exécutions et les incidents résolus. Le compte rendu et les réponses sont dans [docs/compte-rendu.md](docs/compte-rendu.md). Les journaux d'exécution sont dans `preuves/` lorsqu'une manipulation a été exécutée.

## Prérequis

Java 21, Docker démarré (10 Go disponibles pour J2), kubectl, kind >= 0.30, minikube et Bash. FreeLens permet d'observer les objets ; Bruno ou curl permettent d'appeler l'API. Éviter de faire tourner les deux clusters en même temps sur une machine limitée.

## Mini TP — à faire en premier

```bash
bash scripts/mini-tp.sh
# Dans un second terminal, pendant le script :
watch -n 1 'kubectl --context=tp-rs get deploy,rs,pods -n tp-rs -o wide'
```

Le script crée le cluster minikube trois nœuds et réalise `1.23 → 1.25 → rollback 1.23 → 1.27`, puis limite l'historique à deux anciens ReplicaSets. Il garde le cluster pour les captures. Pour rejouer intégralement : supprimer uniquement le Deployment `mon-site` dans `tp-rs` avant de relancer le script, sinon l'historique précédent est conservé.

```bash
minikube stop -p tp-rs
```

## J2 — application et déploiement

```bash
./mvnw verify
# TP 2.1–2.4 : cluster trois nœuds, buildpacks, application avec H2
bash scripts/j2.sh h2
kubectl --context=kind-formation -n shop port-forward svc/modulith 8080:80
```

Dans un autre terminal :

```bash
curl -fsS -X POST 'http://localhost:8080/coffees?name=Arabica&price=5'
curl -fsS http://localhost:8080/coffees
curl -fsS http://localhost:8080/stocks/1
curl -fsS http://localhost:8080/actuator/health/liveness
curl -fsS http://localhost:8080/actuator/health/readiness
```

Puis exécuter `bash scripts/observe-j2.sh` ou suivre [les manipulations J2](docs/manipulations-j2.md) pour observer la réconciliation, la readiness défaillante, le rollback et l'incohérence H2 à trois pods.

```bash
# TP 2.5 : même application, profil k8s, base partagée
bash scripts/j2.sh postgres
bash scripts/verify-postgres.sh
```

`k8s/` contient l'état final : namespace shop, trois pods Modulith, Service port 80 vers 8080, startup/liveness/readiness, Postgres 16 et PVC 1 Gi, Secret et ConfigMap. `stages/h2-deployment.yaml` conserve l'étape intermédiaire. Le schéma est initialisé par un seul pod avant la montée à trois afin d'éviter les créations concurrentes de tables.

Les identifiants `shop/s3cr3t` sont les valeurs pédagogiques du sujet pour le cluster local. Le PVC survit à la suppression du pod Postgres, mais pas à la suppression du cluster kind. Ne pas supprimer le PVC pendant le test de persistance.

## Choix d'implémentation

Spring Boot 4.1.2, Spring Modulith 2.1.2 et Java 21, conformément à J2. Les packages existants `org.formation.shop` sont conservés. Aucun Lombok n'est nécessaire : les constructeurs et getters du J1 sont déjà écrits. Le plugin Boot fabrique `demo-modulith-sb4:0.0.1` par buildpacks, sans Dockerfile.

Les tests vérifient les frontières Modulith, les routes HTTP, la création réelle du stock par événement, la complétion de la publication et les sondes. Un retour HTTP `0` sur le stock seul ne prouve pas que le listener a fonctionné : la route retourne aussi zéro si la ligne n'existe pas. Le test contrôle donc la base.
