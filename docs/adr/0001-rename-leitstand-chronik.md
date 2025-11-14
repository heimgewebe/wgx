# ADR 0001: Rename leitstand to chronik and introduce leitstand UI

## Status

Accepted

## Context

The existing `leitstand` repository serves as an event-ingest and persistence layer, essentially acting as an event store or "memory" for the Heimgewebe ecosystem. The planned UI/dashboard, which will provide a system overview and control room, is a more fitting candidate for the name `leitstand`.

This renaming is necessary to align the repositories' names with their semantic roles, improving clarity and maintainability.

## Decision

1.  **Rename the backend repository:** The `leitstand` repository will be renamed to `chronik`.
2.  **Create a new UI repository:** A new repository named `leitstand` will be created for the UI/dashboard.

## Consequences

-   All references to the old `leitstand` repository in documentation, CI/CD pipelines, and `.ai-context.yml` files must be updated to `chronik`.
-   The new `leitstand` repository will be established as the central UI for the Heimgewebe ecosystem.
-   This change will introduce a temporary inconsistency during the transition, which will be mitigated by a phased rollout.