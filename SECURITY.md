# Security policy

## Supported versions

Security fixes are provided for the latest patch of the current preview line:

| Version | Supported |
|---|---|
| 0.4.x | Yes, latest patch |
| Older previews | No |

## Reporting a vulnerability

Use GitHub private vulnerability reporting:

<https://github.com/avelra-ui/avelra/security/advisories/new>

Alternatively, email <security@avelra.dev>.

Do not open a public issue for an undisclosed vulnerability. Include:

- affected version;
- platform and runtime;
- minimal reproduction;
- impact;
- any suggested fix.

## Response

- acknowledgement within 24 hours;
- initial triage within 72 hours;
- remediation timeline depends on severity and release impact;
- coordinated disclosure after a fix is available.

## Scope

In scope:

- Avelra runtime and CLI;
- SDK and installers;
- npm launcher;
- release and CI workflows;
- native bridge and URL handling.

Out of scope:

- vulnerabilities in the operating system, WebView engine or third-party
  packages that Avelra does not control;
- social engineering;
- issues requiring a compromised administrator account.
