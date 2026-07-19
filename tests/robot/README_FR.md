# Tests fonctionnels Robot Framework pour les stream connectors

## Ce qui est testé

Contrairement aux tests unitaires busted (`modules/tests/`, qui mockent la table globale
`broker`) et au test de packaging (`tests/packaging/`, qui se contente de charger le
script du connecteur sans appeler `init`/`write`/`flush`), ces tests font tourner un
**vrai couple `centreon-engine` + `centreon-broker`** et pilotent un stream connector
exactement comme en production : le module de sortie `lua` de broker charge le script du
connecteur et lui transmet de vrais événements BBDO.

Périmètre actuel : uniquement les connecteurs « apiv2 » (le pattern moderne basé sur
`modules/centreon-stream-connectors-lib`). Deux connecteurs sont couverts pour l'instant :
`centreon-certified/splunk/splunk-events-apiv2.lua` (la suite pilote) et
`centreon-certified/canopsis/canopsis2x-events-apiv2.lua`.

## Comment la sortie est capturée

Quasiment tous les connecteurs apiv2 supportent un paramètre `send_data_test`
(`modules/centreon-stream-connectors-lib/sc_params.lua`, documenté dans
`modules/docs/sc_param.md`) : mis à `1`, le connecteur écrit le payload JSON qu'il aurait
envoyé à l'API externe dans son propre logfile, au lieu de faire le véritable appel HTTP.
La config broker utilisée ici (`tests/robot/config/broker/central-broker.json`) active
`send_data_test: 1` avec un `logfile` dédié : aucun serveur HTTP mock n'est donc
nécessaire — `tests/robot/resources/EngineBroker.py` se contente de lire ce fichier.

Les événements sont injectés en écrivant des lignes dans le fichier de commandes externes
de centreon-engine (`PROCESS_HOST_CHECK_RESULT`, `PROCESS_SERVICE_CHECK_RESULT`,
`ACKNOWLEDGE_SVC_PROBLEM`, `SCHEDULE_SVC_DOWNTIME`, ...) — le même mécanisme que celui
utilisé en production, sans avoir à réimplémenter un client BBDO.

### Tester plusieurs connecteurs

Chaque connecteur testé a sa propre config `tests/robot/config/broker/*.json` (son
propre output `lua`, son logfile `send_data_test`, ses paramètres obligatoires
spécifiques), et sa suite passe les deux à `Start Engine And Broker` :

```robotframework
Suite Setup    Start Engine And Broker    broker_config=/etc/centreon-broker/central-broker-canopsis.json
...            connector_logfile=/var/log/centreon-broker/canopsis-events-test.log
```

L'appeler sans arguments garde la config/le logfile de la suite pilote splunk (les deux
valeurs par défaut pointent dessus), donc les suites existantes n'ont pas eu besoin
d'être touchées quand le second connecteur a été ajouté. `EngineBroker.py` normalise
aussi la façon dont un payload est extrait : le format HEC de Splunk imbrique
l'événement formaté par le connecteur sous une clé `"event"`, alors que le
`build_payload` de Canopsis fait juste `table.insert(payload, event)` — un tableau JSON
brut à un seul élément. La fonction utilitaire `_extract_payload` de
`wait_for_sent_event` gère les deux formes, si bien que `${event}[payload][...]`
fonctionne pareil quel que soit le connecteur testé.

## Configuration engine et broker

La configuration statique se trouve sous `tests/robot/config/` et est copiée dans
l'image au moment du build (`/etc/centreon-engine/`, `/etc/centreon-broker/` — voir le
Dockerfile). Deux processus distincts tournent dans le conteneur, reliés comme dans une
installation Centreon réelle :

```
centengine  --(cbmod, BBDO/TCP :5669)-->  cbd
(config/engine/)                          (config/broker/central-broker.json)
                                              |
                                              +--> output lua --> splunk-events-apiv2.lua
                                                                     (send_data_test=1)
                                                                     --> logfile
```

