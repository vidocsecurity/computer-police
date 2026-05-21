# Security Policy

Computer Police is a supply-chain security tool. We take vulnerabilities in it seriously and we want responsible reporters to have a clear, fast path to us.

## Reporting a vulnerability

Please do **not** open a public GitHub issue for security vulnerabilities, and please do **not** disclose the issue on social media or in chat before we have had a chance to respond.

Use one of these private channels:

- **Preferred:** Open a private report through [GitHub Security Advisories](https://github.com/vidocsecurity/computer-police/security/advisories/new). This keeps the discussion attached to the repository and lets us coordinate a fix and a CVE if needed.
- **Email:** [security@vidocsecurity.com](mailto:security@vidocsecurity.com).

When reporting, please include as much of the following as you can:

- A description of the issue and the impact you believe it has.
- The Computer Police version (`computer-police --version`) and platform (OS, CPU architecture, package managers in use).
- Reproduction steps, proof-of-concept code, or a minimal failing example.
- Whether the issue is already public, and any deadlines you are working against.

## Our response

- We will acknowledge your report within **2 business days**.
- We will give you an initial assessment, including severity and a rough timeline, within **7 business days**.
- We aim to ship a fix for critical issues within **30 days** of acknowledgement, and to coordinate disclosure with you.
- We are happy to credit you in the release notes and in any associated advisory unless you ask us not to.

## Scope

In scope:

- The `computer-police` CLI and the local registry proxy it runs.
- The macOS `Computer Police.app` menu-bar app.
- The public installer script (`scripts/install.sh`) and the release artifacts it downloads.
- The HTTP API exposed by the local proxy (`/api/health`, `/api/events`, `/api/stats`, `/api/advisories`).

Examples of in-scope issues:

- Bypasses of malicious-package blocking for any **Supported** ecosystem.
- Remote code execution, privilege escalation, or sandbox escape originating from Computer Police itself.
- Vulnerabilities in the public installer (for example, missing checksum verification, unsafe extraction, race conditions on a shared system).
- Leaks of local install data beyond the documented `~/.computer-police/` location.
- Tampering with package-manager configuration in ways that are not reversible by `computer-police uninstall`.

Out of scope:

- Vulnerabilities in upstream package managers, registries (npm, PyPI, etc.), or the OSV advisory feed itself. Please report those to the relevant project.
- Reports that depend on an attacker already having local code execution as the user running Computer Police.
- Denial-of-service against the local loopback proxy from the same machine.
- Findings that only apply to ecosystems marked **Planned** in the README coverage table.
- Social-engineering, phishing, or physical-access attacks.

## Hall of fame

We will list publicly disclosed, fixed vulnerabilities and the reporters who found them here once we have any. If you are the first, you get the top slot.
