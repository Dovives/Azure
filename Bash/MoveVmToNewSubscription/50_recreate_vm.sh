#!/bin/bash
#

# ---

# vm
subscription_name="xxxx"
rg_tgt="xxxx"
location="westeurope"
vm="xxxxx"
size="Standard_B2ms"
os="windows"

# network
nic_name="xxxxx"
vnet="xxxxx-vnet"
subnet="default"

# disk
osdisk_name="xxxxx_OsDisk_1_0de89caed1384c00a731715c988b2493"
datadisk_name="xxxxx_DataDisk_0"

# tags
tags="Application=License "

# ---

az account set \
   --subscription "${subscription_name}"

echo "----- Create NIC ${nic_name} -----"
az network nic create \
   --resource-group ${rg_tgt} \
   --location ${location} \
   --name ${nic_name} \
   --vnet-name ${vnet} \
   --subnet ${subnet}

echo "----- Create VM ${vm} from disks and nic -----"
az vm create \
   --name ${vm} \
   --resource-group ${rg_tgt} \
   --location ${location} \
   --size ${size} \
   --os-type ${os} \
   --nics ${nic_name} \
   --attach-os-disk ${osdisk_name} \
   --attach-data-disks ${datadisk_name} \
   --tags ${tags} \
   --verbose
