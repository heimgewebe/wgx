# WGX v1 Profile Specification

This document describes the stable v1 WGX profile format used by the fleet, the wgx CLI, and reusable CI workflows.

## 1. Required top-level keys

All v1 profiles must contain:

- `profile`
  Logical name of the repository.
- `description`
  Human-readable overview text.
- `class`
  Fleet class, describing the repo’s overall technology pattern.
  Examples: `rust-service`, `rust-python-hybrid`, `docs-only`.
- `tasks`
  Mapping from task name → shell snippet.

## 2. Optional but recognized keys

These keys are optional but interpreted by fleet tools:

- `wgx-version` (Semver range; minimum supported WGX features)
- `lang` (list of language tags: `rust`, `python`, `shell`)
- `meta`
  Structured metadata for org, repo, maintainer, tags, etc.
- `rust`, `python`, `tool`, `env`
  Optional detail blocks used by guard/smoke tasks.
- `wgx.apiVersion`
  Version of the profile schema (`v1` for all current repos).

## 3. requiredWgx / required-wgx

Profiles may indicate a required WGX capability level via:

- `requiredWgx`
- or `required-wgx` (legacy spelling)

Both keys are treated identically.

If omitted, the CLI assumes wide compatibility and logs only a warning.

## CI Contract

CI workflows expect a **tracked** `.wgx/profile.yml` (or `.wgx/profile.example.yml` as fallback).
