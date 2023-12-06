param paramlocation string
param paramBastionSubnet string
param paramBastionSku string

// Azure Bastion Public IP
resource pipAzureBastion 'Microsoft.Network/publicIPAddresses@2023-05-01' = {
  name: 'bastion-pip-sp-${paramlocation}'
  location: paramlocation
  sku: {name: 'Standard'}
  properties: {publicIPAllocationMethod: 'Static'}
}

// Azure Bastion
resource azureBastion 'Microsoft.Network/bastionHosts@2023-05-01' = {
  name: 'bastion-sp-${paramlocation}-001'
  location: paramlocation
  sku: {name: paramBastionSku}
  properties: {
    ipConfigurations: [
      {
        name: 'hub-subnet'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {id: paramBastionSubnet}
          publicIPAddress: {id: pipAzureBastion.id}
        }
      }
    ]
  }
}
