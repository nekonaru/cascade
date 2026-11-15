# Security Policy

## Reporting a vulnerability

Please report suspected vulnerabilities privately to nekonaru on GitHub:
https://github.com/nekonaru/cascade/security/advisories/new

If GitHub Security Advisories are not available to you, open a private report via the repository's "Report a vulnerability" button under the Security tab.

Include:

- What you found and where
- How to reproduce it
- The impact you think it has

You can expect an acknowledgment within a week. Please do not open public issues for security reports.

## Scope

Cascade is a local simulation library. It does not run as a service, does not accept network traffic and does not handle credentials. The most sensitive parts are the release pipeline and the dependency tree.

## Supported versions

| Version | Supported |
|---------|-----------|
| v0.1.x  | Yes       |

## Notes

- Dependencies are audited in CI (gitleaks secret scan) and the dependency tree is pinned via `Manifest.toml`.
- This project does not collect telemetry or personal data.
