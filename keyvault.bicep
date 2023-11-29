param paramlocation string
param paramkeyVaultName string
param skuName string = 'standard'
param tenantId string = subscription().tenantId
param paramKeyVaultManagedIdentityName string

resource KVManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: paramKeyVaultManagedIdentityName
  location: paramlocation
}

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
    enableSoftDelete: true
  }
}

output outKVManagedIdentityName string = KVManagedIdentity.name
