param paramAppGatewayName string
param paramlocation string
param paramAgwSubnetId string

var varAgwId = resourceId('Microsoft.Network/applicationGateways', paramAppGatewayName)

resource applicationGatewayIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: '${paramAppGatewayName}Identity'
  location: paramlocation
}

// <-- APPLICATION GATEWAY RESOURCES --> //
resource resApplicationGateway 'Microsoft.Network/applicationGateways@2020-11-01' = {
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
      }
    ]
    backendHttpSettingsCollection: [
      {
        name: 'myHTTPSetting'
        properties: {
          port: 80
          protocol: 'Http'
          cookieBasedAffinity: 'Disabled'
          pickHostNameFromBackendAddress: true
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
          priority: 1000
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

output outAppGatewayId string = resApplicationGateway.id
output outAppGatewayManId string = applicationGatewayIdentity.id
output outAppGatewayName string = resApplicationGateway.name
output outAppGatewayManName string = applicationGatewayIdentity.name
