# WGX v1 Profile Specification

This document describes the stable v1 WGX profile format used by the fleet, the wgx CLI, and reusable CI workflows.

## 1. Profile Structure

The preferred structure for v1 profiles is to nest configuration under the `wgx` top-level key.

### Required keys under `wgx`

- `apiVersion`
  Version of the profile schema (must be `v1`).
- `tasks`
  Mapping from task name → shell snippet (command string or list).

### Optional keys under `wgx`

- `requiredWgx` (Semver range)
  Specifies the minimum or range of WGX versions required.
- `repoKind`
  Describes the repo’s overall technology pattern (e.g., `generic`, `rust-service`).
- `dirs`
  Mapping of directory paths (e.g., `web`, `api`, `data`).
- `env`, `envDefaults`, `envOverrides`
  Environment variable definitions.
- `workflows`
  CI workflow definitions mapping to lists of tasks.

### Legacy Root-Level Keys (Deprecated)

For backward compatibility, the following keys are also recognized at the root level, but `wgx.*` takes precedence:

- `tasks`
- `requiredWgx` (or `required-wgx`)
- `repoKind`
- `dirs`
- `env`, `envDefaults`, `envOverrides`
- `workflows`

## 2. Example Profile

```yaml
# .wgx/profile.yml
wgx:
  apiVersion: v1
  requiredWgx: "^2.0.0"
  repoKind: "generic"

  tasks:
    smoke: "echo 'wgx smoke: ok'"
    lint: "echo 'wgx lint: noop'"
    test: "echo 'wgx test: noop'"
```

## 3. requiredWgx

Profiles may indicate a required WGX capability level via `wgx.requiredWgx`.
Legacy spelling `required-wgx` is also supported.

If omitted, the CLI assumes wide compatibility and logs only a warning.

## CI Contract

CI workflows expect a **tracked** `.wgx/profile.yml` (or `.wgx/profile.example.yml` as fallback).
If neither is tracked by git, `wgx` commands will fail with "No tracked wgx profile found".