### Le rôle de chaque fichier

| Fichier | Rôle |
|---|---|
| `config/engine/centengine.cfg` | Config principale d'engine : quels `cfg_file` charger ci-dessous, les directives `broker_module`/`broker_module_cfg_file` qui le relient à broker (voir plus bas), le chemin du fichier de commandes externes, la journalisation. |
| `config/engine/hosts.cfg` | Définit `host_1` — uniquement passif (`active_checks_enabled 0`), `max_check_attempts 1` (voir le piège plus bas). |
| `config/engine/services.cfg` | Définit `service_1` et `service_2` sur `host_1` — même schéma passif, `max_check_attempts 1`. |
| `config/engine/commands.cfg` | Une commande factice `check_dummy` (`/bin/true`), référencée par le host/les services ci-dessus car engine exige qu'un `check_command` soit défini pour chaque objet — jamais réellement exécutée puisque les checks sont passifs. |
| `config/engine/timeperiods.cfg` | Une seule plage horaire `24x7`, référencée par le host/les services (engine exige un `check_period` valide). |
| `config/engine/resource.cfg` | Macros globales d'engine (`$USER1$`, ...) — présent car `centengine.cfg` le référence via `resource_file`, effectivement vide pour nos besoins. |
| `config/engine/hostgroups.cfg`, `config/engine/connectors.cfg` | Vides, mais référencés via `cfg_file` dans `centengine.cfg` — les fichiers doivent exister même sans rien dedans. |
| `config/broker/central-module.json` | Config broker *embarquée dans le processus engine* (voir plus bas). |
| `config/broker/central-broker.json` | Config du démon `cbd` autonome pour la suite splunk, y compris l'output `lua` testé (voir plus bas). |
| `config/broker/central-broker-canopsis.json` | Pareil, mais pour la suite canopsis — son propre output/logfile `lua` et ses paramètres obligatoires spécifiques (`canopsis_host`, `canopsis_authkey`, ...). Voir « Tester plusieurs connecteurs » ci-dessus. |

- **`config/broker/central-module.json`** est la config broker *embarquée dans le
  processus engine* : elle n'a pas d'`input`, uniquement un `output` qui ouvre une
  connexion BBDO/TCP en clair vers `127.0.0.1:5669` (pas de TLS — tout tourne dans le
  même conteneur). Engine la charge via la directive `broker_module_cfg_file` dans
  `centengine.cfg`.
- **`config/broker/central-broker.json`** est le démon `cbd` autonome : il déclare
  l'`input` correspondant sur le port `5669`, plus l'`output` qui compte vraiment pour
  ces tests — un endpoint `"type": "lua"` pointant vers le script du connecteur,
  configuré avec `send_data_test`/`logfile` (voir « Comment la sortie est capturée »
  ci-dessus).
- **Piège du `lua_parameter`** : le parseur C++ de broker (`broker/lua/src/factory.cc`
  dans centreon-collect) n'accepte `lua_parameter` que sous forme d'un unique objet
  `{name, type, value}` ou d'un **tableau** de tels objets — pas un simple objet JSON
  `{"clé": "valeur"}`. `type` vaut `"string"`, `"password"` ou `"number"`, et même pour
  `"number"` la `value` doit rester une **chaîne** JSON (ex. `"1"`, pas `1`) — broker la
  lit d'abord comme une chaîne, puis la parse en nombre. Se tromper là-dessus fait
  planter `cbd` immédiatement avec `key 'name' not found`.

- **`config/engine/`** définit un host (`host_1`) et deux services (`service_1`,
  `service_2`), tous avec `active_checks_enabled 0` / `passive_checks_enabled 1` :
  aucun script de check réel n'est jamais exécuté, chaque statut provient des commandes
  externes que la librairie Python écrit dans
  `/var/lib/centreon-engine/rw/centengine.cmd` (`PROCESS_HOST_CHECK_RESULT`,
  `PROCESS_SERVICE_CHECK_RESULT`, `ACKNOWLEDGE_SVC_PROBLEM`, ...) — le même pipe de
  commandes qu'engine expose en production, sans avoir eu à réimplémenter un client
  BBDO.
