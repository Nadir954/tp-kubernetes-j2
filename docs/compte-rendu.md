# Compte rendu — mini TP et J2

Les résultats attendus ci-dessous expliquent les manipulations ; seuls les fichiers de `preuves/` attestent des exécutions effectivement réalisées. Aucun nom de pod ou capture fictive n'est présenté comme une observation.

## Mini TP — ReplicaSets

Un Deployment pilote les ReplicaSets ; chaque ReplicaSet maintient les pods d'un modèle donné. Le changement d'image modifie le template et entraîne une nouvelle version. Modifier `minReadySeconds`, la stratégie ou la limite d'historique ne modifie pas le template et ne crée pas de ReplicaSet.

| Opération | ReplicaSets attendus | Version active |
| --- | --- | --- |
| Création | 1 | nginx:1.23, 3 pods |
| Mise à jour | 2 | nginx:1.25, 3 pods ; 1.23 à zéro |
| Rollback | 2 | ancien ReplicaSet 1.23 réactivé |
| Nouvelle version | 3 | nginx:1.27, 3 pods ; anciens à zéro |

`maxSurge: 1` permet au maximum quatre pods pour trois demandés ; `maxUnavailable: 1` tolère deux pods disponibles pendant la transition. `minReadySeconds: 5` exige cinq secondes de disponibilité avant de poursuivre. Le rollback promeut l'ancien template à une nouvelle révision : le numéro de révision n'est pas la version Nginx. `revisionHistoryLimit: 2` conserve deux anciens ReplicaSets en plus de l'actif ; les trois restent donc présents ici.

Le mini TP éclaire directement les mises à jour et retours arrière du TP 2.4 ; il n'est pas une dépendance technique du cluster kind.

## TP 2.1 — Cluster et réconciliation

Le cluster comporte un control plane et deux workers. L'API server reçoit les demandes de kubectl et de FreeLens ; etcd conserve l'état ; le scheduler choisit les nœuds ; les contrôleurs réconcilient l'état désiré. Le kubelet de chaque nœud pilote les conteneurs via containerd. Les nœuds kind sont eux-mêmes des conteneurs Docker. Le control plane kind porte une taint qui empêche le placement des applications ordinaires.

Supprimer un pod ne supprime pas l'intention déclarée : son ReplicaSet le remplace. Modifier le nombre de répliques modifie l'état désiré. Supprimer le Deployment supprime ses objets dépendants.

## TP 2.2 — Image

Le pom cible Boot 4.1.2, Modulith 2.1.2 et Java 21. Les versions existent : [Boot](https://spring.io/blog/2026/10/23/spring-boot-4-1-2-available-now/), [Modulith](https://spring.io/blog/2026/10/23/spring-modulith-2-2-rc1-2-1-2-2-0-9-and-1-4-14-released/).

Les buildpacks créent l'image par couches et configurent le JVM 21. L'image du Docker hôte n'est pas automatiquement visible par containerd dans les nœuds : `kind load docker-image` la copie. `IfNotPresent` utilise cette image locale. Lorsqu'on reconstruit sous le même tag, on recharge puis on redémarre le Deployment.

## TP 2.3 — API et Service

`POST /coffees` publie `CoffeeCreated` ; inventory crée une ligne de stock à zéro après commit. `GET /coffees` expose des vues publiques `CoffeeView`, sans exposer les entités internes. `GET /stocks/{coffeeId}` lit le stock. Les tests de modularité empêchent l'accès à l'intérieur d'un autre module.

Le Service sélectionne `app: modulith` et transmet le port 80 au port 8080. CoreDNS résout `modulith.shop.svc.cluster.local`. Le port-forward rend l'API accessible sur localhost. Avec H2 en mémoire, supprimer le pod fait disparaître ses données.

## TP 2.4 — Sondes, rollback, trois pods

La startup probe laisse jusqu'à 150 secondes pour démarrer. La liveness décide du redémarrage, sans dépendre de Postgres. La readiness contrôle l'éligibilité au trafic. Une readiness vers `/actuator/health/readinesss` échoue et garde le nouveau pod non prêt ; avec `maxUnavailable: 0`, les anciens pods continuent de servir. Corriger le chemin permet au déploiement de terminer.

Un rollout modifie le template et crée un ReplicaSet ; un rollback peut réactiver un modèle existant. Trois pods avec trois bases H2 indépendantes donnent des listes différentes selon le destinataire du POST et des GET. Les requêtes doivent être faites depuis un pod curl via le Service ; chaque connexion peut alors être routée vers un autre pod. Une série courte ne garantit pas de visiter chaque pod.

## TP 2.5 — Postgres et persistance

Le profil k8s utilise `ddl-auto=update` : `create-drop` effacerait le schéma partagé. L'URL provient de la ConfigMap, les identifiants du Secret. Le Service postgres fournit un nom DNS stable. Le PVC stocke les données au-delà de la vie du pod ; `PGDATA` vise un sous-dossier. Une stratégie `Recreate` évite deux instances Postgres concurrentes sur le même volume lors d'une modification.

Les trois pods lisent désormais les mêmes tables. Après suppression et recréation des pods applicatifs et Postgres, le café reste présent. La table `event_publication` permet de vérifier la complétion de l'événement, avec `coffee_entity` et `stock_entity`. `update` convient à ce TP ; une application déployée durablement utiliserait des migrations contrôlées.

## Réponses aux questions J2

1. **Pourquoi le Service ne connaît pas les pods à l'avance ?** Ses selectors décrivent les labels recherchés. Les EndpointSlices sont actualisées quand les pods apparaissent, changent d'adresse ou deviennent non prêts ; le client garde l'adresse stable du Service.
2. **Pourquoi le port-forward ne démontre pas l'équilibrage ?** Le tunnel est attaché à un pod choisi. Pour observer la distribution, appeler le Service depuis le cluster avec plusieurs connexions.
3. **Si la liveness vérifiait Postgres ?** Une panne de base ferait redémarrer les applications saines, sans réparer la base, et pourrait provoquer une boucle de redémarrages. La liveness doit porter sur la vie du processus.
4. **Une base partagée suffit-elle pour des microservices ?** Non. Il faut séparer la propriété des données et les schémas, définir les API et contrats événementiels, remplacer les événements locaux par une messagerie, prévoir l'idempotence, les reprises et la cohérence éventuelle. Le registre des événements aide la fiabilité mais ne remplace pas ces décisions.
