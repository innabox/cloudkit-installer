#!/bin/bash

# Find all directories that:
#
# - contain (a) `kustomization.yaml`
# - DO NOT contain `.skip-build`
# - are not contained in git submodules.
#
# ...and then run `kustomize build` on them.
find ./* -type d -exec test -e "{}/.git" \; -prune \
  -o -type d -exec test -e "{}/.skip-build" \; -prune \
  -o -type f -name kustomization.yaml -printf "%h\n" |
  while read -r path; do
    echo "Building $path..."
    if [[ -f "$path/.buildfiles" ]]; then
      while read -r buildfile; do
        buildpath="$path/$buildfile"
        if ! [[ -f "$buildpath" ]]; then
          echo "Creating empty file $buildpath to satisfy build requirements"
          mkdir -p "${buildpath%/*}"
          touch "$buildpath"
        fi
      done <"$path/.buildfiles"
    fi
    if ! kustomize build "$path" >/dev/null; then
      if [[ -f "$path/.expect-build-failure" ]]; then
        echo "::warning file=$path::failed to build $path (expected)"
      else
        echo "::error file=$path::failed to build $path"
        exit 1
      fi
    fi
  done
