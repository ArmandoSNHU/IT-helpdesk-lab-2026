# Part 7 — Entra ID and a Microsoft 365 Dev Tenant

**Goal:** Stand up a real cloud identity tenant, create and license users, and
apply the security baseline that every modern helpdesk is expected to support.

---

## Getting a tenant

The **Microsoft 365 Developer Program** gives a free E5 sandbox tenant. E5
matters here: it includes Entra ID P2, which is what Conditional Access and
Privileged Identity Management need. The free trial tiers do not.

The tenant renews only while it is being used, so the lab has to actually run.

```
Tenant: mandolab.onmicrosoft.com
Licence: Microsoft 365 E5 (developer)
```

---

## Users, groups, and why licensing goes on the group

Create users in Entra admin center or PowerShell:

```powershell
Connect-MgGraph -Scopes "User.ReadWrite.All", "Group.ReadWrite.All"

$password = @{
    Password                      = (Read-Host -AsSecureString "Initial password" |
                                     ConvertFrom-SecureString -AsPlainText)
    ForceChangePasswordNextSignIn = $true
}

New-MgUser -DisplayName "Jane Doe" `
           -UserPrincipalName "jane.doe@mandolab.onmicrosoft.com" `
           -MailNickname "jane.doe" `
           -AccountEnabled `
           -PasswordProfile $password
```

Then assign licences to a **group**, not to each user:

```powershell
$group = New-MgGroup -DisplayName "Licensed-M365-E5" `
                     -MailEnabled:$false -SecurityEnabled `
                     -MailNickname "licensed-m365-e5"
```

**Group-based licensing is the whole point.** Assigning a licence per user means
every joiner and leaver is a manual step someone forgets, and offboarding leaves
paid licences attached to disabled accounts. Assign to the group, manage
membership, and licensing follows automatically. In a hybrid setup that group
can be synced from on-prem AD, so an HR-driven AD change drives cloud licensing
end to end.

---

## Security baseline

### Multi-factor authentication

Security Defaults turns MFA on for everyone in one click and is the correct
choice for a small tenant with no P1/P2 licences.

This lab uses **Conditional Access instead**, because Security Defaults and
Conditional Access are mutually exclusive, and CA is what real environments run.

| Policy | Assignment | Condition | Control |
|---|---|---|---|
| Require MFA for admins | Directory role: Global Admin, User Admin, Helpdesk Admin | any | Require MFA |
| Require MFA for all users | All users, excluding break-glass | any | Require MFA |
| Block legacy authentication | All users | Client apps: legacy auth clients | Block |

**Block legacy authentication is the single highest-value policy here.** Legacy
protocols such as basic auth in older Exchange clients cannot present an MFA
challenge, so an attacker with valid credentials bypasses MFA entirely by
choosing an old protocol. Blocking it closes the bypass.

### Break-glass account

Before enabling any policy that could lock you out, create an emergency access
account:

- Cloud-only, `.onmicrosoft.com` domain, not federated
- Long random password stored offline
- **Excluded from every Conditional Access policy**
- Permanent Global Administrator
- Sign-in alerting enabled so any use is noticed

Without one, a misconfigured Conditional Access policy locks every administrator
out of the tenant, and recovery becomes a support ticket with Microsoft. This is
the step people skip once and never skip again.

---

## Self-service password reset

SSPR is a helpdesk ticket-volume decision as much as a security one — password
resets are consistently among the highest-volume ticket categories.

- Enabled for all users
- Two authentication methods required
- Registration enforced at next sign-in
- Writeback enabled (needs Entra Connect — see [Part 8](../part-08-hybrid-identity/))

Writeback matters: without it a user resets their cloud password and their
on-prem domain password stays unchanged, so the desktop login still fails and
they call anyway.

---

## Verify

```powershell
# Confirm the CA policies exist and are on
Get-MgIdentityConditionalAccessPolicy |
    Select-Object DisplayName, State | Format-Table -AutoSize

# Check licence assignment
Get-MgUserLicenseDetail -UserId "jane.doe@mandolab.onmicrosoft.com" |
    Select-Object SkuPartNumber

# Sign-in logs -- the first place to look for "MFA is not prompting"
Get-MgAuditLogSignIn -Top 20 |
    Select-Object CreatedDateTime, UserPrincipalName, AppDisplayName,
                  @{n='Status';e={$_.Status.ErrorCode}},
                  @{n='CA';e={($_.AppliedConditionalAccessPolicies |
                               Where-Object Result -eq 'success').DisplayName -join ','}}
```

The sign-in log is the tool that resolves most cloud identity tickets. It shows
which Conditional Access policies evaluated, which applied, and the exact error
code — far faster than guessing at configuration.

---

## Troubleshooting notes

| Symptom | Usual cause |
|---|---|
| MFA not prompting | Security Defaults still on, or the user is excluded from the CA policy |
| "You cannot access this right now" | A CA policy is blocking — read the sign-in log entry, not the client error |
| Licence assignment fails | Usage location not set on the user; it is a required attribute |
| SSPR resets cloud but not desktop | Password writeback not enabled in Entra Connect |
| Legacy client cannot sign in | Working as intended — that is the block legacy auth policy |

---

## Skills demonstrated

Entra ID tenant administration · user and group lifecycle via Microsoft Graph
PowerShell · group-based licensing · Conditional Access design · MFA
enforcement · legacy authentication blocking · break-glass account planning ·
SSPR · sign-in log analysis

---

**Next:** [Part 8 — Hybrid Identity with Entra Connect](../part-08-hybrid-identity/)
