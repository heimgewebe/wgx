# `wgx validate --profile` fleet proof

Evidence for `OPERATOR-INTEGRATION-LOOP-V1-T002`, acceptance criterion `fleet-proof`.

Regenerate with:

```bash
scripts/validate_fleet_proof.sh
```

Note: the script writes into this directory but does not delete it — keep this
README when regenerating.

## Method

Each repository is materialised from `git archive HEAD` into a scratch tree, so
the proof runs against the repository's **real manifest and real native commands**
without mutating the source checkout. The scratch copy gets a `wgx.validate` block
composed from that repository's own task names, plus three probes:

| probe | purpose |
| --- | --- |
| `redprobe` (`exit 7`) | a failing native check must produce a red receipt |
| `slowprobe` (`sleep 60`) | run under `--timeout 3`, must be reported as `timeout`, never as passed |
| `ciprobe` (declared `ciOnly`) | must appear as an explicit skip, not as a missing check |

`FLEET_PROOF_API_TOKEN` is set during the full run; the summary asserts its value
never appears anywhere in the emitted receipt.

Adding the `validate:` block to these repositories upstream is a per-repository
decision and is **not** part of this task — the proof only shows that the surface
works against their real check inventories.

## Result

| repository | discovery | quick (green) | full (red) |
| --- | --- | --- | --- |
| hausKI | deterministic | `lint` passed | `redprobe` failed, `slowprobe` timeout, `ciprobe` ci-only |
| chronik | deterministic | `guard` passed | `guard` timeout, `redprobe` failed, `slowprobe` timeout, `ciprobe` ci-only |
| weltgewebe | deterministic | `lint` passed | `redprobe` failed, `slowprobe` timeout, `ciprobe` ci-only |

Every assertion in `summary.json` → `proves` holds for all three repositories:
deterministic discovery, green receipt, red receipt, failing check reported,
timeout reported, CI-only skipped, secret absent from the receipt.

`chronik`'s `guard` legitimately exceeds the deliberately aggressive 3-second
limit of the red run; its 300-second quick run passes. That is the timeout
contract working, not a defect.

The `repository.root` paths in the receipts point at the ephemeral scratch trees,
which is what the snapshot method produces and what makes the run non-mutating.

## Known blocker: semantAH is excluded

`semantAH` was the intended third repository but cannot run any wgx profile
command at all. Its manifest declares a task named `semantah.index`, and the
profile parser builds a shell variable name directly from the normalised task
name:

```python
safe_name = norm.replace('-', '_')          # keeps the dot
emit_var(f"WGX_TASK_CMDS_{safe_name}", ...) # ValueError: invalid shell variable name
```

The parser aborts, so `profile::ensure_loaded` fails and every command reports
"Kein Profil gefunden". This is reproducible on `main` without any of this
task's changes:

```console
$ git stash && python3 modules/profile_parser.py /home/alex/repos/semantAH/.wgx/profile.yml
ValueError: invalid shell variable name: 'WGX_TASK_CMDS_semantah.index'
```

The other emitters (`workflows`, and the new `validate` skip declarations) already
sanitise with `RE_NON_ALPHANUM_UNDERSCORE`; the task emitter does not. A fix has
to normalise the **lookup** key on both the Python and Bash sides together —
`modules/profile.bash` notes that its `profile::_normalize_task_name` must stay
synchronised with the parser — otherwise `wgx run semantah.index` would stop
resolving. That is a task-naming change affecting every repository, so it is
deliberately **not** bundled into this receipt work and is left for a separate,
explicitly scoped task.
