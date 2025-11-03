### 📄 policies/deny.toml

**Größe:** 250 B | **md5:** `aaa94e21b7604b738348fb00d4bf7cb3`

```toml
[graph]
depth = 5

[bans]
bare_version = "deny"
multiple_versions = "deny"

[licenses]
allow = ["MIT", "Apache-2.0", "BSD-3-Clause", "BSD-2-Clause"]

[advisories]
vulnerability = "deny"
unmaintained = "deny"
yanked = "deny"

[exceptions]
crates = []
```

### 📄 policies/perf.json

**Größe:** 399 B | **md5:** `4d21b279ff5b7439b4145e458e136eb9`

```json
{
  "version": 1,
  "scripts": {
    "wgx:build": {
      "budget_ms": 120000,
      "description": "Full build should complete within two minutes"
    },
    "wgx:test": {
      "budget_ms": 1200000,
      "description": "Unit test suite should complete within twenty minutes"
    },
    "wgx:lint": {
      "budget_ms": 60000,
      "description": "Linting must stay under one minute"
    }
  }
}
```

### 📄 policies/slo.yaml

**Größe:** 165 B | **md5:** `9dfb58ec10e4150d1677150d22dc2fab`

```yaml
version: 1
ci:
  max_runtime_minutes: 30
  max_memory_mb: 4096
  actions:
    - name: unit-tests
      timeout_minutes: 20
    - name: lint
      timeout_minutes: 5
```

