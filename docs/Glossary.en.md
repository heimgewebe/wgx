# Glossary

> Deutsche Version: [Glossar.de.md](Glossar.de.md)

## wgx

Repository verification adapter that provides shared checks and reusable CI
routers. Fleet template ownership remains in Metarepo.

## `profile.yml`

Central configuration file that controls local profiles (e.g. Dev, CI or customer specific setups). It defines CLI
parameters, environment variables and paths and therefore ties the central contract to project specific settings.

## Contract (CLI contract)

Agreement about commands, options, directory structures and side effects of the wgx CLI. It defines which interfaces
must remain stable so that downstream projects continue to operate consistently.

## Guard checklist

Set of repository-shape and contract requirements that `wgx guard` verifies.
Passing a guard does not grant task, deployment or host-mutation authority.

## `wgx send`

High level command that prepares and submits pull or merge requests. It enforces guard checks, pushes the current
branch and triggers the appropriate hosting CLI (`gh` or `glab`).