- **Piège du `max_check_attempts 1`** : avec la valeur par défaut (3 tentatives ou
  plus), un seul résultat de check passif est un changement d'état *soft*, or
  `sc_event` ne transmet que les changements d'état *hard* — le connecteur ignorerait
  silencieusement chaque événement. Mettre `max_check_attempts 1` sur le host et les
  services fait que chaque résultat de check est immédiatement hard.
- `broker_module=/usr/lib64/centreon-engine/externalcmd.so` dans `centengine.cfg` est ce
  qui fait qu'engine écoute réellement sur le pipe de commandes externes ;
  `broker_module_cfg_file` (qui pointe vers `central-module.json`) est la directive
  séparée qui lui fait transmettre les événements BBDO vers broker — **uniquement sur
  la branche 25.10/26.10** (el8, el9, bookworm, trixie). Voir « Distributions supportées »
  ci-dessous : la branche 24.04/24.10 (bullseye, jammy, noble) a besoin d'une ligne
  `broker_module` supplémentaire à la place.

## Distributions supportées

Un Dockerfile par distribution sous `tests/robot/docker/`, correspondant aux
combinaisons OS/version Centreon packagées par ce repo (voir le `CLAUDE.md` racine) :

| Distribution | Dockerfile | Branche Centreon | Statut |
|---|---|---|---|
| AlmaLinux 9 (el9) | `Dockerfile.el9` | 25.10 | référence, service `docker compose` par défaut |
| AlmaLinux 8 (el8) | `Dockerfile.el8` | 25.10 | fonctionnel |
| AlmaLinux 10 (el10) | `Dockerfile.el10` | 26.10 | **pas encore utilisable** — le repo rpm Centreon correspondant n'existe pas (404) à l'heure où ces lignes sont écrites |
| Debian 11 (bullseye) | `Dockerfile.bullseye` | 24.04 | fonctionnel |
| Debian 12 (bookworm) | `Dockerfile.bookworm` | 25.10 | fonctionnel |
| Debian 13 (trixie) | `Dockerfile.trixie` | 26.10 | **pas encore utilisable** — le repo apt Centreon correspondant n'existe pas (404) à l'heure où ces lignes sont écrites |
| Ubuntu 22.04 (jammy) | `Dockerfile.jammy` | 24.04 | fonctionnel |
| Ubuntu 24.04 (noble) | `Dockerfile.noble` | 24.10 | fonctionnel |

Toutes installent de vrais paquets `centreon-engine`/`centreon-broker` depuis le repo
`unstable` de Centreon (même schéma de repo que
`.github/actions/test-packages/action.yml`), mais **pas la même version de Centreon** —
la branche associée à chaque distribution est décidée par les repos de paquets de
Centreon eux-mêmes, pas par nous. Cette différence de version compte ici car les deux
branches câblent engine → broker différemment :

- **Branche 25.10/26.10** (el8, el9, bookworm, trixie) : une simple directive
  `broker_module_cfg_file` dans `centengine.cfg` suffit ; il n'y a pas de paquet cbmod
  séparé.
- **Branche 24.04/24.10** (bullseye, jammy, noble) : la transmission des événements
  BBDO vers broker est un module chargeable distinct, fourni par le paquet
  `centreon-broker-cbmod` (`/usr/lib64/nagios/cbmod.so`), qui ne fait silencieusement
  rien tant que `centengine.cfg` n'a pas aussi une ligne explicite
  `broker_module=/usr/lib64/nagios/cbmod.so /etc/centreon-broker/central-module.json`
  — sans elle, engine démarre proprement et traite les commandes externes, mais aucun
  événement n'atteint jamais broker et chaque test finit simplement par un timeout en
  attendant un événement. Chacun de ces trois Dockerfiles ajoute cette ligne après
  avoir copié le `tests/robot/config/engine/centengine.cfg` partagé, plutôt que de
  dupliquer le fichier de config lui-même.

