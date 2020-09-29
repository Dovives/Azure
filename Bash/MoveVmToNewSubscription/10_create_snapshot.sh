#!/bin/bash

# ---
subscription_name_src="xxxx"
rg_src="xxxxx"
location="westeurope"
vm="xxx"
# ---

az account set \
   --subscription "${subscription_name_src}"

osdisk_id=$(az vm show \
   --resource-group ${rg_src} \
   --name ${vm} \
   --query "storageProfile.osDisk.managedDisk.id" \
   -o tsv)

datadisk_id=$(az vm show \
   --resource-group ${rg_src} \
   --name ${vm} \
   --query "storageProfile.dataDisks[0].managedDisk.id" \
   -o tsv)

# Take snapshot

az snapshot create \
    --resource-group ${rg_src} \
    --location ${location} \
    --source "${osdisk_id}" \
    --name "snap_osdisk_${vm}"

az snapshot create \
    --resource-group ${rg_src} \
    --location ${location} \
    --source "${datadisk_id}" \
    --name "snap_datadisk_${vm}"
