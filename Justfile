set shell := ["bash", "-eu", "-o", "pipefail", "-c"]
set positional-arguments

default: lint

devcontainer-check:
    .devcontainer/setup.sh check

devcontainer-install:
    .devcontainer/setup.sh install all

export METRICS_SCHEMA_URL := "https://raw.githubusercontent.com/heimgewebe/metarepo/contracts-v1/contracts/wgx/metrics.json"

wgx command *args:
    @scripts/just-dispatch.sh wgx "$@"

wgx-metrics subcommand *args:
    @scripts/just-dispatch.sh wgx-metrics "$@"

contracts action *args:
    @scripts/just-dispatch.sh contracts "$@"


# Lokaler Helper: Schnelltests & Linter – sicher mit Null-Trennung und Quoting
lint:
    @set -euo pipefail; \
    mapfile -d '' files < <(git ls-files -z -- '*.sh' '*.bash' || true); \
    if [ "${#files[@]}" -eq 0 ]; then echo "keine Shell-Dateien"; exit 0; fi; \
    printf '%s\0' "${files[@]}" | xargs -0 bash -n; \
    shfmt -d -i 2 -ci -sr -- "${files[@]}"; \
    shellcheck -S style -- "${files[@]}"
