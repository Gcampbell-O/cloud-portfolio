# DevSecOps: security scanning built into the pipeline

Security checks that run automatically on every pull request to this repo, so insecure code, leaked secrets, vulnerable libraries and misconfigured infrastructure are caught **before** they reach `main` or get deployed to Azure ("shift left").

## The controls

| Control | What it checks | Where results appear |
|---|---|---|
| **Secret scanning** | Leaked keys, tokens and passwords anywhere in the repo history | Security tab |
| **Push protection** | Blocks a push that contains a secret, so it never reaches GitHub | At `git push` time |
| **Dependabot alerts + security updates** | Libraries with known vulnerabilities (CVEs); opens a PR with the fix | Security tab, pull requests |
| **Dependabot version updates** | Weekly PRs to keep Maven libraries and GitHub Actions current ([`dependabot.yml`](../.github/dependabot.yml)) | Pull requests |
| **CodeQL** | Security bugs in the Java code and the GitHub Actions workflows | Security tab, PR checks |
| **Checkov** (added by me) | Insecure settings in **Bicep** infrastructure as code: public access, weak TLS, open ports, missing encryption | Security tab (SARIF upload), PR checks |

**Baseline:** 0 secret scanning alerts, 0 Dependabot alerts, 0 CodeQL alerts.

## Pipeline design

[`iac-security-scan.yml`](../.github/workflows/iac-security-scan.yml) runs Checkov on every pull request and push to `main` that touches a `.bicep` file.

- **Static analysis only:** no Azure login, no deployment, no cost. It's deliberately separate from the [three-tier deploy pipeline](../three-tier-network-iac/), which deploys real resources on merge.
- **Least privilege:** the job can only read the code (`contents: read`) and upload results (`security-events: write`).
- **Report first, enforce later:** `soft_fail: true` reports findings without blocking the build, the same idea as Azure Policy's *Audit* before *Deny*. Once the remaining findings are fixed or justified, it flips to blocking.
- **One place for results:** Checkov writes SARIF, which GitHub code scanning shows next to the CodeQL results.

## Triage, not just scanning

The first scan reported **62 passed and 50 failed checks** across every Bicep file in the repo. A failed check is a suspicion, not a confirmed problem, so each one goes into one of three buckets:

| Bucket | Action |
|---|---|
| **True positive** | Fix it, then re-scan to prove the fix |
| **False positive** | Suppress it **in the code** with a written reason (`// checkov:skip=ID: reason`) |
| **Accepted risk** | Document why it stays, and the plan to fix it properly |

### Round 1: the CloudXeus storage and Windows VM modules

| Check | Bucket | Outcome |
|---|---|---|
| CKV_AZURE_44: storage uses the latest TLS | True positive | **Fixed:** `minimumTlsVersion: 'TLS1_2'` (plus explicit HTTPS-only and no anonymous blob access). Re-scan: **passed** |
| CKV_AZURE_35: storage network default is Deny | Accepted risk | The VMs download their IIS setup script from this account. The proper fix is a private endpoint |
| CKV_AZURE_206: storage replication | Accepted risk | LRS keeps lab costs down; production would use ZRS or GRS |
| CKV_AZURE_50: VM extensions installed | Accepted risk | The Custom Script Extension is how IIS gets installed, by design |
| CKV_AZURE_178: Linux VM uses SSH keys | False positive | Fired on a **Windows** VM |
| CKV_AZURE_151 / 97: VM encryption at host | True positive | **Open.** Next fix (needs the `EncryptionAtHost` feature registered on the subscription) |

**Beyond the scanner:** the Windows VM's Custom Script Extension had its script URL, **including a SAS token**, in the public `settings` block, readable by anyone with Reader access to the VM. It now sits in `protectedSettings`, which is encrypted. Checkov doesn't check for this. Scanners are a starting point, not the final word.

**Validation:** after the fixes, the re-scan showed **63 passed, 45 failed, 4 skipped**, each skip with a documented reason.

## Lessons

- **Verify the status of each finding before triaging it.** The raw Checkov log lists passed and failed checks together. The first round of suppressions landed on checks that were already passing, which the re-scan exposed: *Passed* dropped instead of *Failed*. Validating after every change is what caught it.
- **A fix can break the system.** Locking the CloudXeus storage account down would have stopped the VMs downloading their setup script. Understand the dependency before "fixing" a finding.
- **Major version bumps need review.** Dependabot opened PRs for `azure/login` v2→v3 and `actions/checkout` v4→v7. Check the release notes for breaking changes before merging.

## Next steps

- Fix encryption at host on the CloudXeus VMs.
- Triage the remaining modules (`linuxVM.bicep`, `vnet.bicep`, the three-tier template).
- Document [`mini-soc/labdeploy.bicep`](../mini-soc/) as an accepted risk: it is a deliberate honeypot, exposed to the internet on purpose.
- Switch `soft_fail` to `false`, so new insecure Bicep fails the pull request.
