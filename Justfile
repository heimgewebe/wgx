set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

default: devcontainer-check

devcontainer-check:
    .devcontainer/setup.sh check

devcontainer-install:
    .devcontainer/setup.sh install all

METRICS_SCHEMA_URL := "https://raw.githubusercontent.com/heimgewebe/metarepo/contracts-v1/contracts/wgx/metrics.json"

wgx command +args:
    command="${command:-}"
    case "$command" in
      metrics)
        exec just wgx-metrics {{args}}
        ;;
      *)
        echo "Unbekannter wgx-Befehl: $command" >&2
        exit 1
        ;;
    esac

wgx-metrics subcommand +args:
    subcommand="${subcommand:-}"
    case "$subcommand" in
      snapshot)
        exec scripts/wgx-metrics-snapshot.sh {{args}}
        ;;
      *)
        echo "Unbekannter wgx metrics-Befehl: $subcommand" >&2
        exit 1
        ;;
    esac

contracts action +args:
    action="${action:-}"
    case "$action" in
      validate)
        exec npx --yes ajv-cli@5 validate -s "${METRICS_SCHEMA_URL}" -d metrics.json {{args}}
        ;;
      *)
        echo "Unbekannter contracts-Befehl: $action" >&2
        exit 1
        ;;
    esac
default: lint
lint:
    bash -n $(git ls-files *.sh *.bash)
    echo "lint ok"
