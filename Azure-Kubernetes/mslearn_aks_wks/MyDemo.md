MyDemo.md


#Instantiate Variable 

AKS_CLUSTER_NAME=aksworkshop-11360
REGION_NAME=westeurope
RESOURCE_GROUP=aksworkshop
SUBNET_NAME=aks-subnet
VNET_NAME=aks-vnet

#Test Cluster Connectivity 
az aks get-credentials \
    --resource-group $RESOURCE_GROUP \
    --name $AKS_CLUSTER_NAME

kubectl get nodes

##Show namespace inside the Cluster
kubectl get namespace