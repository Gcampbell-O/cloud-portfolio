# IaC Rebuild — Three-Tier Network (Bicep + CI/CD)

The same [Three-Tier Sandbox Network](../three-tier-sandbox-network/) from Project 1, entirely rebuilt as declarative Infrastructure as Code, with a full CI/CD pipeline that deploys it automatically — no manual `az` commands, no stored Azure credentials.

## What's in it

| Component | Details |
|---|---|
| `main.bicep` | 16 resources: 4 NSGs, a VNet with 5 subnets, Azure Bastion + public IP, a NIC + jump-box VM, a storage account + private endpoint + private DNS zone/link/zone-group, and a Network Contributor role assignment |
| `.github/workflows/deploy-three-tier.yml` | A GitHub Actions pipeline that plans on every pull request and applies automatically on merge to main |

## The pipeline

- **Identity, not a password.** The pipeline authenticates to Azure using OpenID Connect (OIDC) federated credentials — a dedicated Entra ID app registration trusts tokens from this specific repo, on specific triggers (pull request, push to main). No client secret is stored anywhere in GitHub.
- **Plan on PR, apply on merge.** Opening a pull request that touches `three-tier-network-iac/` automatically runs `az deployment group what-if`, showing exactly what would change before anything happens. Merging runs the real `az deployment group create`.
- **Least privilege, again.** The pipeline's identity holds Contributor plus User Access Administrator, both scoped to just this one resource group — not the subscription, and not Owner.

## What broke, and what it taught

- Azure federated credentials require an **exact string match** on the token's subject claim. GitHub's current token format includes the owner's and repo's permanent numeric IDs (`owner@id/repo@id`), not just the plain names — the federated credential had to be updated to match the literal value pulled from the actual error, not the documented example format.
- Contributor **cannot** create or modify role assignments (`Microsoft.Authorization/roleAssignments/write`) — that's deliberately excluded, so a Contributor-scoped identity can't escalate its own access. User Access Administrator had to be added alongside Contributor, not in place of it.

## Design decisions carried over from Project 1

Same reasoning as the manual build: segmented subnets with explicit deny-by-default NSG rules, no public IP on the jump-box (Bastion-only access), a private endpoint for storage instead of public access, and RBAC scoped narrowly instead of broad Contributor or Owner grants.

## Cost and teardown

```powershell
az group delete --name rg-three-tier-lab --yes --no-wait
az ad user delete --id "netadmin@<tenant-domain>"
```

Same pattern as Project 1 — the resource group is deleted as a whole, and the mock RBAC identity (tenant-level, not part of the resource group) is removed separately.

## Built with

Bicep, GitHub Actions, OIDC federated credentials — the whole three-tier network from Project 1, reproducible from one file and one push.
