# ADR 0001: chronik and leitstand naming

## Status

Accepted

## Context

The Heimgewebe ecosystem has two key components for system visibility and control:

- **chronik**: An event-ingest and persistence layer, essentially acting as an event store or "memory" for the system. It stores events and audit logs.
- **leitstand**: A UI/dashboard for monitoring and control. It provides a system overview and control room, visualizing data from chronik, semantAH, and hausKI.

This document clarifies the semantic roles and naming of these repositories.

## Decision

1.  **chronik repository:** Serves as the backend event store and persistence layer.
2.  **leitstand repository:** Serves as the UI for monitoring and control (dashboard).

## Consequences

-   All references to the event store/memory in documentation, CI/CD pipelines, and `.ai-context.yml` files use `chronik`.
-   All references to the UI/dashboard use `leitstand`.
-   The naming reflects the semantic roles: chronik = chronicle/memory, leitstand = control room.