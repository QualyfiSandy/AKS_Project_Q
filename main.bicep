
param paramlocation string = resourceGroup().location
param paramNatGatewayName string = 'aks-sp-natgateway'
param paramNatGatewayPip string = 'aks-sp-natgateway-pip'
param paramLogAnalyticsName string = 'aks-sp-loganalytics'
param aksClusterSshPublicKey string
param paramCliKeyVaultName string
param paramKeyVaultManagedIdentityName string = '${paramCliKeyVaultName}ManagedIdentity'

resource resLogAnalytics 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: paramLogAnalyticsName
  location: paramlocation
  properties: {
    sku: {
      name: 'PerNode'
    }
    retentionInDays: 90
    forceCmkForQuery: false
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
    features: {
      disableLocalAuth: false
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    workspaceCapping: {
      dailyQuotaGb: -1
    }
  }
}

resource natGatewayPublicIp 'Microsoft.Network/publicIPAddresses@2021-05-01' = {
  name: paramNatGatewayPip
  location: paramlocation
  sku: {name: 'Standard'}
  properties: {publicIPAllocationMethod: 'Static'}
}

resource natgateway 'Microsoft.Network/natGateways@2021-05-01' = {
  name: paramNatGatewayName
  location: paramlocation
  sku: {name: 'Standard'}
  properties: {
    idleTimeoutInMinutes: 4
    publicIpAddresses: [
      {id: natGatewayPublicIp.id}
    ]
  }
}

// <-- CORE VIRTUAL NETWORK --> //
resource resVnet 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: 'aks-sp-vnet-${paramlocation}'
  location: paramlocation
  properties: {
    addressSpace: {
      addressPrefixes: ['10.0.0.0/8']
    }
    subnets: [
      {
        name: 'azureBastionSubnet'
        properties: {addressPrefix: '10.4.2.0/24'}
      }
      {
        name: 'appGWSubnet'
        properties: {addressPrefix: '10.4.1.0/24'}
      }
      {
        name: 'systemPoolSubnet'
        properties: {
          addressPrefix: '10.1.0.0/16'
          natGateway: {id: natgateway.id}
      }
      }
      {
        name: 'appPoolSubnet'
        properties: {
          addressPrefix: '10.2.0.0/16'
          natGateway: {id: natgateway.id}
      }
      }
      {
        name: 'podSubnet'
        properties: {
          addressPrefix: '10.3.0.0/16'
          natGateway: {id: natgateway.id}
      }
      }
    ]
  }
}

module modAksCluster 'modules/akscluster.bicep' = {
  name: 'AKS'
  dependsOn: [
    resVnet
  ]
  params: {
    clusterName: 'aks-sp-cluster'
    paramAppGwId: modAppGW.outputs.outAppGatewayId
    agentCount: 3
    agentVMSize: 'standard_B2s'
    dnsPrefix: 'aksspdnsprefix'
    paramAKSEIDAdminGroupId: 'c049d1ab-87d3-491b-9c93-8bea50fbfbc3'
    paramK8sVersion: '1.28.3'
    paramlocation: paramlocation
    paramDnsServiceIp: '10.5.0.10'
    paramPodCidr: '10.244.0.0/16'
    paramServiceCidr: '10.5.0.0/16'
    paramTenantId: 'd4003661-f87e-4237-9a9b-8b9c31ba2467'
    paramLogAnalyticsId: resLogAnalytics.id
    linuxAdminUsername: 'akssandyp'
    sshRSAPublicKey: aksClusterSshPublicKey
    paramSystemPoolSubnetId: resVnet.properties.subnets[2].id
    paramAppPoolSubnetId: resVnet.properties.subnets[3].id
    paramPodSubnetId: resVnet.properties.subnets[4].id
  }
}

// module modBastion 'modules/bastion.bicep' = {
//   name: 'Bastion'
//   params: {
//     paramlocation: paramlocation
//     paramBastionSubnet: resVnet.properties.subnets[0].id
//     paramBastionSku: 'Basic'
//   }
// }

module modAppGW 'modules/appgw.bicep' = {
  name: 'AppGateway'
  params: {
    paramAgwSubnetId: resVnet.properties.subnets[1].id
    paramAppGatewayName: 'aks-sp-appGW'
    paramlocation: paramlocation
  }
}

// module managedPrometheus 'modules/managedPrometheus.bicep' = {
//   name: 'aks-sp-Prometheus'
//   params: {
//     clusterName: modAksCluster.outputs.outClusterName
//     paramMonitorWorkspaceName: 'aks-sp-Monitor-Workspace'
//     paramlocation: paramlocation
//   }
// }

// module managedGrafana 'modules/managedGrafana.bicep' = {
//   name: 'Grafana'
//   params: {
//     paramGrafanaName: 'aks-sp-grafana'
//     paramMonitorWorkspaceName: 'aks-sp-Monitor-Workspace'
//     paramlocation: paramlocation
//     paramPrometheusId: managedPrometheus.outputs.id
//     paramPrometheusName: 'Prometheus'
//   }
// }

module identity 'modules/identity.bicep' = {
  name: 'Identity'
  dependsOn: [
    modAppGW
    modAksCluster
  ]
  params: {
    aksClusterName: modAksCluster.outputs.outClusterName
    applicationGatewayIdentityName: modAppGW.outputs.outAppGatewayManName
    aksIdentityName: modAksCluster.outputs.outClusterManIdentityName
    paramKeyVaultManagedIdentityName: paramKeyVaultManagedIdentityName
    paramkeyVaultName: paramCliKeyVaultName
  }
}

module modKeyvault 'modules/keyvault.bicep' = {
  name: 'keyVault'
  params: {
    paramlocation: paramlocation
    paramkeyVaultName: paramCliKeyVaultName
    paramKeyVaultManagedIdentityName: paramKeyVaultManagedIdentityName
  }
}

output outBastionSubnetId string = resVnet.properties.subnets[0].id
output outAppGWSubnetId string = resVnet.properties.subnets[1].id
output outSystemPoolSubnetId string = resVnet.properties.subnets[2].id
output outAppPoolSubnetId string = resVnet.properties.subnets[3].id
output outPodSubnetId string = resVnet.properties.subnets[4].id
