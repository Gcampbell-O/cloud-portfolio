# Storage, Compute & Governance

Rounding out AZ-104's storage and compute domains beyond the VM/private-endpoint work from Projects 1 and 2, plus a first real pass at Azure governance: Policy, tags, and the RBAC/Policy distinction, all tested live rather than just configured and left alone.

## What's in it

| Area | What was built |
|---|---|
| **PaaS compute** | An Azure App Service (Linux, Node) — a live web app with zero VM to manage, patch, or SSH into |
| **Storage lifecycle** | A blob lifecycle management policy (`lifecycle-policy.json`) on a dedicated storage account: Cool at 30 days, Archive at 90, delete at 365 — fully automated, no manual tiering |
| **Governance** | An Azure Policy assignment (built-in "Allowed locations") scoped to the resource group, restricting deployments to `eastus`/`centralus` — proven live by deliberately trying to deploy outside it and watching Azure deny the request |
| **IaaS at scale** | A VM Scale Set (2 instances, Flexible orchestration mode) behind a Standard Load Balancer, with a custom health probe and NSG rule for HTTP, provisioned via cloud-init (`cloud-init.txt`) so each instance boots already running nginx |

## What broke, and what it taught

- **Quota and capacity are two different failure modes that look identical at first.** The Free (F1) and Basic (B1) App Service tiers both failed in `eastus` with "Operation cannot be completed without additional quota" — a subscription-level limit, fixable by switching to a region where quota was already available. Separately, F1 in `centralus` failed with "No available instances to satisfy this request" — Azure's own shared-tier infrastructure being full at that moment, unrelated to the subscription at all. Same symptom on the surface, completely different cause and fix.
- **`az vmss create` already provisions a default load-balancing rule.** Trying to add a second rule for the same protocol/port/backend pool combination fails outright — the fix was updating the existing auto-created rule to attach a custom health probe, not creating a new one.
- **Flexible orchestration mode VMSS instances aren't addressed by numeric instance IDs.** `az vmss run-command invoke` expects a plain integer (built for the older Uniform mode) and errors with `instanceId must be a number`. Flexible-mode instances are actually individual VM resources under the hood, so the fix was using `az vm run-command invoke` against the instance's real resource name instead.
- **A Load Balancer's health probe and its load-balancing rule are separate objects, and only one needs to break to take the whole thing down.** Repointing the probe at a port nothing was listening on took the site fully offline — not because the rule changed (it never did), but because the probe is the sole gatekeeper deciding which backends are even eligible to receive the rule's traffic. With every instance failing the same probe simultaneously, there was nowhere left for traffic to go.
- **A client's own networking can produce misleading test results.** Repeated `curl` tests from WSL kept hitting the exact same VM instance, looking like broken load balancing — actually caused by WSL's NAT layer not varying the outbound source port enough to exercise the Load Balancer's 5-tuple hash. Testing from a second, independent client (a browser on the Windows host) immediately showed traffic correctly reaching both instances, confirming the Load Balancer had been working the whole time.

## Design decisions

- **Allowed locations, not allowed blindly:** the Policy assignment scopes strictly to the regions actually used (`eastus`, `centralus`), rather than being left wide open — same least-privilege instinct as the RBAC decisions in Projects 1/2, applied to governance instead of access.
- **Health probe deliberately separated from "it just works":** rather than trusting the default probeless setup, a real probe was added and then deliberately broken to prove the failure mode understood, not just described.

## Cost and teardown

```bash
az group delete --name rg-storage-compute-lab --yes --no-wait
```

The Policy assignment, storage account, App Service resources (already torn down mid-lab), and VM Scale Set are all scoped to this one resource group — deleting it removes everything in one step.

## Built with

Azure App Service, Azure Storage (lifecycle management), Azure Policy, VM Scale Sets (Flexible orchestration), Azure Load Balancer, cloud-init.
