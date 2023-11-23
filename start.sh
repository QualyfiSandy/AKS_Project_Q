az login

RG="azure-devops-track-aks-exercise-sandy"
LOC=uksouth
ACRNAME="aksacrsandy"
CLUSTER="aks-sp-cluster"

az group create --name $RG --location $LOC

# #az sshkey create --name "sandySSHKey" --resource-group $RG
# #ssh-keygen -t rsa -b 4096

# # docker compose -f azure-voting-app-redis/docker-compose.yaml up -d
# # docker images
# # docker ps
# # docker compose down

az acr create --resource-group $RG --name $ACRNAME --sku Basic
az acr build --resource-group $RG --registry $ACRNAME --image mcr.microsoft.com/azuredocs/azure-vote-front:v1 ./azure-voting-app-redis/azure-vote
az acr build --registry $ACRNAME --resource-group $RG --image mcr.microsoft.com/oss/bitnami/redis:6.0.8 ./azure-voting-app-redis/azure-vote

az acr login --name $ACRNAME

az deployment group create --resource-group $RG --template-file main.bicep

az aks get-credentials --resource-group $RG --name $CLUSTER

kubectl create namespace production
kubectl apply -f azure-voting-app-redis/azure-vote-all-in-one-redis.yaml --namespace production
kubectl apply -f container-azm-ms-agentconfig.yaml
kubectl apply -f appgw.yaml --namespace production

kubectl autoscale deployment azure-vote-front --namespace production --cpu-percent=50 --min=1 --max=10

#--parameters dnsPrefix=akssandydns linuxAdminUsername=sandyaks sshRSAPublicKey=AAAAB3NzaC1yc2EAAAADAQABAAACAQCiyESiu9BUh0GX0pBXj4sDV9KgRcdqfYs3bGzuJOM13yGqCBTQ4t75lONA69EDDj7kvL8l27GlrOib4nwlc1PsAcMmOJmDT2y+GUhaIFY6r+/JTKCkMFvlVunLF1O/qYd2KPmKrjUrcFYeB0QUd0bb3xyF3xSu/7oxnGzNTV34ZnUg1kJRnUSObK6L3glWY5qAhol5DtDOO039hrLaRsIt9QoG7fLUibw0PzwXu4qAgMeA/PuFjTERn3zCm8fy8MoA1kthcm0eQLpDyFAh9VNdfE3TQEI8qzhk0xoEu8pCALEWTZv3cdbltU4ipo21xi2jOBXUM2A+nq6Dih0BZcAWX6iE98i3riHoB1/D1y/d4EfY8TVE/J2gQU8LOS+FPCfgjjqkirD0gBuI6BEI9kPqpqXxHg3qRS27ofATOhTgXRuem8xmostMTZgUD3EOBKcSBmROBQAFEB7jWBC8uMpQcPV7SUJnvpqTd7ON2kFHf2AkGUDjtjA42/Xav/LuE3n7t0KhtKWMAN2j7u3qMJTYqF6mJuDpFeurDEBk8k1GSc0teloMe/5qz5lBKgT8F3UBl99rqVRZp9PBqhE2PEb49pmEPzJuwG4d4mOKkE9hTiW2fawOPlJq+6nmwrhJ8iV5ScCLTx5e3SrkF5+N3ukdIJsvyfIIA+Qyc7YqkUXsFQ==