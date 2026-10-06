#!/usr/bin/env bash
# Promotes the latest testing build of every package of a module to stable on JFrog (Artifactory).
# Testing keeps every build, so only the highest version-release per package name (and arch for deb) is copied.
# DRY_RUN=true prints the downloads and uploads instead of running them.
set -euo pipefail

MODULE_NAME="${MODULE_NAME:-}"
DISTRIB="${DISTRIB:-}"
PACKAGE_EXTENSION="${PACKAGE_EXTENSION:-}"
RELEASE_TYPE="${RELEASE_TYPE:-}"
DRY_RUN="${DRY_RUN:-false}"
WORK_DIR="${WORK_DIR:-$(mktemp -d)}"

PROMOTED=0
ALREADY_STABLE=0

summary() {
  if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
    echo "$*" >> "$GITHUB_STEP_SUMMARY"
  fi
}

fail() {
  echo "::error::$*" >&2
  exit 1
}

run() {
  if [[ "$DRY_RUN" == "true" ]]; then
    printf '[dry-run]'
    printf ' %q' "$@"
    printf '\n'
  else
    "$@"
  fi
}

# reads "<group key>\t<version>\t<fields...>" lines, prints the fields of the highest version per group key
latest_per_package() {
  sort -t $'\t' -k1,1 -k2,2V \
    | awk -F '\t' '{ line = $3; for (i = 4; i <= NF; i++) line = line "\t" $i; latest[$1] = line } END { for (key in latest) print latest[key] }' \
    | sort
}

# promote_file <source path> <source sha256> <target directory> [jf upload options...]
promote_file() {
  local source="$1" sha256="$2" target="$3" file stable_sha256
  shift 3
  file="$(basename "$source")"

  stable_sha256="$(jf rt search "$target$file" | jq -r '.[0].sha256 // empty')" || fail "cannot search $target$file."
  if [[ -n "$stable_sha256" ]]; then
    # a stable file is never overwritten: same name means same version-release
    if [[ "$stable_sha256" != "$sha256" ]]; then
      echo "::warning::$file is already stable with a different checksum, bump its version or release to ship this build"
    fi
    echo "$file is already stable"
    ALREADY_STABLE=$((ALREADY_STABLE + 1))
    return
  fi

  echo "promoting $source to $target"
  summary "- \`$file\`"
  run jf rt download "$source" "$WORK_DIR/" --flat --fail-no-op
  run jf rt upload "$WORK_DIR/$file" "$target" --flat --fail-no-op "$@"
  PROMOTED=$((PROMOTED + 1))
}

# prints the search results as tsv, failing on any result missing one of the given properties
search_tsv() {
  local search="$1" filter="$2"
  jq -e 'all(.[]; .props as $p | all($ARGS.positional[]; ($p[.][0] // "") != ""))' --args "${@:3}" <<< "$search" > /dev/null \
    || fail "some testing packages miss one of these properties: ${*:3}."
  jq -r "$filter | @tsv" <<< "$search"
}

promote_rpm() {
  local source_stability="testing" arch search source sha256 found=0
  # hotfix builds are delivered apart, as on pulp
  if [[ "$RELEASE_TYPE" == "hotfix" ]]; then
    source_stability="testing-hotfix"
  fi
  for arch in noarch x86_64; do
    search="$(jf rt search --recursive=false "rpm-plugins/$DISTRIB/$source_stability/$arch/$MODULE_NAME/*.rpm")" \
      || fail "cannot search rpm-plugins/$DISTRIB/$source_stability/$arch/$MODULE_NAME."
    while IFS=$'\t' read -r source sha256; do
      [[ -n "$source" ]] || continue
      found=1
      promote_file "$source" "$sha256" "rpm-plugins/$DISTRIB/stable/$arch/RPMS/$MODULE_NAME/"
    done < <(search_tsv "$search" '.[] | [
        .props["rpm.metadata.name"][0],
        "\(.props["rpm.metadata.version"][0])-\(.props["rpm.metadata.release"][0])",
        .path,
        .sha256
      ]' rpm.metadata.name rpm.metadata.version rpm.metadata.release | latest_per_package)
  done
  (( found )) || fail "nothing to promote: no $MODULE_NAME rpm in rpm-plugins/$DISTRIB/$source_stability."
}

promote_deb() {
  local search source arch sha256 found=0
  search="$(jf rt search --recursive=false --props "deb.distribution=$DISTRIB;release_type=$RELEASE_TYPE" \
    "apt-plugins-testing/pool/$MODULE_NAME/*.deb")" \
    || fail "cannot search apt-plugins-testing/pool/$MODULE_NAME."
  while IFS=$'\t' read -r source arch sha256; do
    [[ -n "$source" ]] || continue
    found=1
    promote_file "$source" "$sha256" "apt-plugins-stable/pool/$MODULE_NAME/" --deb "$DISTRIB/main/$arch"
  done < <(search_tsv "$search" '.[] | [
      "\(.props["deb.name"][0])_\(.props["deb.architecture"][0])",
      .props["deb.version"][0],
      .path,
      .props["deb.architecture"][0],
      .sha256
    ]' deb.name deb.version deb.architecture | latest_per_package)
  (( found )) || fail "nothing to promote: no $RELEASE_TYPE $MODULE_NAME deb for $DISTRIB in apt-plugins-testing."
}

main() {
  [[ -n "$MODULE_NAME" && -n "$DISTRIB" ]] || fail "MODULE_NAME and DISTRIB are required."
  [[ "$RELEASE_TYPE" == "release" || "$RELEASE_TYPE" == "hotfix" ]] || fail "RELEASE_TYPE must be release or hotfix (got '$RELEASE_TYPE')."
  [[ "$DRY_RUN" == "true" || "$DRY_RUN" == "false" ]] || fail "DRY_RUN must be true or false (got '$DRY_RUN')."

  summary "### $MODULE_NAME $DISTRIB promoted to stable on JFrog ($RELEASE_TYPE)"
  case "$PACKAGE_EXTENSION" in
    rpm) promote_rpm ;;
    deb) promote_deb ;;
    *) fail "PACKAGE_EXTENSION must be rpm or deb (got '$PACKAGE_EXTENSION')." ;;
  esac

  echo "$MODULE_NAME $DISTRIB: $PROMOTED promoted, $ALREADY_STABLE already stable"
  summary "- $PROMOTED promoted, $ALREADY_STABLE already stable"
}

main "$@"
