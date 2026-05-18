# Codex Guide

## Project Purpose

This repository documents a Windows Server 2022 and IT helpdesk home lab. It is portfolio documentation, not production infrastructure code.

## Repository Layout

- `part-01-hyperv-server-2022/` through `part-10-monitoring-docs/` - lab modules.
- `docs/` - supporting documentation.
- `scripts/` - helper scripts.
- `README.md` - main portfolio overview.
- `LICENSE` - MIT license.

## Documentation Rules

- Keep instructions reproducible and step-based.
- Every completed lab part should include screenshots or command output proving the result.
- Do not include real passwords, real tenant secrets, production domains, public IP addresses, or employer-specific configuration.
- Keep status labels accurate: `Not started`, `In progress`, or `Complete`.
- Use consistent terminology: Active Directory, AD DS, Microsoft Entra ID, Group Policy, WSUS, ServiceNow.
- Prefer PowerShell commands where they make the build repeatable.

## Recommended Lab Part Template

Each part should include:

```markdown
# Part NN: Title

## Goal

## Prerequisites

## Steps

## Validation

## Troubleshooting

## Skills Demonstrated
```

## Verification

For documentation-only changes, review Markdown rendering and check links. For script changes, run the affected script in a disposable lab environment before documenting it as complete.

