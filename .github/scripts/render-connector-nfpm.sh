#!/bin/bash
# Fills the stream connectors nfpm template in place for one connector, from its manifest
# packaging/connectors/<connector>.json. Usage: render-connector-nfpm.sh <connector> <distrib>
set -euo pipefail

CONNECTOR="$1"
DISTRIB="$2"
TEMPLATE="packaging/connectors/centreon-stream-connectors.yaml"
MANIFEST="packaging/connectors/$CONNECTOR.json"

if ! command -v jq > /dev/null; then
  echo "::error::jq is required to render the nfpm config of $CONNECTOR"
  exit 1
fi
if [[ ! -f "$MANIFEST" ]]; then
  echo "::error file=$MANIFEST::no packaging manifest for the stream connector $CONNECTOR"
  exit 1
fi
if ! jq -e -f "$(dirname "$0")/connector-manifest.jq" "$MANIFEST" > /dev/null; then
  echo "::error file=$MANIFEST::invalid packaging manifest, run .github/scripts/check-connectors-packaging.sh"
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

# assigned one by one so that a jq failure stops the script
SUMMARY="$(jq -r '.summary' "$MANIFEST")"
SUMMARY_QUOTED="$(jq '.summary' "$MANIFEST")"
DESCRIPTION="$(jq -r '.description' "$MANIFEST")"
RPM_DEPENDENCIES="$(depends_items rpm '{}')"
DEB_DEPENDENCIES="$(depends_items deb "$DEB_RENAMES")"

# values go through the environment and are inserted literally in a single pass: sed and awk gsub
# alter "&", "/" and backslashes, and an inserted value is never scanned for tokens again
TPL_PACKAGE_NAME="centreon-stream-connector-$CONNECTOR" \
TPL_CONNECTOR_NAME="$CONNECTOR" \
TPL_SUMMARY="$SUMMARY" \
TPL_SUMMARY_QUOTED="$SUMMARY_QUOTED" \
TPL_DESCRIPTION="$DESCRIPTION" \
TPL_RPM_DEPENDENCIES="$RPM_DEPENDENCIES" \
TPL_DEB_DEPENDENCIES="$DEB_DEPENDENCIES" \
awk '
BEGIN {
  n = split("PACKAGE_NAME CONNECTOR_NAME SUMMARY_QUOTED SUMMARY DESCRIPTION RPM_DEPENDENCIES DEB_DEPENDENCIES", tokens, " ")
}
{
  line = $0
  out = ""
  while ((i = index(line, "@")) > 0) {
    out = out substr(line, 1, i - 1)
    line = substr(line, i)
    matched = 0
    for (t = 1; t <= n; t++) {
      token = "@" tokens[t] "@"
      if (substr(line, 1, length(token)) == token) {
        out = out ENVIRON["TPL_" tokens[t]]
        line = substr(line, length(token) + 1)
        matched = 1
        break
      }
    }
    if (!matched) {
      out = out "@"
      line = substr(line, 2)
    }
  }
  print out line
}' "$TEMPLATE" > "$TEMPLATE.rendered"
mv "$TEMPLATE.rendered" "$TEMPLATE"
