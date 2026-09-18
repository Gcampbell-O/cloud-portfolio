# Identity Hardening (Entra ID / Conditional Access)

Work in progress. Week 5 (Conditional Access) is complete; Week 6 (PIM, Access Reviews, SSPR, Key Vault) is next.

Hands-on identity security in a dedicated Microsoft Entra tenant with an Entra ID P2 trial: building Conditional Access policies, rolling them out safely, and deliberately causing and diagnosing a real lockout.

## What's in it

| Area | What was built |
|---|---|
| **Break-glass account** | A cloud-only emergency Global Administrator, assigned Active and Permanent through PIM, unlicensed, with a long random password generated in the shell and stored offline |
| **CA001** | Block legacy authentication for all users (break-glass and one working admin excluded), rolled out in Report-only |
| **CA002** | Require MFA for a single test user, rolled out in Report-only and verified in the sign-in logs |
| **CA003** | Require a compliant device for the test user, enforced On, used for the deliberate lockout and then turned Off |

## How it was rolled out

1. **Break-glass first, before any policy.** The recovery path existed before there was anything to recover from.
2. **Small blast radius.** Enforced policies targeted one test user, not the tenant.
3. **Report-only before On.** Real sign-ins were evaluated silently and the results reviewed in the sign-in logs before anything was enforced.
4. **What if for hypotheticals.** The What if tool confirmed CA001 applied to legacy clients and did not apply to browser sign-ins.

## The deliberate lockout, and what it showed

CA003 required a compliant device for the test user, who had no managed device. The sign-in stopped after the password was accepted: Conditional Access is evaluated *after* authentication, not instead of it. The resulting error was `53000`, with device state **Unregistered** and no device identifier. That means Entra had no record of the device at all, which is different from a device that is known but non-compliant. The fix was turning the policy Off, chosen over deleting it (keeps the definition) and over excluding the user (identical effect for a single-user policy). Sign-in worked again immediately.

## What broke, and what it taught

- **Two tenants by accident.** Entra's Try / Buy button was disabled and licensing had moved to the Microsoft 365 admin center. Because the working login was a guest in the original tenant, the admin center created a brand-new tenant. The lesson: a tenant is a boundary for identity, licenses, and policy. A P2 license in one tenant does nothing for users in another, and a policy built in one cannot affect the other. That boundary made the second tenant a safe place to practice a lockout.
- **Report-only results are on a separate tab.** The sign-in log's Conditional access tab lists only enforced policies. Report-only outcomes appear on their own Report only tab, so an empty Conditional access tab did not mean the policy had not evaluated.
- **Token scopes.** The default Azure CLI token for Microsoft Graph lacks the scope to read some policy objects, so a Graph call was forbidden. The portal was the simpler path for policy work.

## Design decisions

- **Break-glass is Active, not PIM-eligible.** An eligible role must be activated first, and activation can require MFA or approval, the very controls that may be broken during a lockout.
- **Exclude the break-glass account and a working admin from every policy.** A bad policy must never be able to lock out the account that fixes it.
- **Prefer Off over delete, and group exclusions over user exclusions,** to preserve the policy and keep exceptions auditable.

## Coming in Week 6

PIM (time-bound role activation), Access Reviews, self-service password reset, and Azure Key Vault referenced from a Bicep deployment.

## Built with

Microsoft Entra ID P2 (Conditional Access, PIM), Microsoft Graph via Azure CLI, Azure Portal sign-in logs.
