#!/bin/bash

# ---
subscription_name_src="xxxx"
rg_src="xxxx"
vm="xxxxx"
# ---

az account set \
   --subscription "${subscription_name_src}"

# Delete VM

az vm delete \
   --name ${vm} \
   --resource-group ${rg_src}
