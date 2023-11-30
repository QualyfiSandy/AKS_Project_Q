param applicationGatewayIdentityName string
param aksClusterName string
param aksIdentityName string
param paramkeyVaultName string
param paramKeyVaultManagedIdentityName string

var netContributorRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4d97b98b-1d4f-4787-a291-c67834d212e7')
var acrPullRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')
var readerRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'acdd72a7-3385-48ef-bd42-f606fba81ae7')
var contributorRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c')

resource aks 'Microsoft.ContainerService/managedClusters@2023-09-01' existing = {name: aksClusterName}
resource applicationGatewayIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = {name: applicationGatewayIdentityName}
resource aksClusterIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = {name: aksIdentityName}
resource keyVault 'Microsoft.KeyVault/vaults@2021-10-01' existing = {name: paramkeyVaultName}
resource KVManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = {name: paramKeyVaultManagedIdentityName}

resource appGwNetContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(applicationGatewayIdentity.id, netContributorRoleId, resourceGroup().id)
  properties: {
    roleDefinitionId: netContributorRoleId
    principalId: aks.properties.addonProfiles.ingressApplicationGateway.identity.objectId
    principalType: 'ServicePrincipal'
  }
}

resource acrPullRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(aksClusterIdentity.id, acrPullRoleId, resourceGroup().id)
  properties: {
    roleDefinitionId: acrPullRoleId
    principalId: aks.properties.identityProfile.kubeletidentity.objectId
    principalType: 'ServicePrincipal'
  }
}

resource contributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(aksClusterIdentity.id, contributorRoleId, resourceGroup().id)
  properties: {
    roleDefinitionId: contributorRoleId
    principalId: aksClusterIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource appGwContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(applicationGatewayIdentity.id, contributorRoleId, resourceGroup().id)
  properties: {
    roleDefinitionId: contributorRoleId
    principalId: aks.properties.addonProfiles.ingressApplicationGateway.identity.objectId
    principalType: 'ServicePrincipal'
  }
}

// resource keyVaultReaderRoleAssignment  'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
//   name: guid(KVManagedIdentity.id, readerRoleId, resourceGroup().id)
//   properties: {
//     roleDefinitionId: readerRoleId
//     principalId: KVManagedIdentity.properties.principalId
//     principalType: 'ServicePrincipal'
//   }
// }

// resource keyVaultAdminRoleAssignment  'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
//   name: guid(KVManagedIdentity.id, keyVaultSecretsAdminRole.id, resourceGroup().id)
//   properties: {
//     roleDefinitionId: keyVaultSecretsAdminRole.id
//     principalId: KVManagedIdentity.properties.principalId
//     principalType: 'ServicePrincipal'
//   }
// }

// resource keyVaultSecretsUserApplicationGatewayIdentityRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' =  {
//   name: guid(keyVault.id, 'ApplicationGateway', 'keyVaultSecretsUser')
//   scope: keyVault
//   properties: {
//     roleDefinitionId: keyVaultSecretsUserRole.id
//     principalType: 'ServicePrincipal'
//     principalId: applicationGatewayIdentity.properties.principalId
//   }
// }

// resource keyVaultSecretsUserRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
//   name: '4633458b-17de-408a-b874-0445c86b69e6'
//   scope: subscription()
// }

// resource keyVaultSecretsAdminRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
//   name: '00482a5a-887f-4fb3-b363-3b7fe8e74483'
//   scope: subscription()
// }

// resource keyVaultCSIdriverSecretsUserRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
//   name: guid(aks.id, 'CSIDriver', keyVaultSecretsUserRole.id)
//   scope: keyVault
//   properties: {
//     roleDefinitionId: keyVaultSecretsUserRole.id
//     principalType: 'ServicePrincipal'
//     principalId: aks.properties.addonProfiles.azureKeyvaultSecretsProvider.identity.objectId
//   }
// }
