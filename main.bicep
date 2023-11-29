
param clusterName string = 'aks-sp-cluster'
param paramlocation string = resourceGroup().location
param dnsPrefix string = 'aksspdnsprefix'
param agentCount int = 3
param agentVMSize string = 'standard_DS2_v2'
// param linuxAdminUsername string = 'akssandy'
// param sshRSAPublicKey string = 

param paramNatGatewayName string = 'aks-sp-natgateway'
param paramNatGatewayPip string = 'aks-sp-natgateway-pip'
param paramLogAnalyticsName string = 'aks-sp-loganalytics'
param paramTenantId string = 'd4003661-f87e-4237-9a9b-8b9c31ba2467'
param paramAKSEIDAdminGroupId string = 'c049d1ab-87d3-491b-9c93-8bea50fbfbc3'
param paramK8sVersion string = '1.28.3'
param paramPodCidr string = '10.244.0.0/16'
param paramServiceCidr string = '10.5.0.0/16'
param paramDnsServiceIp string = '10.5.0.10'

resource podSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-05-01' existing = {name: 'podSubnet',parent: resVnet}
resource systemPoolSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-05-01' existing = {name: 'systemPoolSubnet',parent: resVnet}
resource appPoolSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-05-01' existing = {name: 'appPoolSubnet',parent: resVnet}
resource bastionSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-05-01' existing = {name: 'azureBastionSubnet',parent: resVnet}
resource appGWSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-05-01' existing = {name: 'appGWSubnet',parent: resVnet}

resource aksClusterUserDefinedManagedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' = {
  name: '${clusterName}ManagedIdentity'
  location: paramlocation
}

resource aks 'Microsoft.ContainerService/managedClusters@2023-09-01' = {
  name: clusterName
  location: paramlocation
  sku: {
    name: 'Base'
    tier: 'Free'
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${aksClusterUserDefinedManagedIdentity.id}':{
      }
    }
  }
  properties: {
    kubernetesVersion: paramK8sVersion
    disableLocalAccounts: true
    enableRBAC: true
    dnsPrefix: dnsPrefix
    agentPoolProfiles: [
      {
        name: 'systempool'
        count: agentCount
        minCount: 2
        maxCount: 10
        maxPods: 50
        enableAutoScaling: true
        vmSize: agentVMSize
        vnetSubnetID: systemPoolSubnet.id
        podSubnetID: podSubnet.id
        osType: 'Linux'
        osSKU: 'CBLMariner'
        mode: 'System'
        // osProfile: {
        //   linuxProfile: {
        //     adminUsername: linuxAdminUsername
        //     ssh: {
        //       publicKeys: [
        //         {
        //           keyData: sshRSAPublicKey
        //         }
        //       ]
        //     }
        //   }
        // }
      }
      {
        name: 'apppool'
        count: agentCount
        minCount: 2
        maxCount: 10
        maxPods: 50
        enableAutoScaling: true
        vmSize: agentVMSize
        vnetSubnetID: appPoolSubnet.id
        podSubnetID: podSubnet.id
        osType: 'Linux'
        osSKU: 'CBLMariner'
        mode: 'System'
      //   osProfile: {
      //     linuxProfile: {
      //       adminUsername: linuxAdminUsername
      //       ssh: {
      //         publicKeys: [
      //           {
      //             keyData: sshRSAPublicKey
      //           }
      //         ]
      //       }
      //     }
      //   }
      }
    ]
    aadProfile: {
      managed: true
      enableAzureRBAC: true
      adminGroupObjectIDs: [
        '${paramAKSEIDAdminGroupId}'
      ]
      tenantID: paramTenantId
    }
    networkProfile: {
      outboundType: 'userAssignedNATGateway'
      networkPlugin: 'azure'
      networkPolicy: 'azure'
      podCidr: paramPodCidr
      serviceCidr: paramServiceCidr
      dnsServiceIP: paramDnsServiceIp
    }
    addonProfiles: {
      azureKeyVaultSecretsProvider: {
        enabled: true
      }
      ingressApplicationGateway: {
        config: {
          applicationGatewayId: modAppGW.outputs.outAppGatewayId
        }
        enabled: true
      }
      omsAgent: {
        enabled: true
        config: {
          logAnalyticsWorkspaceResourceID: resLogAnalytics.id
        }
      }
    }
    azureMonitorProfile: {
      metrics: {
        enabled: true
        kubeStateMetrics: {
          metricAnnotationsAllowList: ''
          metricLabelsAllowlist: ''
        }
      }
    }
  }
}

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
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
    idleTimeoutInMinutes: 4
  }
}

resource natgateway 'Microsoft.Network/natGateways@2021-05-01' = {
  name: paramNatGatewayName
  location: paramlocation
  sku: {
    name: 'Standard'
  }
  properties: {
    idleTimeoutInMinutes: 4
    publicIpAddresses: [
      {
        id: natGatewayPublicIp.id
      }
    ]
  }
}

// <-- CORE VIRTUAL NETWORK --> //
resource resVnet 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: 'aks-sp-vnet-${paramlocation}'
  location: paramlocation
  tags: {
    Owner: 'Sandy'
    Dept: 'Infrastructure'
  }
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/8'
      ]
    }
    subnets: [
      {
        name: 'azureBastionSubnet'
        properties: {
          addressPrefix: '10.4.2.0/24'
        }
      }
      {
        name: 'appGWSubnet'
        properties: {
          addressPrefix: '10.4.1.0/24'
      }
      }
      {
        name: 'systemPoolSubnet'
        properties: {
          addressPrefix: '10.1.0.0/16'
          natGateway: {
            id: natgateway.id
          }
      }
      }
      {
        name: 'appPoolSubnet'
        properties: {
          addressPrefix: '10.2.0.0/16'
          natGateway: {
            id: natgateway.id
          }
      }
      }
      {
        name: 'podSubnet'
        properties: {
          addressPrefix: '10.3.0.0/16'
          natGateway: {
            id: natgateway.id
          }
      }
      }
    ]
  }
}

module modBastion 'bastion.bicep' = {
  name: 'Bastion'
  params: {
    paramlocation: paramlocation
    paramBastionSubnet: bastionSubnet.id
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
    clusterName: aks.name
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
    aks
  ]
  params: {
    aksClusterName: clusterName
    applicationGatewayIdentityName: modAppGW.outputs.outAppGatewayManName
    aksIdentityName: aksClusterUserDefinedManagedIdentity.name
  }
}

module modKeyvault 'keyvault.bicep' = {
  name: 'keyVault'
  params: {
    paramlocation: paramlocation
    paramkeyVaultName: 'aksspkeyvault2911'
  }
}

output controlPlaneFQDN string = aks.properties.fqdn
output outBastionSubnetId string = bastionSubnet.id
output outAKSId string = aks.id
output outAKSName string = aks.name
