#!/bin/bash

resourceGroupName=""
location="eastus"

operation=""
adminUid=""
adminPassword=""
vmNamePrefix=""
storageAccountNamePrefix=""
clientid=""
secret=""
tenantid=""
ingestionkey=""

while test $# -gt 0
do
    case "$1" in
    -o|--op)
        shift ; operation=$1
        ;;
    -u|--uid)
        shift ; adminUid=$1
        ;;
    -p|--pwd)
        shift ; adminPassword=$1
        ;;
    -g|--resourcegroup)
        shift ; resourceGroupName=$1
        ;;
    -n|--nameprefix) 
        shift ; vmNamePrefix=$1
        ;;
    -l|--location)
        shift ; location=$1
        ;;
    -c|--clientid)
        shift ; clientid=$1
        ;;
    -s|--secret)
        shift ; secret=$1
        ;;
    -t|--tenantid)
         shift ; tenantid=$1
        ;;
    -k|--ingestionkey)
         shift ; ingestionkey=$1
        ;;
    esac
    shift
done

if [ -z "$resourceGroupName" ]; then
  echo "Error: Missing Resource Group".
  exit 0
fi

function deleteCluster() {
  az group delete -q -n $resourceGroupName
}

function createCluster() {
  if [ -z "$adminPassword" ]; then
     read -s -p "Password for user $adminUid:" adminPassword
  fi

  if [ -z "$NamePrefix" ]; then
    vmNamePrefix=$resourceGroupName
  fi

  if [ -z "$storageAccountNamePrefix" ]; then
    storageAccountNamePrefix="strg"
  fi

# create the parameters form the tamplate in JSON format
PARAMS=$(echo "{\
\"adminUsername\":{\"value\":\"$adminUid\"},\
\"adminPassword\":{\"value\":\"$adminPassword\"},\
\"vmNamePrefix\":{\"value\":\"$vmNamePrefix\"},\
\"storageAccountNamePrefix\":{\"value\":\"$storageAccountNamePrefix\"},\
\"clientid\":{\"value\":\"$clientid\"},\
\"secret\":{\"value\":\"$secret\"},\
\"tenantid\":{\"value\":\"$tenantid\"},\
\"ingestionkey\":{\"value\":\"$ingestionkey\"}\
}")

  echo $PARAMS
  # create the resource group
  az group create -n $resourceGroupName -l $location

  # deploy the template
  az group deployment create -g $resourceGroupName -n $vmNamePrefix --template-file azuredeploy.json --parameters "$PARAMS"
}


case "$operation" in
   "delete")    
        deleteCluster
        ;;
   "create")
       createCluster
       ;;
   *)
       echo "bad -o switch"
       ;;
esac

