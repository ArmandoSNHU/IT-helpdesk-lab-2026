\# IT Helpdesk Lab 2026



A hands-on Windows Server 2022 + Active Directory home lab built from scratch on \*\*Hyper-V\*\*, documenting the exact day-one tasks performed by IT Helpdesk technicians and Junior SysAdmins in real-world environments.



> Built and documented by \*\*Armando Gomez\*\* — AI Systems / Network Engineer, Laredo, TX



\---



\## Why this lab exists



Most "learn IT" content stays at the slideshow level. This repo is the opposite — every part is a fully reproducible build with screenshots, PowerShell scripts, troubleshooting notes, and the kind of documentation a real IT shop would expect.



The lab walks through provisioning a Windows Server 2022 Domain Controller, joining a Windows 11 client to the domain, enforcing security policy via Group Policy, managing patches with WSUS and Action1, extending identity to the cloud with Entra ID, and handling tickets in ServiceNow — the same workflow used in production helpdesk environments.



\---



\## Lab Architecture (Phase 1 — On-prem)



```

┌─────────────────────────────────────────────────────────┐

│              Hyper-V Host (Windows 11 Pro)              │

│                                                         │

│  ┌──────────────────────┐    ┌──────────────────────┐   │

│  │  DC01                │    │  WIN11-CLIENT01      │   │

│  │  Windows Server 2022 │◄──►│  Windows 11 Pro      │   │

│  │  AD DS / DNS / DHCP  │    │  Domain-joined       │   │

│  │  Static: 10.0.0.10   │    │  Static: 10.0.0.20   │   │

│  └──────────────────────┘    └──────────────────────┘   │

│                  Internal vSwitch: LAB-NET              │

└─────────────────────────────────────────────────────────┘

```



\*\*Domain:\*\* `mandolab.local`



\---



\## Lab Parts



\### Phase 1 — On-prem foundation

| # | Part | Skills | Status |

|---|------|--------|--------|

| 1 | \[Hyper-V + Windows Server 2022 Install](./part-01-hyperv-server-2022/) | Hyper-V, vSwitch, ISO install, initial config | 🟡 In progress |

| 2 | \[Active Directory + PowerShell Promotion](./part-02-active-directory/) | AD DS role, DC promotion, DNS | ⚪ Not started |

| 3 | \[AD Users, OUs, and Command Prompt](./part-03-ad-users-cmd/) | User/group/OU management, AD cmdlets | ⚪ Not started |

| 4 | \[Windows 11 Domain Join](./part-04-windows11-domain-join/) | Win11 install, static IP, domain join | ⚪ Not started |

| 5 | \[Group Policy + Password Policies](./part-05-group-policy/) | GPO creation, password/lockout, security baselines | ⚪ Not started |

| 6 | \[WSUS + Action1 Patching](./part-06-wsus-action1-patching/) | WSUS install, Action1 enrollment, audit reports | ⚪ Not started |



\### Phase 2 — Cloud + ticketing

| # | Part | Skills | Status |

|---|------|--------|--------|

| 7 | \[Entra ID + M365 Dev Tenant](./part-07-entra-id-m365/) | Microsoft 365 dev tenant, Entra ID, cloud users | ⚪ Not started |

| 8 | \[Hybrid Identity / Entra Connect](./part-08-hybrid-identity/) | Sync on-prem AD to Entra ID | ⚪ Not started |

| 9 | \[ServiceNow PDI](./part-09-servicenow/) | ITSM workflows, ticket lifecycle, knowledge base | ⚪ Not started |



\### Phase 3 — Operations

| # | Part | Skills | Status |

|---|------|--------|--------|

| 10 | \[Monitoring + Documentation](./part-10-monitoring-docs/) | Event Viewer, PRTG, runbooks, SOPs | ⚪ Not started |



\---



\## Skills Demonstrated



\*\*Windows Server / AD:\*\* AD DS · DNS · DHCP · Group Policy · PowerShell automation

\*\*Endpoint / Helpdesk:\*\* Windows 11 deployment · domain join · static IP · account lockout workflow

\*\*Cloud / Identity:\*\* Microsoft Entra ID · M365 admin · hybrid identity · Entra Connect

\*\*Patching / Compliance:\*\* WSUS · Action1 · audit reporting

\*\*Ticketing / ITSM:\*\* ServiceNow · ticket lifecycle · knowledge base

\*\*Monitoring / Ops:\*\* Event Viewer · PRTG · runbooks · SOP documentation



\---



\## About the Author



\*\*Armando Gomez\*\* — AI Systems / Network Engineer at the Laredo Police Department Real-Time Crime Center. Background spans network engineering, AI/ML systems, drone operations, and homelab infrastructure. Pursuing an MS in Artificial Intelligence at Colorado State University Global.



\- 📧 Armandogom83@yahoo.com

\- 🔗 GitHub: \[@ArmandoSNHU](https://github.com/ArmandoSNHU)



\---



\## License



MIT — see \[LICENSE](./LICENSE).

