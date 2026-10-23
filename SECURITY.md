# Security Policy

## Reporting a Vulnerability

**Do not open a public GitHub issue for security vulnerabilities.**

Email: security@kotton.sh

Include:

- A description of the vulnerability and its potential impact
- Steps to reproduce or proof-of-concept code
- The version or commit you tested against

You'll receive an acknowledgment within 48 hours. We'll work with you on a
coordinated disclosure timeline — typically 90 days, shorter for critical issues
affecting user key material or encrypted data.

## Scope

The areas we care most about, in priority order:

1. **Key management** — anything that could expose a user's CEK, device keypair,
   or recovery key in plaintext
2. **IPC authentication** — privilege escalation via the daemon's named pipe /
   Unix socket
3. **Encryption correctness** — nonce reuse, wrong key derivation path, or
   ciphertext manipulation that allows plaintext recovery
4. **Capability grant bypass** — an app reading data it was not explicitly granted
   access to

## Out of Scope

- Vulnerabilities in dependencies that have already been disclosed upstream
  (report those to the upstream project)
- Denial-of-service attacks against a local daemon with no network exposure
- Issues that require physical access to an already-unlocked device

## What a signature here certifies

`install.sh` trusts one thing: `SHA256SUMS.sig`, checked against `infra/release/allowed_signers`
as the tag holds it. Before signing a release's `SHA256SUMS`, the owner confirms that every
`repository` field of `release.lock` at the tag names a kotton repository (`kottonllc/…`), and
that each line of `SHA256SUMS` matches that component's own published `SHA256SUMS` at the
locked tag, or the line the owner's own build of that commit printed. The owner then signs on
their own machine with a key whose public half is in `allowed_signers`, never on GitHub. The
component sums the release workflow fetches over TLS are a cross-check, not the root of trust:
an archive that matches them but that the owner has not signed installs nothing.

## What We Commit To

- We will not take legal action against researchers acting in good faith
- We will credit you in the release notes if you'd like
- We will not disclose your identity without your permission
