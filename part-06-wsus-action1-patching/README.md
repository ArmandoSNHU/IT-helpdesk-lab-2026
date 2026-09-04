# Part 6 — Patch Management: WSUS and Action1

**Goal:** Get every endpoint in the lab patched, reporting, and provable — then
be able to answer "is CVE-XXXX remediated?" with evidence rather than a guess.

---

## Why two tools

WSUS and Action1 solve overlapping problems from opposite ends, and running both
is what a small IT shop actually looks like.

| | WSUS | Action1 |
|---|---|---|
| Runs | On-prem, on the DC or a member server | Cloud, agent on the endpoint |
| Covers | Microsoft updates only | Microsoft **plus third-party** (Chrome, Zoom, Reader, 7-Zip) |
| Reaches | Domain-joined machines on the LAN/VPN | Anything with internet, including remote laptops |
| Cost | Free with Windows Server | Free tier up to 200 endpoints |

**The gap that matters:** WSUS does not patch third-party software, and roughly
that is where a large share of exploited endpoint vulnerabilities live — an
outdated Chrome or Adobe Reader is a far more common entry point than an
unpatched Windows kernel. A shop running only WSUS is patching half the problem.

The second gap is reach. A laptop that has not been on the corporate network for
three weeks has not talked to WSUS in three weeks. The Action1 agent checks in
over the internet regardless.

---

## Part A — WSUS on Windows Server 2022

### Install

```powershell
# WSUS with the internal Windows Internal Database. On a larger deployment this
# would point at SQL Server instead; WID is fine for a lab and small sites.
Install-WindowsFeature -Name UpdateServices -IncludeManagementTools

# Post-install configuration. The content directory must be on a volume with
# room to grow -- update content easily reaches tens of GB.
& "$env:ProgramFiles\Update Services\Tools\wsusutil.exe" postinstall CONTENT_DIR=D:\WSUS
```

> **Sizing note:** point `CONTENT_DIR` at a data volume, never `C:`. A full
> system drive on a domain controller stops the AD database from writing, which
> turns a patching problem into an authentication outage.

### Configure the scope

Synchronising *everything* is the classic first mistake — it pulls hundreds of
GB of products the lab does not run. Select only what exists:

- **Products:** Windows 11, Windows Server 2022, Microsoft Defender
- **Classifications:** Critical Updates, Security Updates, Definition Updates, Update Rollups
- **Languages:** English only

Definition Updates (Defender) are included deliberately — they ship multiple
times a day and are the one classification you never want to defer.

### Computer groups

```
All Computers
├── Servers          (DC01)          -- patch last, after a validated ring
├── Workstations     (WIN11-CLIENT01)
└── Pilot            -- one machine from each group; patches land here first
```

The Pilot ring is the point. Patches go Pilot → Workstations → Servers, with a
soak period between each. Approving straight to Servers is how a bad update
takes down a domain controller.

### Point clients at WSUS by Group Policy

`Computer Configuration → Policies → Administrative Templates → Windows Components → Windows Update`

| Setting | Value | Why |
|---|---|---|
| Specify intranet Microsoft update service location | `http://DC01:8530` | Both the update and statistics server |
| Configure Automatic Updates | 4 — auto download and schedule install | |
| Enable client-side targeting | `Workstations` | Puts the machine in the right group automatically |
| No auto-restart with logged on users | Enabled | Prevents an update rebooting a user mid-task |

**Port 8530, not 80.** WSUS moved off port 80 in Server 2012; pointing clients at
`http://DC01` silently fails to connect.

### Verify

```powershell
# Force a detection cycle instead of waiting up to 22 hours
wuauclt /detectnow /reportnow      # legacy
(New-Object -ComObject Microsoft.Update.AutoUpdate).DetectNow()

# Confirm the client is actually pointed at WSUS
Get-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate' |
    Select-Object WUServer, WUStatusServer, TargetGroup
```

If a client never appears in the WSUS console, check in this order: the GPO
applied (`gpresult /r`), the registry keys above are present, port 8530 is
reachable, and `C:\Windows\WindowsUpdate.log` (or `Get-WindowsUpdateLog` on
Windows 10/11) for the actual error.

---

## Part B — Action1 for third-party and remote endpoints

1. Create a free organisation (200 endpoints, no cost)
2. Deploy the agent to `WIN11-CLIENT01`
3. Build an automation:
   - **Scope:** all endpoints
   - **Trigger:** weekly, Wednesday 02:00
   - **Action:** approve and install all Critical and Security updates, including third-party
   - **Reboot:** deferred, with a user prompt

Action1 is what covers the browser, the PDF reader, and the laptop that has not
touched the LAN in a month — the three things WSUS cannot see.

---

## Reporting: the part that matters in an audit

Patching that cannot be evidenced does not count. Two questions have to be
answerable on demand:

**"Is this machine current?"**

```powershell
# Last 20 installed updates with dates
Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 20 |
    Format-Table HotFixID, Description, InstalledOn -AutoSize

# Pending updates the client knows about
$session  = New-Object -ComObject Microsoft.Update.Session
$searcher = $session.CreateUpdateSearcher()
$searcher.Search("IsInstalled=0 and Type='Software'").Updates |
    Select-Object Title, @{n='Severity';e={$_.MsrcSeverity}}
```

**"Is CVE-XXXX remediated across the fleet?"** — Action1's vulnerability report
answers this per-endpoint. WSUS answers the Microsoft half through the *Update
Status Summary* report.

Export both, attach to the ticket, done. That export is the deliverable — not
the patching itself.

---

## Troubleshooting notes

| Symptom | Usual cause |
|---|---|
| Client never appears in WSUS | GPO not applied, or pointed at port 80 instead of 8530 |
| Clients appear but never report status | `WUStatusServer` missing or different from `WUServer` |
| Duplicate client entries | VMs cloned without `sysprep` share a `SusClientId`; delete the key and re-register |
| Updates download but never install | Automatic Updates set to 3 (notify) rather than 4 (schedule) |
| WSUS console crashes on large syncs | WID memory limit — decline superseded updates and run server cleanup |

Duplicate `SusClientId` is the one that wastes an afternoon in a lab, because
cloning a VM is exactly how the second machine gets built:

```powershell
Remove-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate' -Name SusClientId
Restart-Service wuauserv
wuauclt /resetauthorization /detectnow
```

---

## Skills demonstrated

WSUS role installation and post-install configuration · update scoping and
classifications · ring-based deployment groups · client-side targeting via GPO ·
third-party patching with Action1 · compliance reporting and evidence export ·
patch troubleshooting from the client log up

---

**Next:** [Part 7 — Entra ID + M365 Dev Tenant](../part-07-entra-id-m365/)
