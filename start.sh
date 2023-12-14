az login

# Parameters
RG="azure-devops-track-aks-exercise-sandy"
LOC=uksouth
ACRNAME="aksacrsandy"
CLUSTER="aks-sp-cluster"
KV="aks-sp-keyvault"
SECRET="testsecret"
VALUE="testsecretvalue"
secretProviderClass="aks-sandy"

# Set the subscription
az account set --subscription e5cfa658-369f-4218-b58e-cece3814d3f1

# Create the resource group
az group create --name $RG --location $LOC

# Create the SSH key needed to log into the Azure Bastion
# ssh-keygen -m PEM -t rsa -b 4096 -f KEYNAME

# This will parse the key to be sent to the Azure Key Vault for storage
readKey=$(< KEYNAME.PUB)
arrayKey=($readKey)
publicKey=${arrayKey[@]:1:1}

# This executes the deployment of the Bicep files
az deployment group create --resource-group $RG --template-file main.bicep --parameters aksClusterSshPublicKey=$publicKey paramCliKeyVaultName=$KV

# This pulls the application from Docker
# docker compose -f azure-voting-app-redis/docker-compose.yaml up -d
# docker images
# docker ps
# docker compose down

# This creates the Azure Container Registry and logs in
az acr create --resource-group $RG --name $ACRNAME --sku Basic
az acr login --name $ACRNAME

# This mounts of the application front and backends into the ACR
# az acr build --resource-group $RG --registry $ACRNAME --image mcr.microsoft.com/azuredocs/azure-vote-front:v1 ./azure-voting-app-redis/azure-vote --no-wait
# az acr build --resource-group $RG --registry $ACRNAME --image mcr.microsoft.com/oss/bitnami/redis:6.0.8 ./azure-voting-app-redis/azure-vote

az acr import --resource-group $RG --name $ACRNAME --image azure-vote-front:v1 --source mcr.microsoft.com/azuredocs/azure-vote-front:v1
az acr import --resource-group $RG --name $ACRNAME --image redis:6.0.8 --source mcr.microsoft.com/oss/bitnami/redis:6.0.8

# Pulls needed information for the deployment of the applications
TENANT_ID=$(az account show --query tenantId -o tsv)
export CLIENT_ID=$(az aks show --resource-group $RG --name $CLUSTER --query addonProfiles.azureKeyvaultSecretsProvider.identity.clientId -o tsv)

# This will pull the credentials for AKS, install the keyvault secrets provider and pass the secret into the Key Vault.
az aks get-credentials --resource-group $RG --name $CLUSTER --overwrite-existing
az acr list --resource-group $RG --query "[].{acrLoginServer:loginServer}" --output table

az keyvault secret set --vault-name $KV --name $SECRET --value $VALUE

export yamlSecretProviderClassName=$secretProviderClass
export yamlKeyVaultName=$KV
export yamlClientId=$CLIENT_ID
export yamlTenantId=$TENANT_ID
export yamlKvSecretName=$SECRET

# This creates a namespace for the nodes and then applies the yaml files
kubectl create namespace production
envsubst < ./yaml/manifest.yaml | kubectl apply -f - --namespace production
kubectl apply -f ./yaml/container-azm-ms-agentconfig.yaml

# This sets the autoscaling for AKS
kubectl autoscale deployment azure-vote-front --namespace production --cpu-percent=50 --min=1 --max=10
kubectl autoscale deployment azure-vote-back --namespace production --cpu-percent=50 --min=1 --max=10

sleep 5
kubectl get pods --namespace production

sleep 5
kubectl describe pods --namespace production