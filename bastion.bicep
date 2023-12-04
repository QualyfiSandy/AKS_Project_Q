param paramlocation string
// param paramBastionSubnet string
param paramBastionSku string

resource resVnet 'Microsoft.Network/virtualNetworks@2023-05-01' existing = {name: 'aks-sp-vnet-${paramlocation}'}

resource pipAzureBastion 'Microsoft.Network/publicIPAddresses@2023-05-01' = {
  name: 'bastion-pip-sp-${paramlocation}'
  location: paramlocation
  sku: {name: 'Standard'}
  properties: {publicIPAllocationMethod: 'Static'}
}

resource azureBastion 'Microsoft.Network/bastionHosts@2023-05-01' = {
  name: 'bastion-sp-${paramlocation}-001'
  location: paramlocation
  sku: {name: paramBastionSku}
  properties: {
    virtualNetwork: {
      id: resVnet.id
    }
    ipConfigurations: [
      // {
      //   name: 'hub-subnet'
      //   properties: {
      //     privateIPAllocationMethod: 'Dynamic'
      //     subnet: {id: paramBastionSubnet}
      //     publicIPAddress: {id: pipAzureBastion.id}
      //   }
      // }
    ]
  }
}
