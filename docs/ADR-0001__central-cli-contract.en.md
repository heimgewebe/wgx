# ADR-0001: Central CLI Contract

> German version: [ADR-0001__central-cli-contract.de.md](ADR-0001__central-cli-contract.de.md)

## Status
Accepted

## Context
The wgx toolchain supports multiple projects and workstations. Until now, different variants of the CLI contract lived in individual repositories, leading to inconsistent behaviour and repeated coordination effort. New features had to be documented and agreed upon multiple times, and automated tests could not be reused reliably. On top of that, engineers work from different environments (Termux, VS Code Remote, traditional Linux setups), which makes configuration drift in the CLI a common source of errors.

## Decision
We maintain a centrally governed CLI contract within wgx. The contract is versioned in `docs`, describes expected commands, configuration files (for example `profile.yml`), and their interfaces, and serves as the reference for all dependent projects. Contract changes must go through pull requests, including an ADR update, so that transparency and traceability are ensured.

## Consequences
- Consistent behaviour: all projects align to the same contract and can ship compatible tooling scripts.
- Less coordination overhead: documentation, tests, and runbooks only need to be maintained once.
- Faster onboarding: new team members get a single reference point.
- Higher maintainability: incompatible changes are detected early because they must be negotiated via the central contract.

## Open Questions
- How do we migrate legacy projects that still maintain their own CLI definitions?
- Which automated validations must run when the contract changes?
