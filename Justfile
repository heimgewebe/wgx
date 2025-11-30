set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

default: lint

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

# Lokaler Helper: Schnelltests & Linter – sicher mit Null-Trennung und Quoting
lint:
    @set -euo pipefail; \
    mapfile -d '' files < <(git ls-files -z -- '*.sh' '*.bash' || true); \
    if [ "${#files[@]}" -eq 0 ]; then echo "keine Shell-Dateien"; exit 0; fi; \
    printf '%s\0' "${files[@]}" | xargs -0 bash -n; \
    shfmt -d -i 2 -ci -sr -- "${files[@]}"; \
    shellcheck -S style -- "${files[@]}"
