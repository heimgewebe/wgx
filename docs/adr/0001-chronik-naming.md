# ADR 0001: chronik naming

## Status

Accepted (updated)

## Context

The Heimgewebe ecosystem has a key component for system visibility and event storage:

- **chronik**: An event-ingest, persistence layer, and dashboard. It acts as an event store ("memory")
  for the system, storing events and audit logs, and provides visualization capabilities.

This document clarifies the semantic role and naming of this repository.

Note: The previous "leitstand" repository was merged into chronik. The name "leitstand" is now reserved
for a future UI component for controlling operations.

## Decision

1. **chronik repository:** Serves as the event store, persistence layer, and dashboard for system visibility.

## Consequences

- All references to the event store/memory and the associated dashboard in documentation, CI/CD
  pipelines, and `.ai-context.yml` files use `chronik`.
- The name "leitstand" is reserved for a future control UI component.
- The naming reflects the semantic role: chronik = chronicle/memory + visualization.
