param paramlocation string
param paramkeyVaultName string
param objectIds array = []
param skuName string = 'standard'
param tenantId string = subscription().tenantId

resource keyVault 'Microsoft.KeyVault/vaults@2021-10-01' = {
  name: paramkeyVaultName
  location: paramlocation
  properties: {
    accessPolicies: [for objectId in objectIds: {
      tenantId: subscription().tenantId
      objectId: objectId
      permissions: {
        keys: [
          'get'
          'list'
        ]
        secrets: [
          'get'
          'list'
        ]
        certificates: [
          'get'
          'list'
        ]
      }
    }]
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
