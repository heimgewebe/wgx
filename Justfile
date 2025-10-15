set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

default: devcontainer-check

devcontainer-check:
    .devcontainer/setup.sh check

devcontainer-install:
    .devcontainer/setup.sh install all

METRICS_SCHEMA_URL := "https://raw.githubusercontent.com/heimgewebe/metarepo/contracts-v1/contracts/wgx/metrics.json"

wgx command +args:
    case "$command" in \
      metrics)
        just wgx-metrics {{args}}
        ;;
      *)
        echo "Unbekannter wgx-Befehl: $command" >&2
        exit 1
        ;;
    esac

wgx-metrics subcommand +args:
    case "$subcommand" in \
      snapshot)
        scripts/wgx-metrics-snapshot.sh {{args}}
        ;;
      *)
        echo "Unbekannter wgx metrics-Befehl: $subcommand" >&2
        exit 1
        ;;
    esac

contracts action +args:
    case "$action" in \
      validate)
        npx --yes ajv-cli@5 validate -s "${METRICS_SCHEMA_URL}" -d metrics.json {{args}}
        ;;
      *)
        echo "Unbekannter contracts-Befehl: $action" >&2
        exit 1
        ;;
    esac
