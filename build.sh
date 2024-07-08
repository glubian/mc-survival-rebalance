#!/bin/sh
# shellcheck disable=SC3043

set -e

[ -z "$PACK_DESCRIPTION" ] && PACK_DESCRIPTION='Minecraft Survival Rebalance'
[ -z "$PACK_VERSION" ] && PACK_VERSION='1.0.0'
[ -z "$PACK_FORMAT" ] && PACK_FORMAT='48'
[ -z "$MC_VERSION" ] && MC_VERSION='1.21'

[ -z "$PACK_FILENAME" ] && PACK_FILENAME="mc-survival-rebalance-$PACK_VERSION+$MC_VERSION.zip"

getRepoDir() {
  cd -- "$(realpath -z "$0" | xargs -0 dirname)" > /dev/null 2>&1
  git rev-parse --show-toplevel
  cd - > /dev/null 2>&1
}

workDir=

mkWorkDir() {
  [ -z "$workDir" ] && workDir="$(mktemp -d)"
}

rmWorkDir() {
  [ -z "$workDir" ] && return 0
  rm -rf "$workDir"
  workDir=
}

cleanup() {
  local trapSignal="$2"

  trap - EXIT
  rmWorkDir

  if [ "$trapSignal" ]; then
    trap - "$trapSignal"
    kill -"$trapSignal" $$
  fi
}

setupCleanup() {
  trap 'cleanup' EXIT
  trap 'cleanup HUP' HUP
  trap 'cleanup TERM' TERM
  trap 'cleanup INT' INT
}

genPackMcMeta() {
  cat << EOF
{
  "pack": {
    "description": "$PACK_DESCRIPTION",
    "pack_format": $PACK_FORMAT,
  }
}
EOF
}

log() {
  echo "$1"
}

main() {
  setupCleanup
  mkWorkDir

  repoDir="$(getRepoDir)"
  srcDir="$repoDir/src"
  distDir="$repoDir/dist"
  distFile="$distDir/$PACK_FILENAME"

  # Clean dist/
  rm -rf "$distDir"
  mkdir "$distDir" > /dev/null 2>&1 || true

  # Compress src/ files
  cd -- "$srcDir" > /dev/null 2>&1
  zip -rq "$distFile" -- *
  cd - > /dev/null 2>&1

  # Add pack.mcmeta
  packMcMetaPipe="$workDir/pack.mcmeta"
  mkfifo "$packMcMetaPipe"
  genPackMcMeta > "$packMcMetaPipe" &
  zip -jFIq "$distFile" "$packMcMetaPipe"
  rm "$packMcMetaPipe"

  log "Successfully built '$(realpath --relative-to "$repoDir" "$distFile")'"
}

main
