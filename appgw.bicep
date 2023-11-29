param paramAppGatewayName string
param paramlocation string
param paramAgwSubnetId string

// var varAgwId = resourceId('Microsoft.Network/applicationGateways', paramAppGatewayName)

resource applicationGatewayIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: '${paramAppGatewayName}Identity'
  location: paramlocation
}

resource pipAppGateway 'Microsoft.Network/publicIPAddresses@2023-05-01' = {
  name: 'pip-agw-${paramlocation}'
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

// <-- APPLICATION GATEWAY RESOURCES --> //
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
      name: 'WAF_v2'
      tier: 'WAF_v2'
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
          sslCertificate: null
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
    firewallPolicy: {
      id: wafPolicy.id
    }
  }
}

resource wafPolicy 'Microsoft.Network/ApplicationGatewayWebApplicationFirewallPolicies@2022-07-01' = {
  name: 'WAF-Policy'
  location: paramlocation
  properties: {
    customRules: [
      {
        name: 'BlockMe'
        priority: 1
        ruleType: 'MatchRule'
        action: 'Block'
        matchConditions: [
          {
            matchVariables: [
              {
                variableName: 'QueryString'
              }
            ]
            operator: 'Contains'
            negationConditon: false
            matchValues: [
              'blockme'
            ]
          }
        ]
      }
      {
        name: 'BlockEvilBot'
        priority: 2
        ruleType: 'MatchRule'
        action: 'Block'
        matchConditions: [
          {
            matchVariables: [
              {
                variableName: 'RequestHeaders'
                selector: 'User-Agent'
              }
            ]
            operator: 'Contains'
            negationConditon: false
            matchValues: [
              'evilbot'
            ]
            transforms: [
              'Lowercase'
            ]
          }
        ]
      }
    ]
    policySettings: {
      mode: 'Prevention'
      state: 'Enabled'
    }
    managedRules: {
      managedRuleSets: [
        {
          ruleSetType: 'OWASP'
          ruleSetVersion: '3.2'
        }
      ]
    }
  }
}



output outAppGatewayId string = resApplicationGateway.id
output outAppGatewayManId string = applicationGatewayIdentity.id
output outAppGatewayName string = resApplicationGateway.name
output outAppGatewayManName string = applicationGatewayIdentity.name
