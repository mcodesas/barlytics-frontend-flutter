#!/usr/bin/env bash
# Identificador de release: mismo commit => mismo build en Android/escritorio.
# Un merge nuevo en main produce un número superior sin editar pubspec.yaml.
set -euo pipefail
commit="${GITHUB_SHA:-HEAD}"
epoch="$(git show -s --format=%ct "$commit")"
[[ "$epoch" =~ ^[0-9]+$ ]]
base=1767225600 # 2026-01-01 UTC
build=$((2001000000 + (epoch - base) / 2))
if (( build <= 2000000692 || build >= 2100000000 )); then
  echo "Build fuera de rango Android: $build" >&2
  exit 1
fi
printf '%s\n' "$build"
