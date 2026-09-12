# Tears down everything built for the Three-Tier Sandbox Network project.
# Run this when you're done with a session so nothing (especially Azure Bastion) keeps billing.

$tenantDomain = (az ad signed-in-user show --query userPrincipalName -o tsv).Split('@')[1]

Write-Host "Deleting resource group rg-three-tier-lab (this removes every resource inside it, including Bastion)..."
az group delete --name rg-three-tier-lab --yes --no-wait

Write-Host "Deleting mock team identities (these are tenant-level, not part of the resource group)..."
az ad user delete --id "netadmin@$tenantDomain"
az ad user delete --id "vmoperator@$tenantDomain"
az ad user delete --id "reader@$tenantDomain"

Write-Host "Teardown requested. Resource group deletion runs in the background (--no-wait) -- check 'az group list -o table' in a few minutes to confirm it's gone."
