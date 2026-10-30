# Exécution du 30 octobre 2026

Environnement : Linux, Java 21, Docker 29.3.1. Les preuves enregistrent les sorties du terminal ; les heures du conteneur sont en UTC, le poste est en Europe/Paris.

- `maven-verify.log` : deux tests réussis, aucune erreur ; routes HTTP, stock effectivement créé, publication complétée, santé et frontières Modulith.
- `build-image.log` : image `demo-modulith-sb4:0.0.1` construite par buildpacks avec Java 21.
- `kind-cluster.log` et `kind-load.log` : cluster kind trois nœuds et image chargée.
- `j2-observations.log` : nœuds Ready, composants système, réconciliation Nginx, DNS, API H2, disparition des cafés après remplacement du pod, readiness incorrecte, rollback et listes variables avec trois bases H2.
- `j2-postgres.log` : déploiement final à trois pods, PVC Bound et connexion PostgreSQL.
- `persistance.log` : lectures via le Service, données café/stock/publication puis remplacement des pods applicatifs et Postgres et nouvelle lecture.
- `mini-tp.log` : trois nœuds minikube, versions Nginx, ReplicaSets, rollback et historique.
- `manifests-validation.log` : validation des manifests auprès de l'API Kubernetes avec `--dry-run=server`.

La CI GitHub Actions exécute aussi `mvn verify`.

## Incidents résolus

Minikube 1.37 a échoué lors de la jonction d'un worker. Le worker a été remplacé avec minikube 1.39 ; le troisième nœud fonctionnel porte donc le nom `tp-rs-m04` au lieu de `tp-rs-m03`. Les trois nœuds du cluster actif sont Ready.

La limite Linux `fs.inotify.max_user_instances=128` était insuffisante pour les clusters simultanés : kube-proxy échouait avec `too many open files`, ce qui empêchait le DNS depuis un worker. La valeur a été portée à 1024 à l'exécution, sans configuration persistante au redémarrage. Ce réglage concerne le poste hôte partagé par les conteneurs.

FreeLens et Bruno sont des clients graphiques : les vérifications ont été exécutées en ligne de commande avec kubectl et curl, sans capture de ces interfaces.

## Résultats finaux

Le mini TP s'est terminé avec trois pods `nginx:1.27` et deux anciens ReplicaSets à zéro (`1.23` et `1.25`). Le rollback a bien réutilisé le ReplicaSet `mon-site-5b67f86759`.

Le contrôle de persistance s'est terminé avec succès : **deux cafés avant et après remplacement des trois pods applicatifs et du pod Postgres**. Les publications observées sont `COMPLETED` et les stocks existent à quantité zéro. `etat-final.log` consigne trois pods Modulith prêts et le PVC Bound.

Le cluster minikube `tp-rs` est ensuite arrêté pour libérer les ressources ; `minikube start -p tp-rs` le redémarre. Le cluster kind `formation` reste disponible pour le rendu J2. Les outils téléchargés pour cette session sont dans `/tmp/tp-tools` (`export PATH=/tmp/tp-tools:$PATH`).
