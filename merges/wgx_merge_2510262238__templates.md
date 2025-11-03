### 📄 templates/.gitkeep

**Größe:** 0 B | **md5:** `d41d8cd98f00b204e9800998ecf8427e`

```plaintext

```

### 📄 templates/profile.template.yml

**Größe:** 478 B | **md5:** `e5d7b07eed979a5957c2c6880ebf6634`

```yaml
wgx:
  apiVersion: v1.1
  requiredWgx:
    range: "^2.0"
    min: "2.0.0"
    caps: ["task-array","status-dirs"]
  repoKind: "generic"
  envDefaults:
    RUST_BACKTRACE: "1"
  tasks:
    doctor: { desc: "Sanity-Checks", safe: true, cmd: ["wgx","doctor"] }
    test:   { desc: "Run Bats",        safe: true, cmd: ["bats","-r","tests"] }
python:
  manager: uv
  version: "3.12"
  lock: true
  tools: [ "ruff", "pyright" ]
contracts:
  uv_lock_present: true
  uv_sync_frozen: true
```

