# Part 9 — ServiceNow: ITSM Practice on a Personal Developer Instance

**Goal:** Work tickets the way a service desk actually does — correct
categorisation, honest priority, documented resolution, and a knowledge article
that stops the next occurrence.

I use ServiceNow daily at the Laredo Police Department RTCC. This part documents
the workflow on a free Personal Developer Instance so it is reviewable.

---

## Getting an instance

A **Personal Developer Instance (PDI)** is free from the ServiceNow Developer
Program. It hibernates after ~10 days idle and is reclaimed after longer, so it
has to be used to be kept.

---

## Incident vs. Request — the distinction that drives everything

Miscategorising here corrupts every metric downstream.

| | Incident | Service Request |
|---|---|---|
| Means | Something is **broken** | Someone **wants** something |
| Example | "Outlook crashes on launch" | "Please install Visio" |
| Measured by | Restore time, MTTR | Fulfilment time against SLA |
| Drives | Problem management | Capacity and licensing planning |

Filing a software install as an Incident inflates the incident count and makes
the environment look less stable than it is. Filing a genuine outage as a Request
hides it from problem management, so the root cause is never investigated.

---

## Priority is calculated, not chosen

ServiceNow derives Priority from **Impact × Urgency**. That is deliberate: it
stops priority becoming a negotiation about who is loudest.

| Impact ↓ / Urgency → | High | Medium | Low |
|---|---|---|---|
| **High** (site / many users) | P1 Critical | P2 High | P3 Moderate |
| **Medium** (department) | P2 High | P3 Moderate | P4 Low |
| **Low** (one user) | P3 Moderate | P4 Low | P5 Planning |

- **Impact** = how many people are affected — an objective fact
- **Urgency** = how quickly it must be fixed — driven by business need

A single user who cannot print is Low impact. The whole finance department on
payroll day is High impact and High urgency regardless of headcount.

---

## Ticket lifecycle

```
New ──► In Progress ──► On Hold ──► Resolved ──► Closed
                          │
                    (awaiting caller / vendor / change)
```

Two rules that matter in practice:

**On Hold must state what it is waiting for.** "On Hold" with no reason is
indistinguishable from an abandoned ticket, and it pauses the SLA clock — which
is exactly why it gets misused.

**Resolved is not Closed.** Resolved means the technician believes it is fixed;
Closed means the caller agrees or the auto-close window elapsed. Collapsing the
two removes the caller's chance to say it is still broken.

---

## Worked example

**INC0010023 — Domain user cannot sign in after password change**

| Field | Value |
|---|---|
| Caller | Jane Doe |
| Category | Inquiry / Help → Access |
| Configuration Item | WIN11-CLIENT01 |
| Impact | Low (1 user) |
| Urgency | High (cannot work) |
| **Priority** | **P3 Moderate** (calculated) |
| Assignment group | Service Desk |

**Work notes** (internal — the diagnostic trail):

```
09:14  Caller reset password via SSPR. Cloud sign-in to M365 succeeds;
       domain sign-in on WIN11-CLIENT01 fails with "username or password
       is incorrect".
09:19  Split symptom -- cloud works, on-prem does not -- points at password
       writeback rather than the account itself.
09:22  Ran Test-DomainHealth.ps1 against DC01: all checks PASS. DC is healthy,
       so this is not a replication or time-skew issue.
09:27  Entra Connect: password writeback shows Disabled. Root cause found.
09:31  Enabled writeback, forced delta sync.
09:34  Caller re-ran SSPR, confirmed domain sign-in succeeds.
```

**Close notes** (customer-facing — plain language, no jargon):

> Your password reset was updating your Microsoft 365 account but not your
> Windows sign-in, because password writeback was turned off. It has been
> enabled and your reset now applies to both. No action is needed from you.

**Resolution code:** Solved (Permanently)
**Knowledge:** KB0010012 created (below)

The `Test-DomainHealth.ps1` step is worth noting — ruling the DC out in three
minutes is what made the writeback cause obvious rather than a guess.

---

## Knowledge article

Ticket volume only falls if fixes get written down.

**KB0010012 — SSPR resets cloud password but Windows sign-in still fails**

- **Symptom:** User resets via SSPR, Microsoft 365 works, domain sign-in does not
- **Cause:** Password writeback disabled in Entra Connect, so the reset never reaches on-prem AD
- **Resolution:** Entra Connect → Configure → Customize synchronization options → enable password writeback → force delta sync
- **Verify:** `Get-ADSyncScheduler`, then have the caller re-run SSPR
- **Applies to:** Hybrid identity with password hash sync

A good article states the *symptom as the user reports it*, because that is what
the next technician searches for — not the root cause, which is unknown at the
time of the search.

---

## Metrics worth watching

| Metric | Why |
|---|---|
| First Contact Resolution | Rising FCR means knowledge articles are working |
| Mean Time To Resolve, by category | Isolates the categories that need automation or training |
| Reopen rate | High reopens mean tickets are being closed prematurely |
| Ticket volume by category | The top category is the automation candidate |
| SLA breach rate | Distinguishes a staffing problem from a process problem |

Recurring incidents in one category are the trigger for a **Problem** record —
incident management restores service, problem management stops it recurring.

---

## Skills demonstrated

ITIL incident and request management · impact/urgency priority modelling ·
ticket lifecycle and state discipline · structured work notes and customer-facing
close notes · knowledge article authoring · service desk metrics · problem
management triggers

---

**Next:** [Part 10 — Monitoring and Documentation](../part-10-monitoring-docs/)