Deux autres pièges spécifiques à apt, rencontrés seulement en construisant les images
Debian/Ubuntu (corrigés dans les cinq Dockerfiles concernés, gardés ici car faciles à
réintroduire en copiant-collant) : le `70-lua.so` de `centreon-broker-core` charge
dynamiquement `liblua<ver>.so.0` à l'exécution mais ne déclare comme dépendance que
l'interpréteur `lua<ver>` (pas le paquet de bibliothèque partagée) — il faut installer
`liblua<ver>-0` explicitement, en utilisant la version renvoyée par
`lua -e "print(string.sub(_VERSION, 5))"` (fonctionne partout ici car le paquet
`lua<ver>` enregistre `/usr/bin/lua` via `update-alternatives`). De même, le
`lcurl.so` de `lua-curl` est lié à `libcurl.so.4` sans le déclarer comme dépendance non
plus — installer `libcurl4` explicitement aussi.

## Lancer les tests en local (Docker)

```bash
cd tests/robot

# Construire une distribution à la fois (ne reconstruit que ce qui a changé) ...
docker compose build robot-tests-bookworm
docker compose build robot-tests-jammy

# ... ou construire toutes les distributions d'un coup (el10/trixie exclus - voir
# « Distributions supportées » ci-dessus ; les nommer explicitement les construit
# quand même individuellement).
docker compose build

# Lancer la suite d'une seule distribution :
docker compose run --rm robot-tests             # AlmaLinux 9 (défaut/référence)
docker compose run --rm robot-tests-bookworm     # ou tout autre service du tableau ci-dessus

# Lancer toutes les distributions d'un coup, en parallèle, à partir des images déjà construites :
docker compose up
```

`docker compose up` démarre chaque service du profil par défaut (el10/trixie exclus,
comme pour `build`), chacun exécutant la commande par défaut de son image (la suite
complète sous `connectors/`), en entrelaçant leurs logs préfixés par le nom du
conteneur ; il se termine quand tous ont fini, avec un code de sortie par service. Il
**ne** reconstruit **pas** les images au préalable — lancez `docker compose build`
avant si vous avez modifié quelque chose.

Les rapports (`report.html`, `log.html`, `output.xml`) sont écrits dans
`tests/robot/results/<distribution>/` — un dossier séparé par distribution (`el9`,
`el8`, `bullseye`, ...), justement pour que des lancements parallèles via
`docker compose up` n'écrasent pas les résultats les uns des autres.

Pour itérer sur une suite sans reconstruire l'image, modifiez les fichiers sous
`tests/robot/{config,connectors,resources}/` — ils sont montés en volume — puis
relancez `docker compose run --rm <service>` (ou `up`). Si vous modifiez
`modules/centreon-stream-connectors-lib` ou `centreon-certified/` eux-mêmes,
reconstruisez d'abord l'image (ou les images), car ils sont copiés dans l'image au
moment du build, pas montés.

## Écrire un nouveau test

### Recette générale

1. **Choisir le scénario** : quel(s) événement(s) BBDO il lui faut (statut host/service,
   acquittement, downtime, ...), sur quel connecteur.
2. **Vérifier dans `tests/robot/resources/EngineBroker.py`** si le mot-clé dont vous
   avez besoin existe déjà. Sinon, l'ajouter : chaque mot-clé n'est qu'un fin wrapper
   qui écrit une ligne dans le pipe de commandes externes d'engine
   (`_write_external_command`). Trouver le nom exact de la commande et l'ordre des
   arguments dans `engine/src/commands/processing.cc` de centreon-collect (la table
   `"NOM_COMMANDE"` -> `CMD_XXX`) et `engine/src/commands/commands.cc` (la fonction
   `cmd_xxx` qui parse les arguments séparés par des points-virgules — lisez-la plutôt
   que de deviner l'ordre/le nombre d'arguments).
