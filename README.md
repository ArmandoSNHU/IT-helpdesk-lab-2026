# IT Helpdesk Lab 2026

[![Windows Server](https://img.shields.io/badge/Windows%20Server-2022-0078d4)](https://www.microsoft.com/windows-server)
[![Identity](https://img.shields.io/badge/Identity-Active%20Directory%20%2B%20Entra%20ID-2563eb)](#skills-demonstrated)
[![Lab](https://img.shields.io/badge/Lab-Documented%20Build-success)](#lab-parts)

IT Helpdesk Lab 2026 is a hands-on Windows infrastructure lab that documents the day-one work performed by helpdesk technicians and junior systems administrators: virtual machine provisioning, Windows Server setup, Active Directory, DNS, DHCP, domain join, Group Policy, patching, cloud identity, ticketing, monitoring, and operational documentation.

The lab is built on Hyper-V with screenshots, commands, troubleshooting notes, and step-by-step documentation.

## Lab Architecture

```text
Hyper-V Host (Windows 11 Pro)
|
|-- DC01
|   |-- Windows Server 2022
|   |-- AD DS / DNS / DHCP
|   |-- Static IP: 10.0.0.10
|
|-- WIN11-CLIENT01
|   |-- Windows 11 Pro
|   |-- Domain joined
|   |-- Static IP: 10.0.0.20
|
`-- Internal vSwitch: LAB-NET
```

Domain: `mandolab.local`

## Lab Parts

### Phase 1: On-Prem Foundation

| # | Part | Skills | Status |
| --- | --- | --- | --- |
| 1 | [Hyper-V + Windows Server 2022 Install](./part-01-hyperv-server-2022/) | Hyper-V, vSwitch, ISO install, initial server config | In progress |
| 2 | [Active Directory + PowerShell Promotion](./part-02-active-directory/) | AD DS role, domain controller promotion, DNS | Not started |
| 3 | [AD Users, OUs, and Command Prompt](./part-03-ad-users-cmd/) | User, group, OU, and AD command management | Not started |
| 4 | [Windows 11 Domain Join](./part-04-windows11-domain-join/) | Client setup, static IP, domain join | Not started |
| 5 | [Group Policy + Password Policies](./part-05-group-policy/) | GPOs, password policy, lockout policy, baselines | Not started |
| 6 | [WSUS + Action1 Patching](./part-06-wsus-action1-patching/) | WSUS, endpoint enrollment, audit reporting | Not started |

### Phase 2: Cloud And Ticketing

| # | Part | Skills | Status |
| --- | --- | --- | --- |
| 7 | [Entra ID + M365 Dev Tenant](./part-07-entra-id-m365/) | Microsoft 365 tenant, Entra ID, cloud users | Not started |
| 8 | [Hybrid Identity / Entra Connect](./part-08-hybrid-identity/) | On-prem to cloud identity sync | Not started |
| 9 | [ServiceNow PDI](./part-09-servicenow/) | ITSM workflow, ticket lifecycle, knowledge base | Not started |

### Phase 3: Operations

| # | Part | Skills | Status |
| --- | --- | --- | --- |
| 10 | [Monitoring + Documentation](./part-10-monitoring-docs/) | Event Viewer, monitoring, runbooks, SOPs | Not started |

## Skills Demonstrated

| Area | Skills |
| --- | --- |
| Windows Server | Server Manager, AD DS, DNS, DHCP, PowerShell administration |
| Directory Services | Domain controller promotion, OUs, users, groups, domain join |
| Endpoint Support | Windows 11 setup, account workflows, troubleshooting, local networking |
| Security Baselines | Password policy, account lockout, Group Policy enforcement |
| Patching | WSUS, Action1, endpoint inventory, compliance reporting |
| Cloud Identity | Microsoft Entra ID, Microsoft 365 admin, hybrid identity concepts |
| ITSM | ServiceNow tickets, knowledge articles, operational documentation |
| Operations | Event Viewer, runbooks, SOPs, monitoring documentation |

## Repository Structure

```text
IT-helpdesk-lab-2026/
├── part-01-hyperv-server-2022/
├── part-02-active-directory/
├── part-03-ad-users-cmd/
├── part-04-windows11-domain-join/
├── part-05-group-policy/
├── part-06-wsus-action1-patching/
├── part-07-entra-id-m365/
├── part-08-hybrid-identity/
├── part-09-servicenow/
├── part-10-monitoring-docs/
├── docs/
├── scripts/
├── LICENSE
└── README.md
```

## Documentation Standard

Each lab part should include:

- Goal and business context.
- Prerequisites.
- Step-by-step build procedure.
- Screenshots that prove completion.
- Validation commands or checks.
- Troubleshooting notes.
- Skills demonstrated.

## Lab Safety

This is a local training lab. Do not expose domain controllers, lab clients, RDP, SMB, or admin portals directly to the public internet. Do not reuse production passwords, real employee accounts, or private organizational configuration.

## Author

Armando Gomez  
GitHub: [@ArmandoSNHU](https://github.com/ArmandoSNHU)  
Portfolio: [gomezdev.tech](https://gomezdev.tech)

## License

MIT. See [LICENSE](./LICENSE).

