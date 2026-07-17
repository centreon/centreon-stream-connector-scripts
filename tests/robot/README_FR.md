# Tests fonctionnels Robot Framework pour les stream connectors

## Ce qui est testé

Contrairement aux tests unitaires busted (`modules/tests/`, qui mockent la table globale
`broker`) et au test de packaging (`tests/packaging/`, qui se contente de charger le
script du connecteur sans appeler `init`/`write`/`flush`), ces tests font tourner un
**vrai couple `centreon-engine` + `centreon-broker`** et pilotent un stream connector
exactement comme en production : le module de sortie `lua` de broker charge le script du
connecteur et lui transmet de vrais événements BBDO.

Périmètre actuel : uniquement les connecteurs « apiv2 » (le pattern moderne basé sur
`modules/centreon-stream-connectors-lib`). La suite pilote couvre
`centreon-certified/splunk/splunk-events-apiv2.lua`.

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
  la branche 25.10/26.10** (el9, bookworm, trixie). Voir « Distributions supportées »
  ci-dessous : la branche 24.04/24.10 (bullseye, jammy, noble) a besoin d'une ligne
  `broker_module` supplémentaire à la place.

## Distributions supportées

Un Dockerfile par distribution sous `tests/robot/docker/`, correspondant aux
combinaisons OS/version Centreon packagées par ce repo (voir le `CLAUDE.md` racine) :

| Distribution | Dockerfile | Branche Centreon | Statut |
|---|---|---|---|
| AlmaLinux 9 (el9) | `Dockerfile.el9` | 25.10 | référence, service `docker compose` par défaut |
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

- **Branche 25.10/26.10** (el9, bookworm, trixie) : une simple directive
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
Debian/Ubuntu (corrigés dans les quatre Dockerfiles, gardés ici car faciles à
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
docker compose build              # construit l'image de chaque distribution
docker compose run --rm robot-tests             # AlmaLinux 9 (défaut/référence)
docker compose run --rm robot-tests-bookworm     # ou tout autre service du tableau ci-dessus
```

Les rapports (`report.html`, `log.html`, `output.xml`) sont écrits dans
`tests/robot/results/` (partagé entre distributions — relancez une suite avant de lire
le rapport si vous venez de changer de distribution).

Pour itérer sur une suite sans reconstruire l'image, modifiez les fichiers sous
`tests/robot/` — ils sont montés en volume — puis relancez
`docker compose run --rm <service>`. Si vous modifiez
`modules/centreon-stream-connectors-lib` lui-même, reconstruisez l'image
(`docker compose build`), car la bibliothèque est copiée dans le chemin Lua au moment du
build.

## Ce qui n'est pas encore couvert

- L'intégration CI (un workflow GitHub Actions) est volontairement une étape ultérieure,
  hors périmètre de cette première itération.
- `bigquery-events-apiv2.lua` ne supporte pas `send_data_test` et nécessitera une autre
  stratégie de capture.
- Seuls les événements host/service status sont réellement vérifiables pour ce
  connecteur aujourd'hui : broker délivre bien l'acquittement/downtime en tant
  qu'élément BBDO à part entière, mais `accepted_elements` de ce connecteur ne liste
  que `host_status,service_status` — ces événements sont donc reçus puis filtrés avant
  d'atteindre `send_data` (voir le test « Acknowledging A Service Does Not Produce A
  Splunk Event »).
