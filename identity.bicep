param applicationGatewayIdentityName string
param aksClusterName string
param aksIdentityName string

var netContributorRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4d97b98b-1d4f-4787-a291-c67834d212e7')
var acrPullRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')
// var readerRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'acdd72a7-3385-48ef-bd42-f606fba81ae7')
var contributorRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c')

resource aks 'Microsoft.ContainerService/managedClusters@2023-09-01' existing = {name: aksClusterName}
resource applicationGatewayIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = {name: applicationGatewayIdentityName}
resource aksClusterIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = {name: aksIdentityName}

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
