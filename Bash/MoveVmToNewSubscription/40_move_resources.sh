#!/bin/bash

# ---
subscription_name_src="xxxx"
subscription_id_tgt="xxxx"
rg_src="xxxxx"
rg_tgt="xxxxx"
rg_publicip_tgt="xxxxx"
osdisk="xxxxx_OsDisk_1_0de89caed1384c00a731715c988b2493"
datadisk="xxxxx_DataDisk_0"
publicip="xxxxx-ip"
nsg="xxxxx-nsg"
# ---

az account set \
   --subscription "${subscription_name_src}"

osdisk_id=$(az disk show \
                 --name ${osdisk} \
                 --resource-group ${rg_src} \
                 --query "id" \
                 -o tsv)

datadisk_id=$(az disk show \
                 --name ${datadisk} \
                 --resource-group ${rg_src} \
                 --query "id" \
                 -o tsv)

publicip_id=$(az network public-ip show \
                 --name ${publicip} \
                 --resource-group ${rg_src} \
                 --query "id" \
                 -o tsv)

nsg_id=$(az network nsg show \
                 --name ${nsg} \
                 --resource-group ${rg_src} \
                 --query "id" \
                 -o tsv)

# Move disk and nsg to target subscription

az resource move \
   --destination-subscription-id ${subscription_id_tgt} \
   --destination-group ${rg_tgt} \
   --ids ${osdisk_id} ${datadisk_id} ${nsg_id}

# Move public ip to target subscription

az resource move \
   --destination-subscription-id ${subscription_id_tgt} \
   --destination-group ${rg_publicip_tgt} \
   --ids ${publicip_id}
