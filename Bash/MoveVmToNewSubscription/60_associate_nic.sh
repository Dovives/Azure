#!/bin/bash

# ---
subscription_name_tgt="xxxxx"
rg_tgt="xxxxx"
nic="xxxxx"
ipconfig="ipconfig1"
nsg="xxxxx-nsg"
publicip_id="/subscriptions/xxxxx/resourceGroups/xxxxx/providers/Microsoft.Network/publicIPAddresses/xxxxx-ip"
# ---

az account set \
   --subscription "${subscription_name_tgt}"

# Associate public IP and NSG from NIC

az network nic ip-config update \
   --name ${ipconfig} \
   --nic-name ${nic} \
   --resource-group ${rg_tgt} \
   --public-ip-address ${publicip_id}

az network nic update \
   --resource-group ${rg_tgt} \
   --name ${nic} \
   --network-security-group ${nsg}
