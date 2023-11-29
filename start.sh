az login

RG="azure-devops-track-aks-exercise-sandy"
LOC=uksouth
ACRNAME="aksacrsandy"
CLUSTER="aks-sp-cluster"

az group create --name $RG --location $LOC

KV="aks-sp-keyvault291123"
SECRET="testsecret"
VALUE="testsecretvalue"

az keyvault create --name $KV --resource-group $RG --location $LOC --enable-rbac-authorization true

SUBSCRIPTION_ID=$(az account show --query id -o tsv)
USER_OBJECT_ID=$(az ad signed-in-user show --query objectId -o tsv)
az role assignment create --assignee-object-id $USER_OBJECT_ID --role "Key Vault Administrator" --scope /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG/providers/Microsoft.KeyVault/vaults/$KV
az keyvault secret set --vault-name $KV --name $SECRET --value $VALUE

IDENTITY_ID=$(az identity show -g MC\_$RG\_$CLUSTER\_westeurope --name azurekeyvaultsecretsprovider-$CLUSTER --query principalId -o tsv)
az role assignment create --assignee-object-id $IDENTITY_ID --role "Key Vault Administrator" --scope /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG/providers/Microsoft.KeyVault/vaults/$KV

# ssh-keygen -m PEM -t rsa -b 4096 -f KEYNAME

readKey=$(< KEYNAME.PUB)
arrayKey=($readKey)
publicKey=${arrayKey[@]:1:1}

# docker compose -f azure-voting-app-redis/docker-compose.yaml up -d
# docker images
# docker ps
# docker compose down

az acr create --resource-group $RG --name $ACRNAME --sku Basic
az acr build --resource-group $RG --registry $ACRNAME --image mcr.microsoft.com/azuredocs/azure-vote-front:v1 ./azure-voting-app-redis/azure-vote --no-wait
az acr build --registry $ACRNAME --resource-group $RG --image mcr.microsoft.com/oss/bitnami/redis:6.0.8 ./azure-voting-app-redis/azure-vote

az acr login --name $ACRNAME

az deployment group create --resource-group $RG --template-file main.bicep --parameters aksClusterSshPublicKey=$publicKey

az aks get-credentials --resource-group $RG --name $CLUSTER

kubectl create namespace production
kubectl apply -f azure-voting-app-redis/azure-vote-all-in-one-redis.yaml --namespace production
kubectl apply -f container-azm-ms-agentconfig.yaml
# kubectl apply -f manifest.yaml --namespace production
kubectl apply -f appgw.yaml --namespace production

kubectl autoscale deployment azure-vote-front --namespace production --cpu-percent=50 --min=1 --max=10