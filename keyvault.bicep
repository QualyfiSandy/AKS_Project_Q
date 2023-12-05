param paramlocation string
param paramkeyVaultName string
param skuName string = 'standard'
param tenantId string = subscription().tenantId
param paramKeyVaultManagedIdentityName string


// Azure Keyvault Managed Identity
resource KVManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: paramKeyVaultManagedIdentityName
  location: paramlocation
}

// Azure Keyvault
resource keyVault 'Microsoft.KeyVault/vaults@2021-10-01' = {
  name: paramkeyVaultName
  location: paramlocation
  properties: {
    sku: {
      family: 'A'
      name: skuName
    }
    tenantId: tenantId
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
    }
    enabledForDeployment: true
    enabledForDiskEncryption: true
    enabledForTemplateDeployment: true
    enableSoftDelete: false
    enableRbacAuthorization: true
  }
}

output outKVManagedIdentityName string = KVManagedIdentity.name
