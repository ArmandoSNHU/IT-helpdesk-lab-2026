# Part 5 — Group Policy and Security Baselines

**Goal:** Enforce password and lockout policy, standardise the desktop, and be
able to prove which policies applied to a given machine.

---

## How GPOs actually apply

Precedence runs **L → S → D → OU**, and the *last* one wins:

```
Local  ►  Site  ►  Domain  ►  OU  ►  nested OU  (closest to the object wins)
```

Two modifiers change that:

- **Enforced** on a link — the GPO wins regardless of anything below it
- **Block Inheritance** on an OU — stops policies from above, except Enforced ones

Both are useful and both are overused. An environment full of Enforced links and
Block Inheritance is one where nobody can predict what a machine will receive,
which is exactly the state Group Policy exists to prevent.

---

## Password and account lockout

Domain-wide password policy lives in the **Default Domain Policy** — it is one of
the few settings that genuinely must be linked at the domain root, because it
applies to domain accounts rather than to machines.

`Computer Configuration → Policies → Windows Settings → Security Settings → Account Policies`

| Setting | Value | Reasoning |
|---|---|---|
| Minimum password length | 14 | Length beats complexity; current NIST guidance favours longer passphrases |
| Password history | 24 | Prevents cycling back to a favourite |
| Maximum password age | 365 days | Forced 90-day rotation drives predictable patterns like `Summer2026!` |
| Minimum password age | 1 day | Stops instant cycling through history |
| Complexity requirements | Enabled | Still required by most compliance frameworks |
| **Account lockout threshold** | **10** | |
| Lockout duration | 15 minutes | |
| Reset counter after | 15 minutes | |

**Why threshold 10 rather than 3:** a low threshold is a self-inflicted denial of
service. A phone with a stale saved password locks the account repeatedly, and
the helpdesk absorbs the calls. Ten attempts still stops guessing while
tolerating the ordinary case of a user mistyping.

**Why a 365-day maximum age:** NIST SP 800-63B moved away from mandatory periodic
rotation, because forced frequent changes produce weaker, more predictable
passwords. Rotate on evidence of compromise instead.

---

## Fine-Grained Password Policy for admins

Domain policy is one-size-fits-all. Privileged accounts should be stricter, and
that requires a Password Settings Object rather than a GPO:

```powershell
New-ADFineGrainedPasswordPolicy -Name 'PSO-Admins' `
    -Precedence 10 `
    -MinPasswordLength 20 `
    -PasswordHistoryCount 24 `
    -MaxPasswordAge '90.00:00:00' `
    -LockoutThreshold 5 `
    -LockoutDuration '00:30:00' `
    -LockoutObservationWindow '00:30:00' `
    -ComplexityEnabled $true

Add-ADFineGrainedPasswordPolicySubject -Identity 'PSO-Admins' -Subjects 'Domain Admins'
```

Lower `Precedence` wins when a user is subject to more than one PSO.

---

## Desktop standardisation

Separate GPOs by purpose rather than one large policy — a single monolithic GPO
is impossible to troubleshoot or roll back selectively.

| GPO | Linked to | Does |
|---|---|---|
| `Baseline-Security` | Domain | Password/lockout, audit policy, Defender |
| `Workstation-Standards` | Workstations OU | Screen lock at 15 min, disable removable storage write |
| `Drive-Mappings` | LabUsers OU | Mapped drives by security group |
| `Printer-Deployment` | LabUsers OU | Printers by department |

Drive mappings use **Group Policy Preferences with item-level targeting**, so one
GPO serves every department:

```
User Configuration → Preferences → Windows Settings → Drive Maps
  S:  \\DC01\Shared      -- targeting: member of Domain Users
  F:  \\DC01\Finance     -- targeting: member of Finance
```

Item-level targeting is the alternative to a separate GPO per department, and it
scales far better.

---

## Verify — always verify

```powershell
# What actually applied to this machine and user
gpresult /r
gpresult /h C:\gpreport.html      # full HTML report, including denied GPOs

# Force a refresh instead of waiting 90 minutes (+/- 30 random offset)
gpupdate /force

# Inventory every GPO and its links
Get-GPO -All | Select-Object DisplayName, GpoStatus, ModificationTime |
    Sort-Object ModificationTime -Descending

# Export one GPO's settings to review
Get-GPOReport -Name 'Baseline-Security' -ReportType Html -Path .\baseline.html
```

`gpresult /h` is the tool that resolves most "policy is not applying" tickets. It
lists **denied** GPOs with the reason — wrong OU, security filtering, WMI filter —
which is far faster than inspecting each policy by hand.

---

## Troubleshooting

| Symptom | Usual cause |
|---|---|
| GPO not applying to a machine | Computer object is in `CN=Computers`, which cannot be linked to |
| Applies to some users, not others | Security filtering — check *Authenticated Users* has Read + Apply |
| Settings revert after reboot | Two GPOs conflict; the one closest to the object wins |
| Nothing applies anywhere | SYSVOL or NETLOGON unreachable — clients cannot read policy files |
| Drive maps missing for some users | Item-level targeting group membership; log off and on for a new token |
| Changes take up to 2 hours | Normal — 90 min refresh plus up to 30 min random offset |

**The SYSVOL case is the quiet one.** Group Policy files live in the SYSVOL
share; if it is unreachable or not replicating between DCs, policy silently stops
applying with no obvious client error. That is why
[`scripts/Test-DomainHealth.ps1`](../scripts/) checks both SYSVOL and NETLOGON
explicitly, alongside the AD replication that keeps them in sync.

---

## Skills demonstrated

GPO precedence and inheritance · domain password and lockout policy design ·
Fine-Grained Password Policies · Group Policy Preferences with item-level
targeting · security filtering · RSoP analysis with `gpresult` · GPO reporting
via PowerShell · policy troubleshooting from SYSVOL up

---

**Next:** [Part 6 — WSUS and Action1 Patching](../part-06-wsus-action1-patching/)
