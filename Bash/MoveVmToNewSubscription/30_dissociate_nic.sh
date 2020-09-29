#!/bin/bash

# ---
subscription_name_src="XXXXXXXXX"
rg_src="XXXXXXXXX"
nic="XXXXXXXXX"
ipconfig="XXXXXXXXX"
# ---

az account set \
   --subscription "${subscription_name_src}"

# Dissociate public IP and NSG from NIC

az network nic ip-config update \
   --name ${ipconfig} \
   --nic-name ${nic} \
   --resource-group ${rg_src} \
   --public-ip-address ""

az network nic update \
   --resource-group ${rg_src} \
   --name ${nic} \
   --remove networkSecurityGroup
