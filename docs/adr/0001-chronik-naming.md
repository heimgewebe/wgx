# ADR 0001: Standardize chronik naming and introduce chronik UI

## Status

Accepted

## Context

The existing `chronik` repository serves as an event-ingest and persistence layer, essentially acting as an event store or "memory" for the Heimgewebe ecosystem. The planned UI/dashboard, which will provide a system overview and control room, will share the `chronik` branding.

This renaming is necessary to align the repositories' names with their semantic roles, improving clarity and maintainability.

## Decision

1.  **Standardize the backend repository name:** The backend repository is named `chronik`.
2.  **Create a new UI repository:** A new repository named `chronik-ui` will be created for the UI/dashboard.

## Consequences

-   All references to the backend repository in documentation, CI/CD pipelines, and `.ai-context.yml` files must use `chronik`.
-   The new `chronik-ui` repository will be established as the central UI for the Heimgewebe ecosystem.
-   This change will introduce a temporary inconsistency during the transition, which will be mitigated by a phased rollout.