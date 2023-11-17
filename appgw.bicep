param paramAppGatewayName string
param paramlocation string
param paramAgwSubnetId string
param paramProdFqdn string

var varAgwId = resourceId('Microsoft.Network/applicationGateways', paramAppGatewayName)

// <-- APPLICATION GATEWAY RESOURCES --> //
resource resApplicationGateway 'Microsoft.Network/applicationGateways@2020-11-01' = {
  name: paramAppGatewayName
  tags: {
    Owner: 'Sandy'
    Dept: 'Hub'
  }
  location: paramlocation
  properties: {
    sku: {
      name: 'Standard_v2'
      tier: 'Standard_v2'
    }
    autoscaleConfiguration:{
      minCapacity: 1
      maxCapacity: 2
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
        properties: {
          backendAddresses: [
            {
              fqdn: paramProdFqdn
            }
          ]
        }
      }
    ]
    backendHttpSettingsCollection: [
      {
        name: 'myHTTPSetting'
        properties: {
          port: 80
          protocol: 'Http'
          cookieBasedAffinity: 'Disabled'
        }
      }
    ]
    httpListeners: [
      {
        name: 'myListener'
        properties: {
          frontendIPConfiguration: {
            id: '${varAgwId}/frontendIPConfigurations/appGatewayFrontendIp'
          }
          frontendPort: {
            id: '${varAgwId}/frontendPorts/port_80'
          }
          protocol: 'Http'
          sslCertificate: null
        }
      }
    ]
    requestRoutingRules: [
      {
        name: 'myRoutingRule'
        properties: {
          ruleType: 'Basic'
          httpListener: {
            id: '${varAgwId}/httpListeners/myListener'
          }
          backendAddressPool: {
            id: '${varAgwId}/backendAddressPools/myBackendPool'
          }
          backendHttpSettings: {
            id: '${varAgwId}/backendHttpSettingsCollection/myHTTPSetting'
          }
        }
      }
    ]
  }
}

resource pipAppGateway 'Microsoft.Network/publicIPAddresses@2022-01-01' = {
  name: 'pip-agw-${paramlocation}'
  tags: {
    Owner: 'Sandy'
    Dept: 'Hub'
  }
  location: paramlocation
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    idleTimeoutInMinutes: 4
    publicIPAddressVersion: 'IPv4'
  }
}
