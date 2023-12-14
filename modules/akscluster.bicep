param clusterName string
param paramlocation string
param paramK8sVersion string
param dnsPrefix string
param agentCount int
param agentVMSize string
param paramAKSEIDAdminGroupId string
param paramTenantId string
param paramPodCidr string
param paramServiceCidr string
param paramDnsServiceIp string
param paramAppGwId string
param paramLogAnalyticsId string
param linuxAdminUsername string
param sshRSAPublicKey string
param paramSystemPoolSubnetId string
param paramPodSubnetId string
param paramAppPoolSubnetId string

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
    userAssignedIdentities: {'${aksClusterUserDefinedManagedIdentity.id}':{}}
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
        minCount: 1
        maxCount: 1
        maxPods: 50
        enableAutoScaling: true
        vmSize: agentVMSize
        vnetSubnetID: paramSystemPoolSubnetId
        podSubnetID: paramPodSubnetId
        osType: 'Linux'
        osSKU: 'CBLMariner'
        mode: 'System'
      }
      {
        name: 'apppool'
        count: agentCount
        minCount: 1
        maxCount: 1
        maxPods: 50
        enableAutoScaling: true
        vmSize: agentVMSize
        vnetSubnetID: paramAppPoolSubnetId
        podSubnetID: paramPodSubnetId
        osType: 'Linux'
        osSKU: 'CBLMariner'
        mode: 'System'
      }
    ]
    linuxProfile: {
      adminUsername: linuxAdminUsername
      ssh: {
        publicKeys: [
          {keyData: 'ssh-rsa ${sshRSAPublicKey}\n'}
        ]
      }
    }
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
      ingressApplicationGateway: {
        config: {applicationGatewayId: paramAppGwId}
        enabled: true
      }
      omsAgent: {
        enabled: true
        config: {logAnalyticsWorkspaceResourceID: paramLogAnalyticsId}
      }
      azureKeyvaultSecretsProvider: {
        enabled: true
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

output outClusterId string = aks.id
output outClusterName string = aks.name
output outClusterManIdentityName string = aksClusterUserDefinedManagedIdentity.name
