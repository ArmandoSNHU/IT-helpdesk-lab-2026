# Part 4 — Windows 11 Domain Join

**Goal:** Join a Windows 11 Pro client to `lab.local`, verify it authenticates
against DC01, and understand the three things that cause almost every failed
domain join.

---

## Prerequisites

- DC01 promoted and healthy ([Part 2](../part-02-active-directory/))
- OU structure in place ([Part 3](../part-03-ad-users-cmd/))
- **Windows 11 Pro or Enterprise.** Home cannot join a domain — there is no
  workaround, and it is the first thing to check when the option is missing.

---

## Client network configuration

The single most important setting is DNS.

```powershell
# Static IP on the lab network
New-NetIPAddress -InterfaceAlias 'Ethernet' -IPAddress 10.0.0.20 `
                 -PrefixLength 24 -DefaultGateway 10.0.0.1

# DNS MUST point at the domain controller, not the router and not 8.8.8.8
Set-DnsClientServerAddress -InterfaceAlias 'Ethernet' -ServerAddresses 10.0.0.10
```

**Why DNS is the whole game:** a client finds a domain controller by querying
DNS for `_ldap._tcp.dc._msdcs.lab.local` — an SRV record that only the AD-
integrated DNS server holds. Point the client at a public resolver and that
lookup returns nothing, so the client reports it "cannot contact the domain"
even though the DC is running perfectly.

Verify before attempting the join:

```powershell
nltest /dsgetdc:lab.local
Resolve-DnsName -Name _ldap._tcp.dc._msdcs.lab.local -Type SRV
```

If those two fail, the join will fail. Fix DNS first.

---

## Join the domain

```powershell
Add-Computer -DomainName 'lab.local' `
             -OUPath 'OU=Workstations,DC=lab,DC=local' `
             -Credential (Get-Credential) `
             -Restart
```

`-OUPath` is worth using deliberately. Without it the computer object lands in
the default `CN=Computers` container, which **cannot have Group Policy linked to
it**. Every GPO targeting workstations then silently misses the machine, and the
symptom is "policy is not applying" with no error anywhere.

---

## Verify

```powershell
# Secure channel between client and DC -- True means the trust is healthy
Test-ComputerSecureChannel -Verbose

# Which DC authenticated this session
nltest /dsgetdc:lab.local

# Confirm the computer object is in the intended OU
Get-ADComputer WIN11-CLIENT01 -Properties DistinguishedName |
    Select-Object Name, DistinguishedName

# Group Policy actually received
gpresult /r /scope:computer
```

`Test-ComputerSecureChannel` returning `False` means the machine account password
is out of sync with AD — common after restoring a VM from an old snapshot. Repair
without rejoining:

```powershell
Test-ComputerSecureChannel -Repair -Credential (Get-Credential)
```

---

## Troubleshooting

Domain join failures are almost always one of three causes, in this order:

| Symptom | Cause | Fix |
|---|---|---|
| "Domain could not be contacted" | Client DNS not pointing at the DC | `Set-DnsClientServerAddress` to the DC |
| "The specified domain either does not exist" | SRV records missing or DNS zone not AD-integrated | Check `_msdcs` zone on DC01 |
| Join succeeds, logon fails with clock error | Time skew over 5 minutes | `w32tm /resync` on the client |
| Domain option greyed out | Windows 11 **Home** | Requires Pro or Enterprise |
| Joined, but no Group Policy | Object in `CN=Computers`, not a linkable OU | `Move-ADObject` to the Workstations OU |
| Was working, now "trust relationship failed" | Machine account password out of sync | `Test-ComputerSecureChannel -Repair` |

**Kerberos time skew** deserves the emphasis. Kerberos rejects tickets more than
five minutes out, and the resulting failures look random and intermittent — a
user signs in fine one hour and not the next. It is checked explicitly by
[`scripts/Test-DomainHealth.ps1`](../scripts/) for exactly this reason.

---

## Fast triage

Run the health check against the DC before touching the client. It is read-only
and takes seconds:

```powershell
.\scripts\Test-DomainHealth.ps1
```

If DNS, time sync, and the core services all pass, the problem is on the client.
That single step removes half the search space.

---

## Skills demonstrated

Windows 11 client provisioning · static IP and DNS configuration · domain join
via PowerShell with OU targeting · secure channel verification and repair ·
Kerberos time skew diagnosis · SRV record troubleshooting

---

**Next:** [Part 5 — Group Policy](../part-05-group-policy/)
