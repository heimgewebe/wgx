# Glossary

> Deutsche Version: [Glossar.de.md](Glossar.de.md)

## wgx
Internal toolchain and umbrella repository that delivers build scripts, templates and documentation for the connected projects.

## `profile.yml`
Central configuration file that controls local profiles (e.g. Dev, CI or customer specific setups). It defines CLI parameters, environment variables and paths and therefore ties the central contract to project specific settings.

## Contract (CLI contract)
Agreement about commands, options, directory structures and side effects of the wgx CLI. It defines which interfaces must remain stable so that downstream projects continue to operate consistently.

## Guard checklist
Set of minimal repository requirements (e.g. committed `uv.lock`, presence of `templates/profile.template.yml`, CI workflows) that `wgx guard` verifies before automation tasks are allowed to proceed.

## `wgx send`
High level command that prepares and submits pull or merge requests. It enforces guard checks, pushes the current branch and triggers the appropriate hosting CLI (`gh` or `glab`).