3. **Écrire le fichier `.robot`** : `Suite Setup    Start Engine And Broker` /
   `Suite Teardown    Stop Engine And Broker`, `Test Setup    Clear Connector Log`,
   puis pour chaque événement : l'envoyer, `Wait For Sent Event` (ou
   `Run Keyword And Expect Error` si vous vous attendez à ce qu'il soit supprimé),
   vérifier `${event}[payload][...]`. Passez `since_line=${evenement_precedent}[line]`
   pour qu'un `Wait For Sent Event` ultérieur dans le même test ne re-matche pas une
   ligne déjà vue.
4. **Itérer** : `docker compose build` une fois, puis
   `docker compose run --rm robot-tests robot --outputdir /opt/centreon-stream-connector-scripts/tests/robot/results /opt/centreon-stream-connector-scripts/tests/robot/connectors/votre_fichier.robot`
   pour ne lancer que votre nouveau fichier (plus rapide que tout le dossier
   `connectors/`). Un rebuild n'est nécessaire que si vous changez quelque chose sous
   `modules/` ou `centreon-certified/` (copié dans l'image au build) — modifier les
   fichiers `.robot`/`.py` eux-mêmes n'en a pas besoin, ils sont montés en volume.

### Technique de débogage quand un test ne se comporte pas comme prévu

Le timeout de `Wait For Sent Event` (10s par défaut) est un signal trop grossier pour
déboguer un nouveau scénario — il vous dit juste « rien n'est arrivé », pas pourquoi.
Passez plutôt par un shell manuel dans la même image, pour piloter engine/broker pas à
pas et lire les deux logs directement :

```bash
docker compose run --rm --entrypoint bash robot-tests -c '
/usr/sbin/cbd /etc/centreon-broker/central-broker.json &
sleep 2
/usr/sbin/centengine /etc/centreon-engine/centengine.cfg &
sleep 3
ts=$(date +%s)
echo "[$ts] VOTRE_COMMANDE;des;arguments;ici" > /var/lib/centreon-engine/rw/centengine.cmd
sleep 3
cat /var/log/centreon-engine/centengine.log
cat /var/log/centreon-broker/splunk-events-test.log
'
```

Ce qu'il faut chercher :
- `centengine.log` : `EXTERNAL COMMAND: ...` (votre commande a été parsée et acceptée —
  si absent, le nom de commande ou le nombre d'arguments est faux),
  `SERVICE ALERT`/`HOST ALERT` (un vrai changement d'état a eu lieu ; un check passif
  qui ne change pas l'état peut ne pas logguer cette ligne), `PASSIVE SERVICE CHECK`.
- le logfile propre au connecteur : les lignes `[EventQueue:xxx]` tracent le pipeline
  du connecteur ; `dropping event because element is not valid` et les lignes
  `WARNING`/`INFO` de `sc_event:is_valid_*` tracent les décisions de filtrage de
  `sc_event` — ce sont les lignes les plus utiles quand un événement statut/downtime/ack
  ne se comporte pas comme prévu, car elles disent précisément quel test l'a rejeté et
  pourquoi.

Si vous avez besoin de visibilité *à l'intérieur* de
`modules/centreon-stream-connectors-lib` lui-même (pas seulement de ce qu'il logue déjà),
ajoutez temporairement une ligne du type
`self.sc_logger:error("[TEMP DEBUG]: valeur=" .. tostring(ma_valeur))` exactement où
vous en avez besoin — `error()` est toujours loggué quel que soit `log_level`.
**Retirez-la avant de committer quoi que ce soit** — c'est du vrai code de bibliothèque
partagée, pas du code de test.

### Exemple travaillé : le test de rejeu après downtime (`connectors/downtime_replay.robot`)

Construit pour tester le mécanisme de `sc_event.lua` « ne pas envoyer immédiatement un
changement de statut survenu pendant un downtime ; le garder et le rejouer une fois le
downtime terminé ». Il passe sur les six distributions fonctionnelles. Deux choses
utiles à savoir ont été mises au jour en y arrivant, si vous touchez à ce test ou à la
fonctionnalité qu'il couvre :

1. **Le `storage_backend` compte.** Le backend par défaut
   (`storage_backends/sc_storage_broker.lua`) est un placeholder no-op explicite :
   chaque appel `set`/`get` « réussit » sans rien persister, silencieusement (confirmé
   avec une ligne de debug temporaire, voir ci-dessus, montrant que `get_multiple`
   renvoie toujours une table vide). La logique de rejeu a besoin que les données
   survivent entre l'événement de début de downtime et les événements ultérieurs
   (changement de statut/fin de downtime), donc `config/broker/central-broker.json`
   met `storage_backend=sqlite` spécifiquement sur cet output (porté par
   `storage_backends/sc_storage_sqlite.lua`), laissant tous les autres connecteurs sur
   la valeur par défaut.
2. **`sqlite` a besoin du paquet `lua-lsqlite3`**, publié dans les repos `rpm-plugins`/
   `apt-plugins` de Centreon — *pas* `rpm-standard`/`apt-standard`/`ubuntu-standard`,
   d'où viennent tous les autres paquets installés par ce harnais. Chaque Dockerfile
   configure les deux repos et installe `lua-lsqlite3` à côté de `lua-curl`. (Avant que
   ce paquet ne soit publié, mettre `storage_backend=sqlite` sans lui avait aussi mis
   au jour un bug dans le chemin de repli de `sc_storage.lua` lui-même : il essayait de
   `require` le même module manquant une seconde fois hors `pcall`, plantant tout le
   `init()` du connecteur au lieu de se dégrader proprement. Utile à savoir si un
   connecteur plante juste après un changement de `storage_backend`.)

`tests/robot/resources/EngineBroker.py` a aussi gagné `Schedule Host Downtime`,
`Delete Service Downtime` et `Delete Host Downtime` pendant la construction de ce test —
`Delete Service Downtime`/`Delete Host Downtime` utilisent `DEL_SVC_DOWNTIME_FULL`/
`DEL_HOST_DOWNTIME_FULL` (basés sur des critères : host/service, et tout le reste laissé
vide matche n'importe quel downtime pour ce host/service) plutôt que
`DEL_SVC_DOWNTIME`/`DEL_HOST_DOWNTIME`, qui ont besoin du `downtime_id` numérique
interne d'engine — quelque chose que ce harnais ne suit jamais.

### Exemple travaillé : le test canopsis (`connectors/canopsis_events_apiv2.robot`)

Deuxième connecteur ajouté au harnais, suivant globalement le même schéma que splunk
ci-dessus (config broker propre, logfile propre). Deux choses utiles à savoir :

1. **`accepted_elements` exclut volontairement `"downtime"`.** Le `EventQueue.new()` de
   `canopsis2x-events-apiv2.lua` fait de vrais appels HTTP bloquants à l'initialisation
   pour résoudre les IDs de raison/type de pbehavior et la version de Canopsis — mais
   seulement quand `canopsis_downtime_send_pbh ~= 0` (défaut `1`) **et** que
   `"downtime"` fait partie de `accepted_elements` (par défaut oui). Sous
   `send_data_test=1` ces appels s'interrompent proprement (ils ne bloquent pas et ne
   plantent pas), mais `canopsis_version` finit avec la valeur booléenne `false` (la
   valeur de retour du court-circuit) au lieu d'une vraie chaîne de version — et
   `format_event_downtime()` fait ensuite
   `string.find(canopsis_version, "22.10.")`, qui plante sur un booléen dès qu'un
   véritable événement downtime est formaté. La config de test
   (`central-broker-canopsis.json`) laisse `"downtime"` hors de `accepted_elements`
   (seulement host_status/service_status/acknowledgement) et met
   `canopsis_downtime_send_pbh=0` pour plus de clarté — ce qui évite tout le bloc
   d'appels API à l'initialisation et le crash, au prix de ne pas tester le downtime
   pour ce connecteur pour l'instant (voir « Ce qui n'est pas encore couvert »
   ci-dessous).
2. **Fuite d'état entre suites, visible uniquement quand plusieurs suites tournent
   dans le même conteneur.** Chaque `docker compose run --rm <service>` démarre un
   conteneur neuf, donc lancer une suite à la fois (ou via `docker compose up`, une
   suite par service) ne rencontre jamais ce problème. Mais le `CMD` par défaut de
   chaque Dockerfile lance *tout* le dossier `connectors/` en une seule invocation
   `robot` — le système de fichiers du même conteneur persiste à travers chaque cycle
   `Start Engine And Broker`/`Stop Engine And Broker` de chaque suite au sein de ce
   lancement. Deux fichiers sous `/var/lib/` survivent à une suite individuelle et
   fuient vers la suite suivante :
   - `/var/lib/centreon-broker/stream-connector-storage.sdb` — le fichier de base du
     backend de stockage sqlite (voir l'exemple travaillé downtime-replay ci-dessus) ;
     chaque config broker ici met `storage_backend=sqlite` sans surcharger
     `sc_storage.sqlite.db_file`, donc elles pointent toutes par défaut vers ce même
     chemin (`sc_params.lua`).
   - `/var/log/centreon-engine/retention.dat` — engine le recharge comme état *de
     départ* de chaque objet au démarrage suivant, indépendamment de
     `use_retained_program_state`/`use_retained_scheduling_info` dans
     `centengine.cfg` (ces réglages ne contrôlent que les paramètres globaux du
     programme et la planification des checks, pas l'état des objets). Une suite qui
     laisse par exemple `service_1` en CRITICAL (le dernier test de canopsis le fait)
     faisait démarrer l'engine de la suite suivante avec `service_1` déjà en CRITICAL
     au lieu du OK par défaut de la config, transformant silencieusement les checks de
     mise en base de cette suite en « transitions » no-op qui ne déclenchaient jamais
     de `SERVICE ALERT`/événement BBDO — ce qui se manifestait par des échecs parasites
     des tests service de `downtime_replay.robot` (« No event sent... ») qui ne se
     reproduisaient que quand la suite canopsis tournait en premier dans la même
     invocation `robot`.

   Corrigé en faisant supprimer ces deux fichiers par `Start Engine And Broker`, sans
   condition, avant de démarrer broker/engine, pour que chaque suite reparte toujours
   de la même ardoise vierge quel que soit ce qui a tourné avant elle dans le même
   conteneur — même principe que la réinitialisation déjà existante du fichier de
   commandes, juste pour ces deux éléments d'état en plus.

## Ce qui n'est pas encore couvert

- L'intégration CI (un workflow GitHub Actions) est volontairement une étape ultérieure,
  hors périmètre de cette première itération.
- `bigquery-events-apiv2.lua` ne supporte pas `send_data_test` et nécessitera une autre
  stratégie de capture.
- Seuls les événements host/service status sont réellement vérifiables pour splunk
  aujourd'hui : broker délivre bien l'acquittement/downtime en tant qu'élément BBDO à
  part entière, mais `accepted_elements` de ce connecteur ne liste que
  `host_status,service_status` — ces événements sont donc reçus puis filtrés avant
  d'atteindre `send_data` (voir le test « Acknowledging A Service Does Not Produce A
  Splunk Event »).
- Le downtime n'est pas testé pour canopsis — son `format_event_downtime()` plante sur
  un `canopsis_version` booléen sous `send_data_test=1` (voir l'exemple travaillé
  canopsis ci-dessus) ; le tester nécessite de corriger ce bug d'abord.
