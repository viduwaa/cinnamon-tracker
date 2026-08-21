# Cinnamon Trace

Blockchain-verified cinnamon supply-chain traceability for Sri Lanka — from
farm plot to export lot, with QR proof of origin.

## Documentation

| File | Contents |
|------|----------|
| [docs/PLAN.md](docs/PLAN.md) | Master architecture plan (domain, rules, ADRs, roadmap) |
| [docs/tech-stack.md](docs/tech-stack.md) | Finalized stack decision |
| [docs/implementation-plan.md](docs/implementation-plan.md) | Build tracker — what's done, what's next |
| [docs/api-spec.md](docs/api-spec.md) | REST API contract |
| [docs/schema.sql](docs/schema.sql) | PostgreSQL schema (event ledger + RLS) |
| [docs/flutter-plan.md](docs/flutter-plan.md) | Detailed Flutter implementation plan (work packages, sync engine) |
| [docs/wireframes.md](docs/wireframes.md) | Screens and flows |
| [docs/blockchain-discussion.md](docs/blockchain-discussion.md) | Parked: chain-choice discussion |

## Planned repo layout

```
cinnamon-tracker/
├── docs/      ← all planning & design docs (here)
├── app/       ← Flutter mobile app (all roles)                [scaffold pending]
└── backend/   ← integrity core built (29 tests); NestJS next  [in progress]
```
