# Changelog Fragment Workflow

Framework and platform changes should carry release-note intent with the code
change. `koncept changelog` provides a small fragment workflow so release notes
are reviewable in pull requests and can be rendered during a platform release.

Fragments live under `.changes/unreleased/` and use Keep-a-Changelog categories:

- `added`
- `changed`
- `deprecated`
- `removed`
- `fixed`
- `security`
- `known-issue`

## Create a fragment

```bash
koncept changelog new policy-exemptions \
  --type added \
  --summary "Add owned, expiring policy exemptions to the policy gate" \
  --owner platform-team \
  --issue IDP-123
```

This writes `.changes/unreleased/policy-exemptions.yaml` and refuses to
overwrite an existing fragment. Each fragment requires:

- `type`: one of the standard categories above.
- `summary`: short release-note text.
- `owner`: accountable team or person.

Optional fields:

- `issue`: ticket, PR, or issue reference.
- `details`: extra context for release notes.

## Validate fragments

```bash
koncept changelog check
```

The command succeeds with zero fragments, which lets repositories enable the
workflow before the first unreleased note exists.

## Render release notes

```bash
# Print a release section to stdout.
koncept changelog render --version v0.2.0

# Or write the section to a file for review.
koncept changelog render --version v0.2.0 --file CHANGELOG.next.md
```

Rendered output is grouped in Keep-a-Changelog order and includes ownership
metadata so release notes remain accountable.

## Release checklist

1. Run `koncept changelog check`.
2. Render the next release section with `koncept changelog render --version <version>`.
3. Copy the rendered section into the project changelog or release notes.
4. Remove consumed `.changes/unreleased/*.yaml` fragments in the release commit.
