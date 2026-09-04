# Part 5 — Group Policy

**Status:** in progress — writeup pending.

## Planned

- Password and account-lockout policy
- Drive mapping and printer deployment by security group
- Desktop and Start menu standardisation
- Verification with `gpresult /r` and RSoP

## Already usable

Group Policy silently stops applying when the SYSVOL or NETLOGON share is
unreachable — a failure mode that produces no obvious error on the client.
[`scripts/Test-DomainHealth.ps1`](../scripts/) checks both shares explicitly,
along with the replication that keeps them in sync between DCs.
