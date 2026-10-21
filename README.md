# Gbolahan Campbell, Azure Cloud Administrator

**Microsoft Certified: Azure Administrator Associate (AZ-104)** · Azure Security, Compliance & Identity Fundamentals (SC-900) · Azure Fundamentals (AZ-900)

I design, build, secure and troubleshoot Azure environments, and I document every one end to end. This repo holds seven hands-on Azure engineering projects: networking, infrastructure as code with CI/CD, identity security, monitoring and backup, governance, and a working security operations setup that detected and shut down a live brute-force attack.

Each project covers **what was built, the design decisions, what broke and how it was fixed, and what it cost to run.** Every fix is backed by real error text or live state, never guesswork.

---

## Featured: catching a real attack

**[Mini-SOC: Defender for Cloud + Microsoft Sentinel](mini-soc/)**
I exposed two VMs to the internet on purpose. Within about 20 minutes, real attackers were guessing SSH passwords: **3,661 attempts from 30 IP addresses, with 0 successful logins**. I wrote a Sentinel analytics rule (KQL, MITRE ATT&CK T1110) that turned the raw logs into incidents and triaged them. Then I closed the management ports with **just-in-time VM access**, and showed from the logs that the attacks dropped to **zero** while log collection stayed healthy. The evidence, with attacker IPs masked, is in the repo.

## Projects

| Project | What it demonstrates | Key result |
|---|---|---|
| [**Mini-SOC**](mini-soc/) | Defender for Cloud, Microsoft Sentinel, KQL detections, incident triage, JIT access, Azure Monitor Agent and data collection rules | A live SSH brute-force attack detected, triaged and stopped |
| [**CloudXeus Case Study**](cloudxeus-case-study/) | Modular Bicep for a full environment: peered VNets, Azure Bastion, an internal load balancer, IIS via Custom Script Extension, Key Vault secret references | A repeatable dev environment from code, every bug fixed from real deployment errors |
| [**IaC Rebuild: Three-Tier Network**](three-tier-network-iac/) | Bicep plus a **GitHub Actions** pipeline using **OIDC federated credentials** (no stored secrets); `what-if` on pull request, deploy on merge | 16 resources deployed from one file and one push, with least-privilege pipeline access |
| [**Three-Tier Sandbox Network**](three-tier-sandbox-network/) | Segmented VNet (web, app, data, management), NSG deny-by-default between tiers, Bastion-only access, private endpoint plus private DNS for storage, scoped RBAC | No public IP on any workload, and storage reachable only privately |
| [**Identity Hardening**](identity-hardening/) | Entra ID: break-glass account, Conditional Access (report-only before enforcing), PIM just-in-time roles, Access Reviews, SSPR, Key Vault with RBAC | A deliberate Conditional Access lockout diagnosed from sign-in logs and recovered |
| [**Monitoring & Backup**](monitoring-and-backup/) | Log Analytics, Azure Monitor Agent with data collection rules, Application Insights, KQL, alerts and action groups, Connection Monitor, Azure Backup | End-to-end observability across Windows, Linux, web apps and SQL, plus a verified recovery point |
| [**Storage, Compute & Governance**](storage-compute-governance/) | App Service, blob lifecycle policies, Azure Policy, VM Scale Sets behind a Standard Load Balancer, cloud-init | A policy proven by a denied deployment, and load balancer failure modes reproduced and explained |

## Skills, with evidence

| Area | Where to see it |
|---|---|
| **Identity & governance**: Entra ID, RBAC and custom roles, Conditional Access, PIM, Azure Policy, management groups, locks | [Identity Hardening](identity-hardening/), [Storage, Compute & Governance](storage-compute-governance/) |
| **Networking**: VNets and subnetting, NSGs, peering, Bastion, private endpoints and private DNS, load balancers, Network Watcher | [Three-Tier Sandbox](three-tier-sandbox-network/), [CloudXeus](cloudxeus-case-study/), [Mini-SOC](mini-soc/) |
| **Compute**: Windows and Linux VMs, VM Scale Sets, App Service, extensions, cloud-init, quota vs capacity | [CloudXeus](cloudxeus-case-study/), [Storage, Compute & Governance](storage-compute-governance/) |
| **Storage**: private-only storage accounts, lifecycle management, SAS, Key Vault-backed secrets | [Three-Tier Sandbox](three-tier-sandbox-network/), [CloudXeus](cloudxeus-case-study/) |
| **Monitoring & recovery**: Log Analytics, KQL, data collection rules, alerts, Application Insights, Azure Backup | [Monitoring & Backup](monitoring-and-backup/), [Mini-SOC](mini-soc/) |
| **Security operations**: Defender for Cloud, Microsoft Sentinel analytics rules, incident triage, just-in-time access | [Mini-SOC](mini-soc/) |
| **Infrastructure as code & automation**: Bicep (modules, parameters, loops), ARM what-if, GitHub Actions with OIDC, Azure CLI, PowerShell | [IaC Rebuild](three-tier-network-iac/), [CloudXeus](cloudxeus-case-study/) |

## How I work

- **Least privilege by default:** narrowly scoped roles, private networking, and no secrets in source control.
- **Safe rollout:** report-only before enforcing, eligible before active, and `what-if` before deploying.
- **Verify from real state:** sign-in logs, the Activity Log, `az` queries and KQL, not what the UI or the docs suggest.
- **Cost discipline:** one resource group per project, prices checked before deploying, and a confirmed teardown every time.
