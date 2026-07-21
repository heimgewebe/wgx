#!/usr/bin/env bash
set -euo pipefail

namespace=${1:-}
if [[ -z "$namespace" ]]; then
  echo "just-dispatch: namespace fehlt" >&2
  exit 2
fi
shift

case "$namespace" in
wgx)
  command=${1:-}
  [[ $# -gt 0 ]] && shift
  case "$command" in
  metrics)
    exec just wgx-metrics "$@"
    ;;
  *)
    echo "Unbekannter wgx-Befehl: $command" >&2
    exit 1
    ;;
  esac
  ;;
wgx-metrics)
  subcommand=${1:-}
  [[ $# -gt 0 ]] && shift
  case "$subcommand" in
  snapshot)
    exec scripts/wgx-metrics-snapshot.sh "$@"
    ;;
  *)
    echo "Unbekannter wgx metrics-Befehl: $subcommand" >&2
    exit 1
    ;;
  esac
  ;;
contracts)
  action=${1:-}
  [[ $# -gt 0 ]] && shift
  case "$action" in
  validate)
    : "${METRICS_SCHEMA_URL:?METRICS_SCHEMA_URL fehlt}"
    schema_path="$METRICS_SCHEMA_URL"
    case "$METRICS_SCHEMA_URL" in
    http://* | https://*)
      schema_tmp_dir="$(mktemp -d)"
      trap 'rm -rf "$schema_tmp_dir"' EXIT
      schema_path="$schema_tmp_dir/metrics.schema.json"
      if ! curl -fsSL "$METRICS_SCHEMA_URL" -o "$schema_path"; then
        echo "contracts validate: Schema konnte nicht geladen werden: $METRICS_SCHEMA_URL" >&2
        exit 1
      fi
      ;;
    *://*)
      echo "contracts validate: Nicht unterstützte Schema-URL: $METRICS_SCHEMA_URL" >&2
      exit 2
      ;;
    esac
    npx --yes ajv-cli@5 validate --spec=draft2020 --strict=log -s "$schema_path" -d metrics.json "$@"
    ;;
  *)
    echo "Unbekannter contracts-Befehl: $action" >&2
    exit 1
    ;;
  esac
  ;;
*)
  echo "just-dispatch: unbekannter Namespace: $namespace" >&2
  exit 2
  ;;
esac
