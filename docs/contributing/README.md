# Contributing to DrapeAI

## Repo

This is a monorepo: `api/`, `app/`, `admin/`, `infra/`, `docs/`.

## Before a PR

Use [../rules/CODING-RULES-HANDBOOK.md](../rules/CODING-RULES-HANDBOOK.md) and [../rules/AGENTS.md](../rules/AGENTS.md).

Mandatory human review: auth, security, destructive migrations, try-on commercial/licensing, large spend path changes.

## Coding standards

- [../rules/CODING-STANDARDS.md](../rules/CODING-STANDARDS.md)
- Profiles: [../instructions/](../instructions/)

## Secrets

No live credentials in git. See [../local-development/ENV-VARS.md](../local-development/ENV-VARS.md).

## Docs

Update the handbook page under `docs/` when behaviour or ops change. Prefer editing the section that owns the topic (services / backend / ops) over dumping one-off notes at repo root.

## Git

See [GIT-WORKFLOW.md](GIT-WORKFLOW.md).
