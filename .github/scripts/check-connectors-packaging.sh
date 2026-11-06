#!/bin/bash
# Checks the packaging manifests of the stream connectors: one per centreon-certified directory,
# valid (connector-manifest.jq), unique summaries, and a declared package for every Lua module
# the connector requires, directly or through the library (map: connectors-lua-modules.json).
set -euo pipefail
shopt -s inherit_errexit

SCRIPTS_DIR="$(dirname "$0")"
MANIFEST_DIR="packaging/connectors"
LIB_DIR="modules/centreon-stream-connectors-lib"
MODULES="$SCRIPTS_DIR/connectors-lua-modules.json"
ERRORS=0
SUMMARIES=()

# "lib" for the library and its dependencies, "self" for a module shipped by the connector,
# "optional" for a module loaded with a fallback, "unpackaged", "unknown", or the package name
RESOLVE='
  def matches($pattern):
    if ($pattern | endswith(".*")) then ($m == $pattern[:-2] or ($m | startswith($pattern[:-1]))) else $m == $pattern end;
  if any(.provided_by_lib[]; matches(.)) then "lib"
  elif any(.in_package[]; matches(.)) then "self"
  elif any(.optional[]; matches(.)) then "optional"
  elif any(.unpackaged[]; matches(.)) then "unpackaged"
  else ([.packages | to_entries[] | select(.key as $k | matches($k)) | .value] | first // "unknown")
  end'

error() {
  echo "::error file=$1::$2"
  ERRORS=$((ERRORS + 1))
}

# modules required by the given Lua files, comments removed; dynamic names ("prefix" .. var) are
# skipped. Line-based, not a Lua parser: "--" inside a string literal is taken as a comment.
lua_requires() {
  awk '
    FNR == 1 { closing = "" }
    {
      line = $0
      out = ""
      while (line != "") {
        if (closing != "") {
          if ((i = index(line, closing)) > 0) { line = substr(line, i + length(closing)); closing = "" } else { line = "" }
        } else if ((i = index(line, "--")) > 0) {
          out = out substr(line, 1, i - 1)
          line = substr(line, i + 2)
          if (match(line, /^\[=*\[/)) {
            closing = "]"
            for (level = 2; level < RLENGTH; level++) { closing = closing "=" }
            closing = closing "]"
            line = substr(line, RLENGTH + 1)
          } else {
            line = ""
          }
        } else {
          out = out line
          line = ""
        }
      }
      print out
    }' "$@" \
    | { grep -oE "(^|[^[:alnum:]_.:])(require[[:space:]]*\(?[[:space:]]*|pcall\([[:space:]]*require[[:space:]]*,[[:space:]]*)[\"'][^\"']+[\"']([[:space:]]*\.\.)?" || true; } \
    | { grep -vE '\.\.$' || true; } \
    | sed -E "s/.*[\"']([^\"']+)[\"']$/\1/" \
    | sort -u
}

# modules required by a connector and by the library modules it loads, recursively
connector_requires() {
  local -A seen=()
  local -a pending
  local module file requires
  requires="$(lua_requires "centreon-certified/$1"/*.lua)"
  mapfile -t pending <<< "$requires"
  while (( ${#pending[@]} > 0 )); do
    module="${pending[0]}"
    pending=("${pending[@]:1}")
    [[ -z "$module" || -n "${seen[$module]:-}" ]] && continue
    seen[$module]=1
    echo "$module"
    file="$(lib_file "$module")"
    if [[ -f "$file" ]]; then
      requires="$(lua_requires "$file")"
      mapfile -t -O "${#pending[@]}" pending <<< "$requires"
    fi
  done
}

# source file of a library module, empty for other modules
lib_file() {
  if [[ "$1" == centreon-stream-connectors-lib.* ]]; then
    echo "$LIB_DIR/$(tr . / <<< "${1#centreon-stream-connectors-lib.}").lua"
  fi
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
  if ! jq -e -f "$SCRIPTS_DIR/connector-manifest.jq" "$manifest" > /dev/null 2>&1; then
    error "$manifest" "expected only a single-line summary and description, and depends.rpm / depends.deb lists, without @TOKEN@"
    continue
  fi
  SUMMARIES+=("$(jq -r '.summary' "$manifest")")
  if ! compgen -G "centreon-certified/$connector/*.lua" > /dev/null; then
    error "centreon-certified/$connector" "no Lua script in this stream connector directory"
    continue
  fi
  requires="$(connector_requires "$connector")"

  while read -r module; do
    [[ -z "$module" ]] && continue
    file="$(lib_file "$module")"
    if [[ -n "$file" && ! -f "$file" ]]; then
      error "centreon-certified/$connector" "the library module $module does not exist ($file)"
      continue
    fi
    provider="$(jq -r --arg m "$module" "$RESOLVE" "$MODULES")"
    case "$provider" in
      lib|self|optional) ;;
      unpackaged)
        echo "::warning file=centreon-certified/$connector::the Lua module $module is not packaged on any supported distribution"
        ;;
      unknown)
        error "centreon-certified/$connector" "the Lua module $module is not listed in $MODULES"
        ;;
      *)
        for packager in rpm deb; do
          if ! jq -e --arg p "$provider" --arg k "$packager" 'any(.depends[$k][]; split(" ")[0] == $p)' "$manifest" > /dev/null; then
            error "$manifest" "the Lua module $module requires $provider in depends.$packager"
          fi
        done
        ;;
    esac
  done <<< "$requires"
done < <(find centreon-certified -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort)

while read -r summary; do
  [[ -n "$summary" ]] && error "$MANIFEST_DIR" "the summary \"$summary\" is used by several stream connectors"
done < <(printf '%s\n' "${SUMMARIES[@]}" | sort | uniq -d)

if (( ERRORS > 0 )); then
  echo "::error::$ERRORS stream connector packaging problem(s) found"
  exit 1
fi
echo "stream connector packaging manifests are consistent"
