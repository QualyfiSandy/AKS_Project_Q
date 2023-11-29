az login

# Parameters

RG="azure-devops-track-aks-exercise-sandy"
LOC=uksouth
ACRNAME="aksacrsandy"
CLUSTER="aks-sp-cluster"
KV="aks-sp-keyvault291123"
SECRET="testsecret"
VALUE="testsecretvalue"

az group create --name $RG --location $LOC
az keyvault secret set --vault-name $KV --name $SECRET --value $VALUE

TENANT_ID=$(az account show --query tenantId -o tsv)
CLIENT_ID=$(az aks show --resource-group $RG --name $CLUSTER --query addonProfiles.azureKeyvaultSecretsProvider.identity.clientId -o tsv)

# ssh-keygen -m PEM -t rsa -b 4096 -f KEYNAME

readKey=$(< KEYNAME.PUB)
arrayKey=($readKey)
publicKey=${arrayKey[@]:1:1}

# docker compose -f azure-voting-app-redis/docker-compose.yaml up -d
# docker images
# docker ps
# docker compose down

export yamlSecretProviderClassName='sandy'
export yamlKeyVaultName=$KV
export yamlClientId=$CLIENT_ID
export yamlTenantId=$TENANT_ID
export yamlKvSecretName=$SECRET

az acr create --resource-group $RG --name $ACRNAME --sku Basic
az acr build --resource-group $RG --registry $ACRNAME --image mcr.microsoft.com/azuredocs/azure-vote-front:v1 ./azure-voting-app-redis/azure-vote --no-wait
az acr build --registry $ACRNAME --resource-group $RG --image mcr.microsoft.com/oss/bitnami/redis:6.0.8 ./azure-voting-app-redis/azure-vote

az acr login --name $ACRNAME

az deployment group create --resource-group $RG --template-file main.bicep --parameters aksClusterSshPublicKey=$publicKey

az aks get-credentials --resource-group $RG --name $CLUSTER

kubectl create namespace production
kubectl apply -f ./yaml/container-azm-ms-agentconfig.yaml
envsubst < ./yaml/mainfest.yaml | kubectl apply -f ./yaml/manifest.yaml --namespace production

kubectl autoscale deployment azure-vote-front --namespace production --cpu-percent=50 --min=1 --max=10

# kubectl apply -f appgw.yaml --namespace production
# kubectl apply -f azure-voting-app-redis/azure-vote-all-in-one-redis.yaml --namespace production