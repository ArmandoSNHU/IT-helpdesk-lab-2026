# Lab documentation

Cross-cutting reference material. Per-part walkthroughs live in each
`part-NN-*/` directory; this holds what applies across the whole environment.

## Environment

| Host | Role | IP | OS |
| --- | --- | --- | --- |
| DC01 | Domain controller, DNS, DHCP, WSUS | 10.0.0.10 | Windows Server 2022 |
| WIN11-CLIENT01 | Domain-joined workstation | 10.0.0.20 | Windows 11 Pro |

Domain: `lab.local` · Forest/domain functional level: Windows Server 2016
Hypervisor: Hyper-V on Windows 11 Pro
Cloud: Microsoft 365 E5 developer tenant, hybrid via Entra Connect (PHS)

## Naming conventions

| Object | Pattern | Example |
| --- | --- | --- |
| Servers | `<ROLE><NN>` | `DC01` |
| Workstations | `<OS><NN>-CLIENT` | `WIN11-CLIENT01` |
| Users | `first.last` | `jane.doe` |
| sAMAccountName | first initial + surname, max 20 chars | `jdoe` |
| Security groups | `<Scope>-<Purpose>` | `GG-Finance-ReadWrite` |
| GPOs | `<Scope>-<Purpose>` | `Workstation-Standards` |

## OU structure

```
lab.local
├── LabUsers
│   ├── IT
│   ├── Finance
│   ├── HR
│   └── Operations
├── Workstations
├── Servers
└── Disabled          -- offboarded accounts, outside sync scope
```

Users and computers are deliberately **not** left in the default `CN=Users` and
`CN=Computers` containers: neither can have a GPO linked to it, so anything
placed there silently misses policy.

## Where to start

| I want to... | Go to |
| --- | --- |
| Build the environment from nothing | [Part 1](../part-01-hyperv-server-2022/) |
| Understand the AD design | [Part 2](../part-02-active-directory/), [Part 3](../part-03-ad-users-cmd/) |
| Fix a domain join or logon failure | [Part 4](../part-04-windows11-domain-join/) |
| Work out why a GPO is not applying | [Part 5](../part-05-group-policy/) |
| Patch and prove compliance | [Part 6](../part-06-wsus-action1-patching/) |
| Administer cloud identity | [Part 7](../part-07-entra-id-m365/), [Part 8](../part-08-hybrid-identity/) |
| See ticket handling | [Part 9](../part-09-servicenow/) |
| Monitor and document | [Part 10](../part-10-monitoring-docs/) |
| Run the automation | [scripts/](../scripts/) |

## Safety

Everything here targets an isolated Hyper-V lab. Before running any script
against a real environment:

- `Test-DomainHealth.ps1` is **read-only** and safe anywhere.
- `New-LabADUser.ps1` **writes to AD** — always run `-WhatIf` first.
- No credentials, tenant IDs, or public IPs are committed. Screenshots have
  account identifiers redacted.
