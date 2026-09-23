# Identity Hardening (Entra ID)

Hands-on identity security in a dedicated Microsoft Entra tenant with an Entra ID P2 trial: Conditional Access, Privileged Identity Management, Access Reviews, self-service password reset, and Azure Key Vault — each one built, then deliberately tested against a real failure rather than just configured and left alone.

## What's in it

| Area | What was built |
|---|---|
| **Break-glass account** | A cloud-only emergency Global Administrator, assigned Active and Permanent through PIM, unlicensed, with a long random password generated in the shell and stored offline |
| **CA001** | Block legacy authentication for all users (break-glass and one working admin excluded), rolled out in Report-only |
| **CA002** | Require MFA for a single test user, rolled out in Report-only and verified in the sign-in logs |
| **CA003** | Require a compliant device for the test user, enforced On, used for a deliberate lockout and then turned Off |
| **PIM** | Just-in-time activation of the User Administrator role for a test user — no standing access, a bounded 1-hour activation window, required justification, and a full audit trail |
| **Access Reviews** | A recurring-style review of a test group's membership, with a real Deny decision that automatically removed a member on completion |
| **SSPR** | Self-service password reset for a test user via a registered alternate email, tested end to end: register, forget password, verify, reset |
| **Key Vault** | An RBAC-authorized vault, a secret stored and read under least privilege, and that secret referenced from a Bicep deployment without its value ever appearing in source control |

## How it was rolled out

1. **Break-glass first, before any policy.** The recovery path existed before there was anything to recover from.
2. **Small blast radius.** Enforced policies and role grants targeted one test user, not the tenant.
3. **Report-only before On, Eligible before Active, No-change before Remove-access.** Every risky default got tested in its safest mode first — Conditional Access, PIM, and Access Reviews all follow the same "prove it before enforcing it" shape.
4. **Predict, then verify from real state.** Before checking an outcome, the expected result was stated first, then checked against actual output — sign-in logs, role assignment tables, or `az` queries — rather than assumed from the UI alone.

## The deliberate lockout (Conditional Access), and what it showed

CA003 required a compliant device for the test user, who had no managed device. The sign-in stopped after the password was accepted: Conditional Access is evaluated *after* authentication, not instead of it. The resulting error was `53000`, with device state **Unregistered** and no device identifier — meaning Entra had no record of the device at all, different from a device that's known but non-compliant. The fix was turning the policy Off, chosen over deleting it (keeps the definition) and over excluding the user (identical effect for a single-user policy). Sign-in worked again immediately.

## PIM: proving no standing access

A test user was granted the User Administrator role as **Eligible**, not Active — meaning zero power until explicitly activated, for a bounded window, with a justification recorded. Before activation, the user's own "New user" control was correctly greyed out; after activation and a refresh, it worked; after deactivation, it was greyed out again. The audit trail recorded the activation, the justification text, and the deactivation, timestamped.

The first attempt at this got the assignment type wrong — created as permanent Active rather than Eligible — and the confusion wasn't obvious from the UI alone; it only became clear by reading the actual **State** and **End time** columns directly. PIM also refused to remove or deactivate that Active assignment for its first 5 minutes (`ActiveDurationTooShort`), and refused to activate a role for longer than its own eligibility window remained open (`ExpirationRule`) — both real constraints discovered from error text, not documentation.

## Access Reviews: two portals, one workflow

An access review was created against a test group with two members, one of them the break-glass account, added artificially as a "should this really have access" test case. The review's Recommended-action engine correctly flagged the break-glass account for **Deny**, based on its complete lack of sign-in activity.

The real finding: decisions clicked from the **Entra ID admin blade** (Identity Governance → Access reviews → Results) silently did not save — the review completed with 0 recorded decisions and, correctly, changed nothing, since "No change" was the configured default for non-response. The actual reviewer experience lives in a separate portal, **myaccess.microsoft.com**, which has its own Approve/Deny/Submit workflow. Once decisions were submitted there and confirmed (Approved: 1, Denied: 1) before stopping the review, the Deny decision on the break-glass account triggered a real, verified removal from the group.

