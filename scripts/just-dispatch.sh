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
    exec npx --yes ajv-cli@5 validate -s "$METRICS_SCHEMA_URL" -d metrics.json "$@"
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
