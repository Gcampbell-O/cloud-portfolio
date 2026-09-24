# Monitoring & Backup (Azure Monitor, Log Analytics, KQL, Azure Backup)

Working through Microsoft's own official hands-on lab, [azure-monitor-lab](https://github.com/Gcampbell-O/azure-monitor-lab) (forked from [microsoft/azure-monitor-lab](https://github.com/microsoft/azure-monitor-lab)), end to end — deploying a real observability stack across a Windows and a Linux VM, two web apps, and a SQL database, then closing two remaining gaps the lab doesn't cover: deliberate KQL practice and Azure Backup.

## What's in it

| Area | What was built |
|---|---|
| **Environment** | `WS-VM1` (Windows Server, IIS), `LX-VM2` (Ubuntu), a web app + SQL database, and a second Linux web app — split across two resource groups for a real reason (below) |
| **Log Analytics** | Workspace `LogAnalytics1`: 60-day retention, a 10GB daily ingestion cap, read access scoped to a dedicated Entra security group |
| **Data collection** | Two Data Collection Rules (Windows Event Logs + IIS logs for `WS-VM1`; Performance Counters for `LX-VM2`), each auto-deploying the Azure Monitor Agent on assignment |
| **Application Insights** | Workspace-based, enabled on the SQL-backed web app, with the .NET Core Snapshot Debugger explicitly disabled |
| **Diagnostic settings** | HTTP logs and SQL Insights piped to Log Analytics; a third setting added as a reasoned best-guess for an undocumented lab task |
| **Network monitoring** | A cross-VNet Connection Monitor testing `LX-VM2` → `WS-VM1` reachability |
| **Alerting** | An action group (real email, not the lab's placeholder) wired to a CPU-utilization alert |
| **KQL** | Live queries against real data: filtering, `summarize count() by`, and `bin()`-based time-series aggregation, rendered as an actual chart |
| **Backup** | A Recovery Services vault, backup enabled on `LX-VM2`, and a real completed on-demand backup with a recovery point |

## A real quota constraint, and a deliberate deviation

The lab assumes everything lives in one resource group, `rg-alpha`. This subscription has **zero quota for both Windows and Linux App Service compute in East US** — the same limit hit back in the Storage & Compute project, this time affecting the web app + SQL deployment too. The fix: a second resource group, **`rg-alpha-app`, in Central US**, holding both web apps. Nothing in the two resource groups depends on being in the same region — App Service and SQL don't need network adjacency to the VMs — but it's a real, worth-documenting deviation from the lab's own assumption.

## What broke, and what it taught

- **A stale line-number reference pointed at a resource that no longer exists.** The lab's setup instructions say to manually delete a `Microsoft.Insights/components` block from an ARM template by line number. The actual current template, fetched and searched directly, doesn't contain that block at all — Microsoft removed it upstream since the lab was written. Confirmed with the editor's own search, not assumed from a stale line count.
- **RDP clipboard corruption, twice, in two different ways.** Once, leftover terminal scrollback got glued onto a fresh paste, producing a stray `>>` and a mangled URL. Once, a newline between two piped commands silently disappeared, merging `cd` and `Invoke-WebRequest` into one line and making PowerShell treat the second command as an unexpected argument to the first. Fixed by verifying a URL in a variable before using it, and by chaining commands with `;` instead of relying on the paste preserving line breaks.
- **The lab's own instructions are internally inconsistent about VM names** — "Linux-VM2" vs. the actually-built `LX-VM2`, and a straight typo (`WinVMDRC` for `WinVMDCR`). None of it broke anything once caught, but a KQL filter written against the *documented* name (`Computer contains "Linux-VM"`) would have silently returned nothing, looking like a failure that wasn't one.
- **One skilling task had no instructions at all.** "Enable file and configuration change tracking" was listed as a task with zero documented steps. Rather than invent an answer, the actual available diagnostic categories were read live, and **Access Audit Logs** was chosen as the closest real match — documented here explicitly as a reasoned best guess, not a confirmed correct answer.
- **Two VMs, two separate unpeered VNets, discovered by accident.** Neither VM's creation wizard was pointed at a shared network, so each got its own default VNet. Found while setting up Connection Monitor, by expanding the actual subnet list rather than trusting a status label at a glance (which happened to be a correct hint, but was verified anyway).
- **"Enable Backup" and "Backup now" are two different operations.** Enabling backup only registers protection and a policy — it does not take a backup. The Backup jobs list showed exactly one job, "Configure backup," until an explicit on-demand backup was triggered separately, which produced a second, real backup job and an actual recovery point.
- **Log ingestion has a real cost, and metrics don't.** That's why nothing reaches Log Analytics without an explicit diagnostic setting, and why the workspace has a 10GB daily cap — a direct, practical answer to "why does this cost money and that doesn't."

## Design decisions

- **Real email, not the lab's placeholder.** The lab's alert instructions use `prime@fabrikam.com`, Microsoft's fictional example domain. A real address was used instead, so the alert mechanism could actually be observed working, not just configured.
- **Least-privilege access, same as every other project.** The "App Log Examiners" security group was granted only **Log Analytics Reader**, scoped to the one workspace, not broader.
- **Verify from real state, every time an instruction was stale, ambiguous, or missing.** The template search, the raw KQL results, the Backup jobs list, the expanded subnet view — each real finding in this project came from checking actual state rather than trusting either the lab's text or an assumption.

## Cost and teardown

```bash
az group delete --name rg-alpha --yes --no-wait
az group delete --name rg-alpha-app --yes --no-wait
```

Note: `rg-alpha-app` isn't mentioned in the lab's own cleanup instructions, since it only exists because of the quota workaround above — both groups need deleting, not just the one the lab names. The "App Log Examiners" security group is deleted separately, at the tenant level, the same pattern as every prior mock-identity cleanup.

## Built with

Azure Monitor, Log Analytics, KQL, Application Insights, Data Collection Rules and Endpoints, Azure Monitor Agent, Network Watcher / Connection Monitor, Azure Backup, Recovery Services vaults.
