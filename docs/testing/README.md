# Testing And Verification Documentation

Start here if you are validating framework changes, rendered output, acceptance scenarios, or promotion gates.

## Read In Order

1. [TESTING_STRATEGY.md](TESTING_STRATEGY.md) — testing layers and intent.
2. [VERIFICATION_MATRIX.md](VERIFICATION_MATRIX.md) — canonical local/CI verification runbook.
3. [GOLDEN_OUTPUTS.md](GOLDEN_OUTPUTS.md) — render-drift snapshots and review expectations.

## Acceptance Testing

| Document | Use |
|---|---|
| [ACCEPTANCE_TESTING.md](ACCEPTANCE_TESTING.md) | kind dry-run acceptance matrix |
| [ACCEPTANCE_RUNTIME.md](ACCEPTANCE_RUNTIME.md) | Real-cluster runtime acceptance layer |
| [ACCEPTANCE_DEPENDENCIES.md](ACCEPTANCE_DEPENDENCIES.md) | Dependency scenarios and fixture rules |
| [CROSSPLANE_TESTING_GUIDE.md](CROSSPLANE_TESTING_GUIDE.md) | Crossplane output and runtime testing |

## Common Commands

```bash
./scripts/verify.sh
koncept golden check --factory <factory> --formats yaml,helmfile
koncept policy check --factory <factory>
koncept crossplane test --factory <factory>
```
