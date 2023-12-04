
param paramlocation string = resourceGroup().location
param paramNatGatewayName string = 'aks-sp-natgateway'
param paramNatGatewayPip string = 'aks-sp-natgateway-pip'
param paramLogAnalyticsName string = 'aks-sp-loganalytics'
param aksClusterSshPublicKey string
param paramCliKeyVaultName string
param paramKeyVaultManagedIdentityName string = '${paramCliKeyVaultName}ManagedIdentity'

resource bastionSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-05-01' existing = {name: 'azureBastionSubnet',parent: resVnet}
resource appGWSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-05-01' existing = {name: 'appGWSubnet',parent: resVnet}

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

module modAksCluster 'akscluster.bicep' = {
  name: 'AKS'
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
  }
}

module modBastion 'bastion.bicep' = {
  name: 'Bastion'
  params: {
    paramlocation: paramlocation
    paramBastionSubnet: bastionSubnet.id
    paramBastionSku: 'Developer'
  }
}

module modAppGW 'appgw.bicep' = {
  name: 'AppGateway'
  params: {
    paramAgwSubnetId: appGWSubnet.id
    paramAppGatewayName: 'aks-sp-appGW'
    paramlocation: paramlocation
  }
}

module managedPrometheus 'managedPrometheus.bicep' = {
  name: 'aks-sp-Prometheus'
  params: {
    clusterName: modAksCluster.outputs.outClusterName
    paramMonitorWorkspaceName: 'aks-sp-Monitor-Workspace'
    paramlocation: paramlocation
    actionGroupId: actionGroup.outputs.outActionGroupId
  }
}

module managedGrafana 'managedGrafana.bicep' = {
  name: 'Grafana'
  params: {
    paramGrafanaName: 'aks-sp-grafana'
    paramMonitorWorkspaceName: 'aks-sp-Monitor-Workspace'
    paramlocation: paramlocation
    paramPrometheusId: managedPrometheus.outputs.id
    paramPrometheusName: 'Prometheus'
  }
}

module actionGroup 'actionGroup.bicep' = {
  name: 'Action-Group'
  params: {
    emailAddress: 'alexander.pendleton@qualyfi.co.uk'
    paramActionGroupName: 'aks-sp-action-group'
  }
}

module identity 'identity.bicep' = {
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

module modKeyvault 'keyvault.bicep' = {
  name: 'keyVault'
  params: {
    paramlocation: paramlocation
    paramkeyVaultName: paramCliKeyVaultName
    paramKeyVaultManagedIdentityName: paramKeyVaultManagedIdentityName
  }
}

output outBastionSubnetId string = bastionSubnet.id
