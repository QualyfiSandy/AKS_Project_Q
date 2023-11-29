param paramlocation string
param paramBastionSubnet string

resource pipAzureBastion 'Microsoft.Network/publicIPAddresses@2022-01-01' = {
  name: 'bastion-sp-${paramlocation}'
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

resource azureBastion 'Microsoft.Network/bastionHosts@2022-01-01' = {
  name: 'aks-sp-${paramlocation}-001'
  tags: {
    Owner: 'Sandy'
    Dept: 'Hub'
  }
  location: paramlocation
  sku: {
    name: 'Standard'
  }
  properties: {
    ipConfigurations: [
      {
        name: 'hub-subnet'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: paramBastionSubnet
          }
          publicIPAddress: {
            id: pipAzureBastion.id
          }
        }
      }
    ]
  }
}
