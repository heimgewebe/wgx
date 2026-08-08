# Glossary

> Deutsche Version: [Glossar.de.md](Glossar.de.md)

## WGX

Minimal repository verification runner for existing `.wgx/profile.yml`
contracts. Its public operational ABI is `validate`, `tasks`, and `task`.

## Profile

A repository-owned `.wgx/profile.yml` declares tasks and optional validation
profiles. Task names such as `guard`, `lint`, `smoke`, or `test` belong to the
repository; they are not WGX subcommands.

## Task

A shell command explicitly declared by the target repository and executed with
`wgx task <name>`. WGX does not sandbox its host effects.

## Validation profile

A `quick` or `full` ordered task set executed by `wgx validate --profile ...`
with timeout and receipt handling.