## SSPR: two policy surfaces, one working method

Self-service password reset was enabled for a test user, using a registered alternate email rather than the Authenticator app. The legacy **Password Reset → Authentication methods** page only offered Security Questions (a method retiring in March 2027) — every other method, including Email OTP, has moved to a separate, newer **Authentication methods policy** page, where Email OTP was already enabled tenant-wide. The full loop was tested live: register the email at `myaccount.microsoft.com`, trigger "forgot my password," receive a real code, and successfully set a new password.

## Key Vault: RBAC, and a secret that never touched source control

A vault was created with RBAC authorization (no legacy access policies). Creating it granted no access at all, proven live — `az keyvault secret set` failed with `ForbiddenByRbac` until the account was explicitly granted **Key Vault Secrets Officer**, scoped to the vault. A secret was then stored and read back successfully.

The secret was referenced from a Bicep deployment via a parameters file's `reference` block — the secret's *name* and the vault's *ID* live in source control, never its value. Getting this working took three distinct fixes, each revealing something different:
1. `az role assignment create` itself failed with a deserialization error — a CLI bug unrelated to permissions, worked around by using the portal instead.
2. After granting a role to the "Azure Resource Manager" enterprise app, the deployment still failed with `KeyVaultParameterReferenceSecretRetrieveFailed`. The error's tenant ID didn't match the working tenant at all — proof that the identity actually resolving the reference is a separate, Microsoft-internal first-party identity, not the app the role was granted to.
3. The real mechanism turned out to be a legacy vault property, `enabledForTemplateDeployment`, unrelated to RBAC entirely. Setting it to `true` fixed the deployment immediately.

The resulting deployment history confirms the design worked: its `parameters` block shows only `{"reference": {...}, "type": "SecureString"}` — never the plaintext value — even in the permanent record of what was deployed.

## What broke, and what it taught

- **Two tenants by accident.** Entra's Try / Buy button was disabled and licensing had moved to the Microsoft 365 admin center. Because the working login was a guest in the original tenant, the admin center created a brand-new tenant. A tenant is a boundary for identity, licenses, and policy — a P2 license or a policy in one tenant does nothing in another. That boundary made the second tenant a safe place to practice a lockout, and kept the Azure-subscription-holding tenant untouched for Key Vault.
- **Report-only results are on a separate tab**, and later, **Access Review decisions have their own separate submission portal.** The same shape of mistake twice: assuming an admin-facing page does more than it actually does, and only confirming from real state (a log entry, a results count) settled it each time.
- **Similarly-named roles are an easy, real mistake.** Key Vault Certificates Officer was assigned in place of Key Vault Secrets Officer once, and PIM's own role-assignment screen once pre-filled the wrong user because two accounts shared a display name. Both were caught by checking the actual UPN or role name, not the label at a glance.
- **A UI change is not proof of a backend change.** Several "it looks fixed now" moments (PIM activation needing a refresh, a stale portal token) turned out to need direct verification from an audit log, a role assignment table, or a CLI query before trusting them.

## Design decisions

- **Break-glass is Active, not PIM-eligible.** An eligible role must be activated first, and activation can require MFA or approval — the very controls that may be broken during a lockout.
- **Exclude the break-glass account and a working admin from every Conditional Access policy.** A bad policy must never be able to lock out the account that fixes it.
- **Prefer Off over delete, and group exclusions over user exclusions,** to preserve policy definitions and keep exceptions auditable.
- **Every risky action was tested in its safe mode first:** Report-only before On, Eligible before Active, No-change before Remove-access.
- **Key Vault access is RBAC, scoped to the specific role needed** (Secrets Officer, not the broader Administrator role), matching the same least-privilege pattern used everywhere else in this project.

## Built with

Microsoft Entra ID P2 (Conditional Access, PIM, Access Reviews, SSPR), Azure Key Vault, Bicep, Microsoft Graph via Azure CLI, Azure Portal sign-in and audit logs.
