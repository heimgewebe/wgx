# Glossary

> German version: [Glossar.de.md](Glossar.de.md)

## wgx
Internal toolchain and umbrella repository that provides build scripts, templates, and documentation for related projects.

## `profile.yml`
Central configuration file that controls local profiles (for example dev, CI, or customer-specific). It defines CLI parameters, environment variables, and paths and links the central contract with project-specific settings.

## Contract (CLI Contract)
Agreement that describes commands, options, file structures, and side effects of the wgx CLI. It defines which interfaces must remain stable so that dependent projects can work consistently.
