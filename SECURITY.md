# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability in rimshot, please report it responsibly.

**Do NOT open a public GitHub issue for security vulnerabilities.**

Instead, please email: **security@dbfarias.dev**

Or use [GitHub's private vulnerability reporting](https://github.com/dbfarias/rimshot/security/advisories/new).

### What to include

- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if any)

### Response timeline

- **Acknowledgment**: Within 48 hours
- **Assessment**: Within 7 days
- **Fix**: Depends on severity, but we aim for patches within 14 days for critical issues

### Scope

rimshot is a bash script that runs as a Claude Code hook. The primary security concerns are:

- **File access**: The script reads joke files and a config file. Path traversal is guarded by input validation.
- **Temp files**: A cooldown timestamp file is written to `$TMPDIR`. Symlink attacks are guarded.
- **JSON output**: Built with `jq` to ensure RFC 8259-compliant escaping.
- **settings.json modification**: Install/uninstall use `jq` with atomic writes (mktemp + mv).

The script has **no network access**, **no eval**, and **no execution of user-provided code**.

## Supported Versions

| Version | Supported |
| ------- | --------- |
| 1.x     | Yes       |
