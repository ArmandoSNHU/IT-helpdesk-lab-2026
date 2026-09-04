# PowerShell scripts

Automation used across the lab. Written the way I write scripts for real work,
not as one-liners: comment-based help, parameter validation, `-WhatIf` support
on anything that writes, logging, and exit codes so they can be scheduled.

| Script | Writes? | What it does |
|---|---|---|
| `New-LabADUser.ps1` | yes (`-WhatIf` supported) | Bulk-creates AD users from CSV. Validates the whole file first, skips existing accounts, logs every action. |
| `Test-DomainHealth.ps1` | **no — read only** | Domain controller health: services, DNS, replication, time skew, SYSVOL, disk. |

---

## `New-LabADUser.ps1`

```powershell
# Rehearse first — nothing is created
.\New-LabADUser.ps1 -CsvPath .\users.sample.csv -WhatIf

# Then run it
.\New-LabADUser.ps1 -CsvPath .\users.sample.csv -Verbose
```

**The password is a `SecureString`, never a plaintext parameter.** PSScriptAnalyzer
flags `ConvertTo-SecureString -AsPlainText` as an error for good reason: a plaintext
password parameter ends up in PSReadLine history, process listings, and transcript
logs. Omit `-DefaultPassword` and PowerShell prompts for it securely.

Three more decisions worth calling out:

**Validate the whole file before creating anything.** A half-applied onboarding
batch is much worse to clean up than a rejected CSV. Missing columns or blank
names abort the run before a single account exists.

**Idempotent.** Re-running the same CSV skips accounts that already exist
instead of erroring. Onboarding files get re-sent; the script should tolerate
that.

**`-WhatIf` support** via `SupportsShouldProcess`, so a run can be rehearsed
against production without touching it.

Output is a `Created / Skipped / Failed` summary plus a timestamped log file,
and the script exits non-zero on failure so it can drive a scheduled task.

### CSV format

```csv
FirstName,LastName,Department,Title,JobOU
Jane,Doe,IT,Help Desk Technician,"OU=IT,OU=LabUsers,DC=lab,DC=local"
```

---

## `Test-DomainHealth.ps1`

```powershell
.\Test-DomainHealth.ps1
.\Test-DomainHealth.ps1 -ExportCsv .\dc01-health.csv   # evidence for a ticket
```

This is the first thing I run when someone reports *"I can't log in"* or
*"the network is down."* Everything it does is a read, so it is safe on a
production DC mid-incident.

It checks, in the order that actually narrows a problem down:

1. **Core services** — NTDS, DNS, Netlogon, W32Time, KDC. If these are stopped, authentication is broken and every other symptom is downstream noise.
2. **DNS resolution** of the domain — a DC that cannot resolve its own domain fails both replication and logons.
3. **Replication failures** — any non-zero count means changes are not converging between DCs.
4. **Time skew** — Kerberos rejects tickets past a 5-minute skew, which users experience as random, intermittent logon failures. Easy to miss, quick to check.
5. **SYSVOL / NETLOGON shares** — if these are unreachable, Group Policy silently stops applying to every client.
6. **Disk space** — a full system volume stops the AD database from writing.

Results come back as objects, so they format to a table, export to CSV for a
ServiceNow attachment, or pipe into monitoring. Exit codes: `0` clean, `1`
warnings, `2` failures.

---

## Requirements

- Windows Server 2022 (or Windows 11 with RSAT)
- `ActiveDirectory` module: `Install-WindowsFeature RSAT-AD-PowerShell`
- Rights to create users in the target OU (for `New-LabADUser.ps1` only)
