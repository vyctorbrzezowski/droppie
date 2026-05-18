# Security Policy

## Supported Versions

Droppie is pre-1.0. Security fixes target the latest public release and `main`.

## Reporting a Vulnerability

Please report security issues through GitHub private vulnerability reporting when available.

Do not open a public issue with secrets, tokens, exploit payloads, or private provider URLs. If private reporting is unavailable, open a minimal public issue asking for a private contact path and omit sensitive details.

Useful reports include:

- Droppie version or commit
- macOS version
- affected provider or upload path
- clear reproduction steps
- expected impact

## Scope

In scope:

- secret handling and Keychain storage
- upload request signing and authorization
- local file handling
- update metadata handling

Out of scope:

- vulnerabilities in third-party providers
- public access caused by a user's bucket, CDN, Drive, Dropbox, Imgur, or here.now configuration
- reports that require access to someone else's account, machine, or credentials
