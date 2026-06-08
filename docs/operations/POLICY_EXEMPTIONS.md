# Policy Exemptions

`koncept policy check` enforces the platform baseline for rendered YAML. Prefer
fixing findings in the KCL source. When a temporary exception is unavoidable, use
an explicit exemption file instead of disabling whole rules with `--no-*` flags.

Exemptions are intentionally narrow, owned, and time-bounded:

- `rule`, `owner`, `reason`, and `expiresOn` are required.
- `kind` is required, plus at least one of `namespace` or `name`.
- `expiresOn` uses `YYYY-MM-DD`; expired exemptions fail the policy command.
- Stale exemptions fail the policy command when no current finding matches them.

## Example

```yaml
exemptions:
  - rule: require-network-policy
    kind: Deployment
    namespace: apps
    owner: platform-security
    reason: "Temporary migration while default-deny NetworkPolicy is rolled out"
    expiresOn: "2026-06-30"

  - rule: no-secret-literals
    kind: Deployment
    namespace: apps
    name: legacy-api
    owner: team-legacy
    reason: "Replace literal env value with ExternalSecret in PLATFORM-123"
    expiresOn: "2026-06-15"
```

Run the gate with:

```bash
koncept policy check --factory <factory-dir> --exemptions policy-exemptions.yaml
```

## Review checklist

1. Confirm the finding cannot be fixed immediately in the source template or
   project configuration.
2. Scope the exemption to the smallest possible `rule` + workload target.
3. Set a real owner and a ticket-backed reason.
4. Use the shortest practical expiry date.
5. Remove the exemption in the same change that fixes the underlying finding.
