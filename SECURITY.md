# Security

Gas Mask NG is a development preview. A stable security baseline has not yet been
established; local tests and automated scans do not prove an absence of
vulnerabilities or malicious code.

Report sensitive findings privately using GitHub's **Report a vulnerability**
feature when available. Do not open a public issue containing exploit details,
secrets, private hosts files or real internal domains. If private reporting is
unavailable, open an issue asking for a private contact without disclosing details.

The current threat-model review covers privileged `/etc/hosts` writes, migration,
remote downloads and redirects, saved-list paths, updater trust, login-item
launching, dependencies and release automation. Known release gates and verified
coverage are tracked in [docs/PUBLIC-RELEASE.md](docs/PUBLIC-RELEASE.md).

Developer ID signing and Apple notarization establish a release's publisher and
integrity; they do not replace application security review.
