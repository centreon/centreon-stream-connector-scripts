#!/usr/bin/env bash
# Promotes the latest testing build of every package of a module to stable on JFrog (Artifactory).
# Testing keeps every build, so only the highest version-release per package name (and arch for deb) is copied.
# DRY_RUN=true prints the downloads and uploads instead of running them.
set -euo pipefail

MODULE_NAME="${MODULE_NAME:-}"
DISTRIB="${DISTRIB:-}"
PACKAGE_EXTENSION="${PACKAGE_EXTENSION:-}"
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

# reads "<group key>\t<version>\t<path>" lines, prints the path of the highest version per group key
latest_per_package() {
  sort -t $'\t' -k1,1 -k2,2V | awk -F '\t' '{ latest[$1] = $3 } END { for (key in latest) print latest[key] }' | sort
}

# promote_file <source path> <target directory> [jf upload options...]
promote_file() {
  local source="$1" target="$2" file count
  shift 2
  file="$(basename "$source")"

  count="$(jf rt search --count "$target$file")" || fail "cannot search $target$file."
  if (( count > 0 )); then
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

promote_rpm() {
  local arch search source found=0
  for arch in noarch x86_64; do
    search="$(jf rt search --recursive=false "rpm-plugins/$DISTRIB/testing/$arch/$MODULE_NAME/*.rpm")" \
      || fail "cannot search rpm-plugins/$DISTRIB/testing/$arch/$MODULE_NAME."
    while read -r source; do
      [[ -n "$source" ]] || continue
      found=1
      promote_file "$source" "rpm-plugins/$DISTRIB/stable/$arch/RPMS/$MODULE_NAME/"
    done < <(jq -r '.[] | [
        .props["rpm.metadata.name"][0],
        "\(.props["rpm.metadata.version"][0])-\(.props["rpm.metadata.release"][0])",
        .path
      ] | @tsv' <<< "$search" | latest_per_package)
  done
  (( found )) || fail "nothing to promote: no $MODULE_NAME rpm in rpm-plugins/$DISTRIB/testing."
}

promote_deb() {
  local search source arch found=0
  search="$(jf rt search --recursive=false --props "deb.distribution=$DISTRIB" "apt-plugins-testing/pool/$MODULE_NAME/*.deb")" \
    || fail "cannot search apt-plugins-testing/pool/$MODULE_NAME."
  while IFS=$'\t' read -r source arch; do
    [[ -n "$source" ]] || continue
    found=1
    promote_file "$source" "apt-plugins-stable/pool/$MODULE_NAME/" --deb "$DISTRIB/main/$arch"
  done < <(jq -r '.[] | [
      "\(.props["deb.name"][0])_\(.props["deb.architecture"][0])",
      .props["deb.version"][0],
      .path,
      .props["deb.architecture"][0]
    ] | @tsv' <<< "$search" | sort -t $'\t' -k1,1 -k2,2V \
      | awk -F '\t' '{ latest[$1] = $3 "\t" $4 } END { for (key in latest) print latest[key] }' | sort)
  (( found )) || fail "nothing to promote: no $MODULE_NAME deb for $DISTRIB in apt-plugins-testing."
}

main() {
  [[ -n "$MODULE_NAME" && -n "$DISTRIB" ]] || fail "MODULE_NAME and DISTRIB are required."
  [[ "$DRY_RUN" == "true" || "$DRY_RUN" == "false" ]] || fail "DRY_RUN must be true or false (got '$DRY_RUN')."

  summary "### $MODULE_NAME $DISTRIB promoted to stable on JFrog"
  case "$PACKAGE_EXTENSION" in
    rpm) promote_rpm ;;
    deb) promote_deb ;;
    *) fail "PACKAGE_EXTENSION must be rpm or deb (got '$PACKAGE_EXTENSION')." ;;
  esac

  echo "$MODULE_NAME $DISTRIB: $PROMOTED promoted, $ALREADY_STABLE already stable"
  summary "- $PROMOTED promoted, $ALREADY_STABLE already stable"
}

main "$@"
