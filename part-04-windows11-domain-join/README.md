# Part 4 — Windows 11 Domain Join

**Status:** in progress — writeup pending. The AD side it depends on is complete
in [Part 2](../part-02-active-directory/) and [Part 3](../part-03-ad-users-cmd/).

## Planned

- Join a Windows 11 client to `lab.local`
- Verify the computer object lands in the correct OU
- Confirm the client resolves the domain and authenticates against the DC
- Validate Group Policy is received (`gpresult /r`)

## Already usable

Domain-join problems are almost always DNS, time skew, or a DC service being
down. [`scripts/Test-DomainHealth.ps1`](../scripts/) checks all three and is
read-only, so it is safe to run mid-incident:

```powershell
.\Test-DomainHealth.ps1
```
