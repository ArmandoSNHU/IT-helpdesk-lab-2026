# Part 10 — Monitoring and Documentation

**Goal:** Know something is wrong before a user reports it, and leave behind
documentation good enough that someone else can run this environment.

---

## The events that actually matter

Windows generates enormous volumes of events. Alerting on all of them produces
noise, and noise gets ignored — which is worse than no monitoring, because it
looks like coverage.

These are the ones worth a rule:

| Event ID | Log | Meaning | Why it matters |
|---|---|---|---|
| 4625 | Security | Failed logon | Bursts indicate brute force or a service account with a stale password |
| 4740 | Security | Account lockout | The single most common helpdesk ticket; catch it before the call |
| 4720 / 4726 | Security | User created / deleted | Unexpected account creation is a serious signal |
| 4728 / 4732 | Security | Added to a security group | Privilege escalation, especially into Domain Admins |
| 1074 | System | Shutdown initiated | Distinguishes a planned reboot from a crash |
| 6008 | System | Unexpected shutdown | Power or hardware fault |
| 7000 / 7001 | System | Service failed to start | Correlates with morning outages |
| 1102 | Security | **Audit log cleared** | Almost never legitimate — treat as an incident |
| 2213 | Directory Service | AD database recovery | DC storage problem |

**4740 is the highest-value one for a helpdesk.** Detecting a lockout and
identifying the source before the user finishes dialling turns a five-minute
ticket into a proactive fix.

### Finding a lockout source

```powershell
# Lockout events on the DC, with the machine that caused them
Get-WinEvent -FilterHashtable @{LogName='Security'; ID=4740} -MaxEvents 20 |
    ForEach-Object {
        $x = [xml]$_.ToXml()
        [pscustomobject]@{
            Time   = $_.TimeCreated
            User   = ($x.Event.EventData.Data | Where-Object Name -eq 'TargetUserName').'#text'
            Source = ($x.Event.EventData.Data | Where-Object Name -eq 'CallerComputerName').'#text'
        }
    } | Format-Table -AutoSize
```

The `CallerComputerName` field is the answer to "why does this account keep
locking?" — usually a phone with a saved old password, a mapped drive, or a
scheduled task running under the user's credentials.

### Failed logon patterns

```powershell
# Failed logons in the last 24h, grouped by account
Get-WinEvent -FilterHashtable @{LogName='Security'; ID=4625; StartTime=(Get-Date).AddDays(-1)} -ErrorAction SilentlyContinue |
    ForEach-Object {
        ([xml]$_.ToXml()).Event.EventData.Data |
            Where-Object Name -eq 'TargetUserName' |
            Select-Object -ExpandProperty '#text'
    } | Group-Object | Sort-Object Count -Descending |
        Select-Object Count, Name -First 10
```

One account with 200 failures is a stuck credential. Two hundred accounts with
one failure each is password spraying — a different problem entirely, and the
shape of the data is what distinguishes them.

---

## Proactive health checks

[`scripts/Test-DomainHealth.ps1`](../scripts/) is the scheduled check. It is
read-only and exits `0` clean, `1` warnings, `2` failures, so a scheduled task
can act on the result.

```powershell
$action  = New-ScheduledTaskAction -Execute 'powershell.exe' `
    -Argument '-NoProfile -ExecutionPolicy Bypass -File C:\Scripts\Test-DomainHealth.ps1 -ExportCsv C:\Reports\dc-health.csv'
$trigger = New-ScheduledTaskTrigger -Daily -At 6:00AM

Register-ScheduledTask -TaskName 'DC Health Check' -Action $action -Trigger $trigger `
    -User 'SYSTEM' -RunLevel Highest -Description 'Daily read-only DC health check'
```

Running at 06:00 means a problem is found before the first user logs in, which
is the entire point of proactive monitoring.

---

## Documentation that is actually used

Three artefacts, each with a distinct job:

### 1. Runbook — how to do a recurring task

Written for someone with the skills but not the context. The test is whether a
competent technician who has never touched this environment can follow it.

> **RB-004 — Unlock a domain account**
> 1. Confirm identity per the verification policy — never skip on a "quick" request
> 2. `Search-ADAccount -LockedOut | Where-Object SamAccountName -eq '<user>'`
> 3. Find the source: query event 4740 on the DC, read `CallerComputerName`
> 4. `Unlock-ADAccount -Identity <user>`
> 5. **Fix the cause**, or it recurs within the hour: clear the saved credential on the source device
> 6. Record the source device in the ticket — repeats across users indicate a service account issue

Step 5 is what separates a runbook from a script. Unlocking without finding the
source guarantees the same ticket tomorrow.

### 2. SOP — the standard for a process

Policy-level and less frequently changed: naming conventions, the OU structure
and why, patch rings and their soak periods, the account lifecycle, backup
schedule and retention.

### 3. Network and system diagram

```
                    Internet
                        │
                 ┌──────┴──────┐
                 │   Router    │  192.168.1.1
                 └──────┬──────┘
                        │
              ┌─────────┴─────────┐  Hyper-V vSwitch
              │                   │
    ┌─────────┴────────┐  ┌───────┴──────────┐
    │  DC01            │  │  WIN11-CLIENT01  │
    │  10.0.0.10       │  │  10.0.0.20       │
    │  Server 2022     │  │  Windows 11 Pro  │
    │  AD DS · DNS ·   │  │  Domain joined   │
    │  DHCP · WSUS     │  │  Action1 agent   │
    └──────────────────┘  └──────────────────┘
              │
              └── Entra Connect (PHS) ──► Entra ID / M365 tenant
```

A diagram answers "what talks to what" faster than any prose, and it is the
first thing anyone new asks for.

---

## What I would add next

Honest scope note — these are not built in this lab, and pretending otherwise
would defeat the purpose of the documentation:

- **Centralised log collection.** Per-machine Event Viewer does not scale past a handful of hosts. Windows Event Forwarding to a collector, or a free-tier SIEM, is the next step.
- **Uptime and service monitoring.** Something like Zabbix or Uptime Kuma for continuous checks between the daily health run.
- **Backup verification.** A backup that has never been restored is a hypothesis, not a backup.

---

## Skills demonstrated

Windows Event Log analysis and filtering with `Get-WinEvent` · XML event field
extraction · lockout source identification · brute force vs. password spray
pattern recognition · scheduled proactive health checks · runbook and SOP
authoring · network documentation

---

**Lab complete.** Back to the [overview](../README.md).
