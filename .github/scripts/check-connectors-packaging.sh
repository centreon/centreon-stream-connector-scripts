#!/bin/bash
# Checks the packaging manifests of the stream connectors: one per centreon-certified directory,
# a single-line summary and description, unique summaries, and a declared package for every
# Lua module the connector requires (module to package map: connectors-lua-modules.json).
set -euo pipefail

MANIFEST_DIR="packaging/connectors"
MODULES="$(dirname "$0")/connectors-lua-modules.json"
ERRORS=0

# "lib" for the library and its dependencies, "self" for a module shipped by the connector,
# "unpackaged", "unknown", or the package that provides the module
RESOLVE='
  def matches($pattern): if ($pattern | endswith(".*")) then ($m | startswith($pattern[:-1])) else $m == $pattern end;
  if any(.provided_by_lib[]; matches(.)) then "lib"
  elif any(.in_package[]; matches(.)) then "self"
  elif any(.unpackaged[]; matches(.)) then "unpackaged"
  else ([.packages | to_entries[] | select(.key as $k | matches($k)) | .value] | first // "unknown")
  end'

error() {
  echo "::error file=$1::$2"
  ERRORS=$((ERRORS + 1))
}

for manifest in "$MANIFEST_DIR"/*.json; do
  connector="$(basename "$manifest" .json)"
  if [[ ! -d "centreon-certified/$connector" ]]; then
    error "$manifest" "no centreon-certified/$connector directory for this packaging manifest"
  fi
done

while read -r connector; do
  manifest="$MANIFEST_DIR/$connector.json"
  if [[ ! -f "$manifest" ]]; then
    error "centreon-certified/$connector" "no packaging manifest, add $manifest with summary, description and depends"
    continue
  fi
  if ! jq -e '
      (keys | sort) == ["depends", "description", "summary"]
      and ([.summary, .description] | all(type == "string" and test("^\\S(.*\\S)?$")))
      and (.depends | type == "object" and (keys | sort) == ["deb", "rpm"] and all(.[]; type == "array"))
      and ([.depends[][]] | all(type == "string" and test("^\\S+$")))' "$manifest" > /dev/null; then
    error "$manifest" "expected a single-line summary and description, and depends.rpm / depends.deb lists of package names"
    continue
  fi

  while read -r module; do
    provider="$(jq -r --arg m "$module" "$RESOLVE" "$MODULES")"
    case "$provider" in
      lib|self) ;;
      unpackaged)
        echo "::warning file=centreon-certified/$connector::the Lua module $module is not packaged on any supported distribution"
        ;;
      unknown)
        error "centreon-certified/$connector" "the Lua module $module is not listed in $MODULES"
        ;;
      *)
        for packager in rpm deb; do
          if ! jq -e --arg p "$provider" --arg k "$packager" 'any(.depends[$k][]; . == $p)' "$manifest" > /dev/null; then
            error "$manifest" "the Lua module $module requires $provider in depends.$packager"
          fi
        done
        ;;
    esac
  done < <(awk '{ sub(/--.*/, ""); print }' "centreon-certified/$connector"/*.lua \
    | grep -oE "require[[:space:]]*\(?[[:space:]]*[\"'][^\"']+[\"']" \
    | sed -E "s/.*[\"']([^\"']+)[\"']$/\1/" \
    | sort -u)
done < <(find centreon-certified -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort)

while read -r summary; do
  error "$MANIFEST_DIR" "the summary \"$summary\" is used by several stream connectors"
done < <(jq -r '.summary' "$MANIFEST_DIR"/*.json | sort | uniq -d)

if (( ERRORS > 0 )); then
  echo "::error::$ERRORS stream connector packaging problem(s) found"
  exit 1
fi
echo "stream connector packaging manifests are consistent"
