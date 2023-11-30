az login

# Parameters

RG="azure-devops-track-aks-exercise-sandy"
LOC=uksouth
ACRNAME="aksacrsandy"
CLUSTER="aks-sp-cluster"
KV="aks-sp-keyvault-a3"
SECRET="testsecret"
VALUE="testsecretvalue"

az group create --name $RG --location $LOC

# ssh-keygen -m PEM -t rsa -b 4096 -f KEYNAME

readKey=$(< KEYNAME.PUB)
arrayKey=($readKey)
publicKey=${arrayKey[@]:1:1}

az deployment group create --resource-group $RG --template-file main.bicep --parameters aksClusterSshPublicKey=$publicKey paramCliKeyVaultName=$KV

az acr create --resource-group $RG --name $ACRNAME --sku Basic
az acr login --name $ACRNAME

az aks get-credentials --resource-group $RG --name $CLUSTER
az aks enable-addons --addons azure-keyvault-secrets-provider --name $CLUSTER --resource-group $RG
az keyvault secret set --vault-name $KV --name $SECRET --value $VALUE

TENANT_ID=$(az account show --query tenantId -o tsv)
export CLIENT_ID=$(az aks show --resource-group $RG --name $CLUSTER --query addonProfiles.azureKeyvaultSecretsProvider.identity.clientId -o tsv)
export keyVaultId="$(az keyvault show --name $KV --resource-group $RG --query id -o tsv)"
 
az role assignment create --role "Key Vault Administrator" --assignee $CLIENT_ID --scope "/$keyVaultId"
az role assignment create --role "Key Vault Secrets User" --assignee $CLIENT_ID --scope "/$keyVaultId"

az acr build --resource-group $RG --registry $ACRNAME --image mcr.microsoft.com/azuredocs/azure-vote-front:v1 ./azure-voting-app-redis/azure-vote --no-wait
az acr build --registry $ACRNAME --resource-group $RG --image mcr.microsoft.com/oss/bitnami/redis:6.0.8 ./azure-voting-app-redis/azure-vote

# docker compose -f azure-voting-app-redis/docker-compose.yaml up -d
# docker images
# docker ps
# docker compose down

export yamlSecretProviderClassName="sandyaks"
export yamlKeyVaultName=$KV
export yamlClientId=$CLIENT_ID
export yamlTenantId=$TENANT_ID
export yamlKvSecretName=$SECRET

kubectl create namespace production
kubectl apply -f ./yaml/container-azm-ms-agentconfig.yaml
envsubst < ./yaml/manifest.yaml | kubectl apply -f - --namespace production

kubectl autoscale deployment azure-vote-front --namespace production --cpu-percent=50 --min=1 --max=10
kubectl autoscale deployment azure-vote-back --namespace production --cpu-percent=50 --min=1 --max=10

# kubectl apply -f appgw.yaml --namespace production
# kubectl apply -f azure-voting-app-redis/azure-vote-all-in-one-redis.yaml --namespace production