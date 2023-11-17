@description('The name of the Managed Cluster resource.')
param clusterName string = 'aks101cluster'

param paramlocation string = resourceGroup().location

@description('Optional DNS prefix to use with hosted Kubernetes API server FQDN.')
param dnsPrefix string = 'akssandy'

@description('Disk size (in GB) to provision for each of the agent pool nodes. This value ranges from 0 to 1023. Specifying 0 will apply the default disk size for that agentVMSize.')
@minValue(0)
@maxValue(1023)
param osDiskSizeGB int = 0

@description('The number of nodes for the cluster.')
@minValue(1)
@maxValue(50)
param agentCount int = 3

@description('The size of the Virtual Machine.')
param agentVMSize string = 'standard_d2s_v3'

@description('User name for the Linux Virtual Machines.')
param linuxAdminUsername string = 'akssandy'

@description('Configure all linux machines with the SSH RSA public key string. Your key should include three parts, for example \'ssh-rsa AAAAB...snip...UcyupgH azureuser@linuxvm\'')
param sshRSAPublicKey string = 'ssh'

param paramAcrName string = 'aksacrsandy'
param paramNatGatewayName string = 'NatGateway-sandy'
param paramNatGatewayPip string = 'NatGateway-pip-sandy'

resource aks 'Microsoft.ContainerService/managedClusters@2023-09-01' = {
  name: clusterName
  location: paramlocation
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    dnsPrefix: dnsPrefix
    agentPoolProfiles: [
      {
        name: 'agentpool'
        osDiskSizeGB: osDiskSizeGB
        count: agentCount
        vmSize: agentVMSize
        osType: 'MarinerOS'
        mode: 'System'
        osProfile: {
          linuxProfile: {
            adminUsername: linuxAdminUsername
            ssh: {
              publicKeys: [
                {
                  keyData: sshRSAPublicKey
                }
              ]
            }
          }
        }
      }
    ]
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

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2021-06-01-preview' = {
  name: paramAcrName
  location: paramlocation
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: true
  }
}

// <-- CORE VIRTUAL NETWORK --> //
resource resVnet 'Microsoft.Network/virtualNetworks@2018-10-01' = {
  name: 'vnet-${paramlocation}-001'
  location: paramlocation
  tags: {
    Owner: 'Sandy'
    Dept: 'Infrastructure'
  }
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.20.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'azureBastionSubnet'
        properties: {
          addressPrefix: '10.20.1.0/24'
        }
      }
      {
        name: 'appGWSubnet'
        properties: {
          addressPrefix: '10.20.2.0/24'
      }
      }
      {
        name: 'KVSubnet'
        properties: {
          addressPrefix: '10.20.3.0/24'
      }
      }
    ]
  }
}

resource bastionSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-05-01' existing = {
  name: 'azureBastionSubnet'
  parent: resVnet
}

module modBastion 'bastion.bicep' = {
  name: 'Bastion'
  params: {
    paramlocation: paramlocation
    paramBastionSubnet: bastionSubnet.id
  }
}

resource appGWSubnet 'Microsoft.Network/virtualNetworks/subnets@2023-05-01' existing = {
  name: 'appGWSubnet'
  parent: resVnet
}

module appGW 'appgw.bicep' = {
  name: 'AppGateway'
  params: {
    paramAgwSubnetId: appGWSubnet.id
    paramAppGatewayName: 'appGW'
    paramlocation: paramlocation
    paramProdFqdn: aks.properties.fqdn
  }
}

output controlPlaneFQDN string = aks.properties.fqdn
output outBastionSubnetId string = bastionSubnet.id

// comment
