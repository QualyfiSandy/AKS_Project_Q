param applicationGatewayIdentityName string
param aksClusterName string

var netContributorRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4d97b98b-1d4f-4787-a291-c67834d212e7')

resource aks 'Microsoft.ContainerService/managedClusters@2023-09-01' existing = {
  name: aksClusterName
}

resource applicationGatewayIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = {
  name: applicationGatewayIdentityName
}

resource appGwNetContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(applicationGatewayIdentity.id, netContributorRoleId, resourceGroup().id)
  properties: {
    roleDefinitionId: netContributorRoleId
    principalId: aks.properties.addonProfiles.ingressApplicationGateway.identity.objectId
    principalType: 'ServicePrincipal'
  }
}
