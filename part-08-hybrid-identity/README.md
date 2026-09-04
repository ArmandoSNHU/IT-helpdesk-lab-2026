# Part 8 — Hybrid Identity with Entra Connect

**Goal:** One identity per person. A user created in on-prem AD appears in Entra
ID, signs into Microsoft 365 with the same password, and is disabled in both
places by a single offboarding action.

This is the part that ties [Part 2](../part-02-active-directory/) to
[Part 7](../part-07-entra-id-m365/), and it is the design most mid-size
organisations are actually running.

---

## Choosing an authentication method

Entra Connect offers three. Picking the wrong one is expensive to reverse.

| Method | How it authenticates | Needs on-prem servers up? | Notes |
|---|---|---|---|
| **Password Hash Sync (PHS)** | Hash-of-a-hash synced to Entra; cloud validates | **No** | Simplest, most resilient. Enables leaked-credential detection. |
| Pass-through Auth (PTA) | Cloud passes credentials to an on-prem agent | Yes | Password never stored in cloud; needs agents highly available |
| Federation (AD FS) | Redirects to on-prem AD FS farm | Yes | Most control, most infrastructure, most to break |

**This lab uses PHS**, and that is what I would recommend for most organisations.

The deciding argument is availability. With PTA or AD FS, an on-prem outage — a
failed DC, a dead internet link, an expired AD FS certificate — means nobody can
sign into Microsoft 365 either. With PHS, cloud authentication keeps working
while the office is down. That is exactly when people most need email.

**What is actually synced:** not the password, and not the NT hash. Entra Connect
takes the MD4 hash, salts it, and applies 1,000 rounds of PBKDF2-HMAC-SHA256,
then syncs *that*. It is not reversible into a usable credential, and it cannot
be replayed against on-prem AD.

A useful side effect: because Microsoft holds the hash, it can compare it against
breach corpora and flag users whose credentials appear in known leaks. PTA and
federation do not get that.

---

## Prepare before installing

### 1. Verify the domain

The public domain must be verified in Entra ID before UPNs will match.

### 2. Fix UPN suffixes — do this first

The common failure: on-prem AD uses a non-routable domain such as `lab.local`.
That suffix cannot be verified in Entra ID, so every synced user lands as
`user@mandolab.onmicrosoft.com` instead of their real address.

```powershell
# Add a routable UPN suffix to the forest
Get-ADForest | Set-ADForest -UPNSuffixes @{Add = "gomeztech.dev"}

# Re-stamp existing users
Get-ADUser -Filter * -SearchBase "OU=LabUsers,DC=lab,DC=local" -Properties UserPrincipalName |
    ForEach-Object {
        $new = $_.UserPrincipalName -replace '@lab\.local$', '@gomeztech.dev'
        Set-ADUser $_ -UserPrincipalName $new
        Write-Verbose "$($_.SamAccountName) -> $new"
    }
```

Fixing UPNs *after* the first sync means cleaning up duplicate identities. Fix
them before.

### 3. Run IdFix

Microsoft's IdFix tool scans AD for objects that will fail to sync: duplicate
proxy addresses, invalid characters, blank required attributes. Run it and clear
every finding before installing Entra Connect. Every error it reports is a sync
failure you would otherwise debug one object at a time.

---

## Install and scope

Custom installation, because Express syncs the entire directory:

- **Sign-in:** Password Hash Synchronisation, with single sign-on enabled
- **OU filtering:** sync `OU=LabUsers` only — service accounts and computer objects have no reason to exist in the cloud
- **Password writeback:** enabled, so SSPR from [Part 7](../part-07-entra-id-m365/) actually updates the on-prem password
- **Source anchor:** `ms-DS-ConsistencyGuid` (the default) — it survives a move between forests, unlike `objectGUID`

OU filtering is a security control, not just tidiness. Anything synced is
attack surface in the cloud; a service account with a weak password does not
belong there.

---

## Verify

```powershell
Import-Module ADSync

# Sync schedule -- 30 minutes by default
Get-ADSyncScheduler | Select-Object SyncCycleEnabled, NextSyncCyclePolicyType, NextSyncCycleStartTimeInUTC

# Force a delta sync instead of waiting
Start-ADSyncSyncCycle -PolicyType Delta

# Full sync -- only after changing filtering or attribute rules
Start-ADSyncSyncCycle -PolicyType Initial
```

Confirm a user made it across:

```powershell
Connect-MgGraph -Scopes "User.Read.All"
Get-MgUser -UserId "jane.doe@gomeztech.dev" -Property OnPremisesSyncEnabled,OnPremisesSamAccountName,UserPrincipalName |
    Select-Object UserPrincipalName, OnPremisesSyncEnabled, OnPremisesSamAccountName
```

`OnPremisesSyncEnabled = True` confirms the object is mastered on-prem. That
matters, because a synced object cannot be edited in the cloud — attribute
changes must be made in AD and synced.

---

## Troubleshooting notes

| Symptom | Usual cause |
|---|---|
| User synced with `@*.onmicrosoft.com` | UPN suffix not routable or not verified — fix on-prem, then re-sync |
| "Unable to update this object" in the sync log | Duplicate proxyAddress or UPN; run IdFix |
| Password change on-prem not reflected in cloud | PHS is separate from directory sync — check the `PasswordHashSync` status |
| SSPR resets cloud but desktop login still fails | Password writeback not enabled |
| Deleted user keeps returning | Object still in a synced OU; disable and move it out of scope |
| Duplicate identities after a rebuild | Source anchor changed — restore `ms-DS-ConsistencyGuid` |

The Synchronization Service Manager (`miisclient.exe`) shows every connector run
with per-object errors, and it is a faster path to the actual cause than the
Entra portal.

---

## Offboarding, end to end

The reason this design is worth the setup: disabling one AD account propagates
everywhere.

```powershell
$user = "jdoe"
Disable-ADAccount -Identity $user
Get-ADUser $user -Properties MemberOf | Select-Object -ExpandProperty MemberOf |
    ForEach-Object { Remove-ADGroupMember -Identity $_ -Members $user -Confirm:$false }
Move-ADObject -Identity (Get-ADUser $user).DistinguishedName -TargetPath "OU=Disabled,DC=lab,DC=local"
Start-ADSyncSyncCycle -PolicyType Delta
```

Within one sync cycle the cloud account is blocked, group-based licensing
releases the licence, and Microsoft 365 access stops — from a single change in
one directory.

---

## Skills demonstrated

Hybrid identity architecture · authentication method trade-offs (PHS / PTA /
federation) · UPN suffix remediation · IdFix pre-flight · OU-scoped sync ·
password writeback · source anchor selection · sync troubleshooting ·
end-to-end offboarding

---

**Next:** [Part 9 — ServiceNow PDI](../part-09-servicenow/)
