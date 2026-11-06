#!/bin/bash
# Fills the stream connectors nfpm template in place for one connector, from its manifest
# packaging/connectors/<connector>.json. Usage: render-connector-nfpm.sh <connector> <distrib>
set -euo pipefail

CONNECTOR="$1"
DISTRIB="$2"
TEMPLATE="packaging/connectors/centreon-stream-connectors.yaml"
MANIFEST="packaging/connectors/$CONNECTOR.json"

if [[ ! -f "$MANIFEST" ]]; then
  echo "::error file=$MANIFEST::no packaging manifest for the stream connector $CONNECTOR"
  exit 1
fi

# Debian renamed libcurl4 to libcurl4t64 with the 64-bit time_t transition,
# and provides no libcurl4 virtual package from trixie onwards.
DEB_RENAMES='{}'
if [[ "$DISTRIB" == "trixie" ]]; then
  DEB_RENAMES='{"libcurl4": "libcurl4t64"}'
fi

# one YAML list item per dependency, JSON-quoted so that any value stays valid YAML
depends_items() {
  jq -r --arg packager "$1" --argjson renames "$2" \
    '.depends[$packager][] | ($renames[.] // .) | "      - " + tojson' "$MANIFEST"
}

# values go through the environment and are replaced literally: sed and awk gsub
# alter "&", "/" and backslashes
TPL_PACKAGE_NAME="centreon-stream-connector-$CONNECTOR" \
TPL_CONNECTOR_NAME="$CONNECTOR" \
TPL_SUMMARY="$(jq -r '.summary' "$MANIFEST")" \
TPL_SUMMARY_QUOTED="$(jq '.summary' "$MANIFEST")" \
TPL_DESCRIPTION="$(jq -r '.description' "$MANIFEST")" \
TPL_RPM_DEPENDENCIES="$(depends_items rpm '{}')" \
TPL_DEB_DEPENDENCIES="$(depends_items deb "$DEB_RENAMES")" \
awk '
function replace(line, token, value,    out, i) {
  out = ""
  while ((i = index(line, token)) > 0) {
    out = out substr(line, 1, i - 1) value
    line = substr(line, i + length(token))
  }
  return out line
}
BEGIN {
  n = split("PACKAGE_NAME CONNECTOR_NAME SUMMARY_QUOTED SUMMARY DESCRIPTION RPM_DEPENDENCIES DEB_DEPENDENCIES", tokens, " ")
}
{
  line = $0
  for (t = 1; t <= n; t++) {
    line = replace(line, "@" tokens[t] "@", ENVIRON["TPL_" tokens[t]])
  }
  print line
}' "$TEMPLATE" > "$TEMPLATE.rendered"
mv "$TEMPLATE.rendered" "$TEMPLATE"
