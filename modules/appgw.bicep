param paramAppGatewayName string
param paramlocation string
param paramAgwSubnetId string


// Application Gateway Managed Identity
resource applicationGatewayIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: '${paramAppGatewayName}Identity'
  location: paramlocation
}

// Application Gateway Public IP
resource pipAppGateway 'Microsoft.Network/publicIPAddresses@2023-05-01' = {
  name: 'pip-agw-${paramlocation}'
  location: paramlocation
  sku: {name: 'Standard'}
  properties: {publicIPAllocationMethod: 'Static'}
}

// Application Gateway
resource resApplicationGateway 'Microsoft.Network/applicationGateways@2023-05-01' = {
  name: paramAppGatewayName
  location: paramlocation
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${applicationGatewayIdentity.id}': {}
    }
  }
  properties: {
    sku: {
      name: 'Standard_v2'
      tier: 'Standard_v2'
    }
    autoscaleConfiguration:{
      minCapacity: 0
      maxCapacity: 10
    }
    gatewayIPConfigurations: [
      {
        name: 'appGatewayIpConfig'
        properties: {
          subnet: {
            id: paramAgwSubnetId
          }
        }
      }
    ]
    frontendIPConfigurations: [
      {
        name: 'appGatewayFrontendIp'
        properties: {
          publicIPAddress: {
            id: pipAppGateway.id
          }
        }
      }
    ]
    frontendPorts: [
      {
        name: 'port_80'
        properties: {
          port: 80
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'myBackendPool'
      }
    ]
    backendHttpSettingsCollection: [
      {
        name: 'myHTTPSetting'
        properties: {
          port: 80
          protocol: 'Http'
          cookieBasedAffinity: 'Disabled'
          requestTimeout: 30
          pickHostNameFromBackendAddress: true
        }
      }
    ]
    httpListeners: [
      {
        name: 'myListener'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations', paramAppGatewayName, 'appGatewayFrontendIp')
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts', paramAppGatewayName, 'port_80')
          }
          protocol: 'Http'
        }
      }
    ]
    requestRoutingRules: [
      {
        name: 'myRoutingRule'
        properties: {
          ruleType: 'Basic'
          priority: 1000
          httpListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners', paramAppGatewayName, 'myListener')
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools', paramAppGatewayName, 'myBackendPool')
          }
          backendHttpSettings: {
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection', paramAppGatewayName, 'myHTTPSetting')
          }
        }
      }
    ]
    // firewallPolicy: {
    //   id: wafPolicy.id
    // }
  }
}

output outAppGatewayId string = resApplicationGateway.id
output outAppGatewayManId string = applicationGatewayIdentity.id
output outAppGatewayName string = resApplicationGateway.name
output outAppGatewayManName string = applicationGatewayIdentity.name
