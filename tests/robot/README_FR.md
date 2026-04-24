# Tests des Stream Connectors — Robot Framework

- [Vue d'ensemble](#vue-densemble)
- [Prérequis](#prérequis)
- [Structure des répertoires](#structure-des-répertoires)
- [Lancer les tests](#lancer-les-tests)
- [Écrire une nouvelle suite de tests](#écrire-une-nouvelle-suite-de-tests)
  - [1. Créer les fichiers JSON d'événements](#1-créer-les-fichiers-json-dévénements)
  - [2. Créer le fichier .robot](#2-créer-le-fichier-robot)
  - [3. Assertions utiles](#3-assertions-utiles)
  - [4. Surcharger les paramètres du connecteur](#4-surcharger-les-paramètres-du-connecteur)
  - [5. Fournir des fixtures de cache broker](#5-fournir-des-fixtures-de-cache-broker)
- [Fonctionnement du runner de tests](#fonctionnement-du-runner-de-tests)
- [Référence du mock broker](#référence-du-mock-broker)

---

## Vue d'ensemble

Ces tests valident les stream connectors (scripts Lua) **sans** Centreon Broker en cours d'exécution.
Un runner léger (`sc_runner.lua`) charge un connecteur, lui injecte un événement BBDO synthétique
(depuis un fichier JSON), et capture le payload que le connecteur aurait envoyé à sa destination.

Les globaux Lua de Centreon Broker (`broker`, `broker_log`, `broker_cache`) sont fournis par
`broker_mock.lua` : aucune installation Centreon n'est nécessaire.

Les tests sont écrits avec [Robot Framework](https://robotframework.org/) et s'exécutent dans un
conteneur Docker qui fournit Lua 5.3, `lua-cjson` et `robotframework`.

---

## Prérequis

Construire l'image Docker une fois depuis la racine du dépôt :

```bash
docker build \
  --build-arg REGISTRY_URL=docker.io/library \
  -t testing-stream-connector-bookworm \
  -f .github/docker/Dockerfile.testing-stream-connectors-bookworm \
  .
```

> **Note :** `REGISTRY_URL=docker.io/library` utilise l'image de base publique `debian:bookworm`.
> Dans la CI Centreon, omettre cet argument pour utiliser l'image de base Centreon privée, ou
> passer `CENTREON_REPO=<url>` pour installer les paquets officiels `centreon-stream-connectors-lib`
> et `centreon-broker`.

---

## Structure des répertoires

```
tests/robot/
├── README_EN.md                    # ce fichier (anglais)
├── README_FR.md                    # ce fichier (français)
├── variables.robot                 # variables Robot partagées (chemins)
├── resources/
│   ├── broker_mock.lua             # mock des globaux broker, broker_log, broker_cache
│   └── sc_runner.lua               # runner : charge le connecteur et injecte l'événement
└── suites/
    └── <nom-du-connecteur>/
        ├── <nom-du-connecteur>.robot  # suite de tests Robot
        └── events/
            ├── host_down.json         # fixtures d'événements BBDO
            ├── service_critical.json
            └── service_ok.json
```

Chaque connecteur dispose de son propre sous-répertoire dans `suites/`.

---

## Lancer les tests

**Lancer toutes les suites :**

```bash
docker run --rm \
  -v "$(pwd):/repo" \
  -w /repo/tests/robot \
  testing-stream-connector-bookworm \
  robot --outputdir /tmp/robot-results suites/
```

**Lancer une seule suite :**

```bash
docker run --rm \
  -v "$(pwd):/repo" \
  -w /repo/tests/robot \
  testing-stream-connector-bookworm \
  robot --outputdir /tmp/robot-results suites/datadog/
```

**Lancer un cas de test précis par son nom :**

```bash
docker run --rm \
  -v "$(pwd):/repo" \
  -w /repo/tests/robot \
  testing-stream-connector-bookworm \
  robot --test "Host DOWN should produce a valid Datadog payload" \
        --outputdir /tmp/robot-results suites/
```

Robot Framework écrit `output.xml`, `log.html` et `report.html` dans le `--outputdir`.
Pour lire ces fichiers en dehors du conteneur, monter un répertoire hôte à la place de
`/tmp/robot-results` :

```bash
mkdir -p /tmp/rf-results
docker run --rm \
  -v "$(pwd):/repo" \
  -v "/tmp/rf-results:/results" \
  -w /repo/tests/robot \
  testing-stream-connector-bookworm \
  robot --outputdir /results suites/
# puis ouvrir /tmp/rf-results/report.html dans un navigateur
```

---

## Écrire une nouvelle suite de tests

### 1. Créer les fichiers JSON d'événements

Créer `tests/robot/suites/<connecteur>/events/` et ajouter un fichier JSON par scénario.

Un fichier JSON de fixture est un événement BBDO brut tel que Centreon Broker le passerait
à la fonction `write()`. Les champs requis varient selon le type d'événement :

**Événement host status** (`_type: 65550`, `category: 1`, `element: 14`) :

```json
{
  "_type": 65550,
  "category": 1,
  "element": 14,
  "host_id": 1,
  "service_id": 0,
  "state": 1,
  "state_type": 1,
  "output": "CRITICAL - Host is unreachable",
  "last_check": 1700000000,
  "last_state_change": 1700000000,
  "last_hard_state_change": 1700000000,
  "last_hard_state": 1,
  "scheduled_downtime_depth": 0,
  "acknowledged": false
}
```

**Événement service status** (`_type: 65563`, `category: 1`, `element: 24`) :

```json
{
  "_type": 65563,
  "category": 1,
  "element": 24,
  "host_id": 1,
  "service_id": 1,
  "state": 2,
  "state_type": 1,
  "output": "CRITICAL - Service is down",
  "perfdata": "rta=100ms;50;200;0",
  "last_check": 1700000000,
  "last_state_change": 1700000000,
  "last_hard_state_change": 1700000000,
  "last_hard_state": 2,
  "scheduled_downtime_depth": 0,
  "acknowledged": false
}
```

> **Note sur la déduplication :** La bibliothèque stream connector déduplique les événements
> en comparant `last_hard_state_change` et `last_check`. Donner la même valeur aux deux champs
> pour éviter que l'événement soit silencieusement supprimé par le filtre de déduplication.

Valeurs d'état courantes :
- Host : `0` = UP, `1` = DOWN, `2` = UNREACHABLE
- Service : `0` = OK, `1` = WARNING, `2` = CRITICAL, `3` = UNKNOWN

---

### 2. Créer le fichier .robot

Créer `tests/robot/suites/<connecteur>/<connecteur>.robot` :

```robotframework
*** Settings ***
Resource          ../../variables.robot
Library           Process
Library           String

*** Variables ***
${CONNECTOR}    ${CONNECTORS_DIR}/<connecteur>/<script>.lua
${EVENTS_DIR}   ${CURDIR}/events

*** Test Cases ***
Service CRITICAL should produce a valid payload
    ${result}=    Run Process
    ...    lua    ${RUNNER}    ${CONNECTOR}    ${EVENTS_DIR}/service_critical.json
    ...    api_key\=fake_key
    Should Be Equal As Integers    ${result.rc}    0
    Should Contain    ${result.stdout}    [send_data]:
    Should Contain    ${result.stdout}    CRITICAL
```

L'appel `Run Process` invoque :
```
lua sc_runner.lua <connector.lua> <event.json> [cle=valeur ...]
```

Le connecteur s'exécute avec `send_data_test=1` (aucun appel HTTP réel).
Lorsque le connecteur envoie des données, il journalise une ligne de la forme :
```
[NOTICE] [send_data]: <payload-json>
```

---

### 3. Assertions utiles

| Objectif | Keyword Robot |
|---|---|
| L'événement a été envoyé | `Should Contain    ${result.stdout}    [send_data]:` |
| L'événement a été supprimé | `Should Not Contain    ${result.stdout}    [send_data]:` |
| Le payload contient une valeur | `Should Contain    ${result.stdout}    valeur-attendue` |
| Correspondance exacte dans le payload | `Should Contain    ${result.stdout}    "cle":"valeur"` |
| Le script s'est terminé proprement | `Should Be Equal As Integers    ${result.rc}    0` |
| Vérifier un log d'erreur | `Should Contain    ${result.stderr}    [ERROR]` |

---

### 4. Surcharger les paramètres du connecteur

Tout argument `cle=valeur` après le fichier d'événement est passé au connecteur comme
paramètre de configuration, en surchargeant la valeur par défaut. Cela permet de tester
différents scénarios de filtrage sans modifier le connecteur.

```robotframework
# N'accepter que les services CRITICAL ; un événement OK doit être supprimé
Service OK should be dropped when service_status filter only accepts CRITICAL
    ${result}=    Run Process
    ...    lua    ${RUNNER}    ${CONNECTOR}    ${EVENTS_DIR}/service_ok.json
    ...    api_key\=fake_key    service_status\=2
    Should Be Equal As Integers    ${result.rc}    0
    Should Not Contain    ${result.stdout}    [send_data]:
```

Échapper le `=` avec un antislash dans Robot Framework (`\=`) pour éviter qu'il soit
interprété comme un argument nommé.

Paramètres courants :

| Paramètre | Défaut | Description |
|---|---|---|
| `host_status` | `0,1,2` | États host acceptés (séparés par des virgules) |
| `service_status` | `0,1,2,3` | États service acceptés (séparés par des virgules) |
| `hard_only` | `1` | `1` = état HARD uniquement, `0` = HARD et SOFT |
| `max_buffer_size` | `1` | Taille de la file avant envoi (utiliser `0` pour un envoi immédiat) |
| `log_level` | `1` | Verbosité : `1`=INFO, `2`=DEBUG |

---

### 5. Fournir des fixtures de cache broker

Par défaut, `broker_cache` retourne des données mock génériques (ex. nom d'hôte `mock-host-1`).
Pour tester avec des données de cache réalistes, passer un `cache_file` pointant vers une
fixture JSON :

```robotframework
${result}=    Run Process
...    lua    ${RUNNER}    ${CONNECTOR}    ${EVENTS_DIR}/host_down.json
...    api_key\=fake_key    cache_file\=${CURDIR}/cache/my_cache.json
```

Format de la fixture de cache (`tests/robot/suites/<connecteur>/cache/my_cache.json`) :

```json
{
  "hosts": {
    "1": {
      "name": "mon-serveur",
      "alias": "serveur web de production",
      "address": "192.168.1.10",
      "state": 0,
      "state_type": 1,
      "acknowledged": false,
      "scheduled_downtime_depth": 0,
      "instance_id": 1
    }
  },
  "services": {
    "1_1": {
      "description": "HTTP",
      "state": 0,
      "state_type": 1,
      "acknowledged": false,
      "scheduled_downtime_depth": 0
    }
  },
  "hostgroups": {
    "1": [{"id": 10, "name": "Linux-Servers"}]
  },
  "instances": {
    "1": {"name": "Central"}
  }
}
```

La clé pour `services` est `"<host_id>_<service_id>"`.

---

## Fonctionnement du runner de tests

`resources/sc_runner.lua` effectue les étapes suivantes :

1. Charge `broker_mock.lua` pour définir les globaux `broker`, `broker_log` et `broker_cache`.
2. Parse les arguments `cle=valeur` et construit une table de configuration avec
   `send_data_test=1` et `max_buffer_size=0` (pour forcer un envoi immédiat).
3. Si `cache_file` est fourni, charge la fixture JSON dans `_MOCK_CACHE` et recharge
   `broker_mock.lua` pour que `broker_cache` prenne en compte les données de la fixture.
4. Ajoute le répertoire `modules/` du dépôt dans `package.path` pour que la bibliothèque
   stream connector soit chargée depuis la copie de travail (pas le paquet système installé).
5. Charge l'événement depuis le fichier JSON et le décode avec `broker.json_decode`.
6. Appelle `dofile(connecteur)` puis `init(conf)`, `write(event)`, `flush()`.

Grâce à `send_data_test=1`, le connecteur ne fait jamais de vraie requête HTTP.
Il appelle à la place `sc_logger:notice("[send_data]: " .. payload)`, ce qui est capturé
sur stdout.

---

## Référence du mock broker

`resources/broker_mock.lua` fournit trois globaux :

### `broker_log`

Toutes les méthodes (`info`, `warning`, `error`, `debug`, `notice`) écrivent sur **stdout**
avec un préfixe `[NIVEAU]` pour que Robot Framework puisse capturer et asserter les messages
de log.

### `broker`

| Méthode | Comportement |
|---|---|
| `broker.json_encode(t)` | Encode une table Lua en chaîne JSON via `lua-cjson`. |
| `broker.json_decode(s)` | Décode une chaîne JSON ; les flottants à valeur entière sont normalisés en entiers Lua. |

### `broker_cache`

Toutes les méthodes retournent des valeurs par défaut cohérentes si aucune fixture
`cache_file` n'est fournie.

| Méthode | Retour par défaut |
|---|---|
| `broker_cache:get_host(id)` | `{name="mock-host-<id>", address="127.0.0.1", ...}` |
| `broker_cache:get_service(hid, sid)` | `{description="mock-service-<sid>", state=0, ...}` |
| `broker_cache:get_hostgroups(id)` | `{}` |
| `broker_cache:get_servicegroups(hid, sid)` | `{}` |
| `broker_cache:get_severity(hid[, sid])` | `nil` |
| `broker_cache:get_instance(id)` | `{name="mock-poller-<id>"}` |
| `broker_cache:get_instance_name(id)` | `"mock-poller-<id>"` |
| `broker_cache:get_ba(id)` | `nil` |
| `broker_cache:get_bv(id)` | `nil` |
