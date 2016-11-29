#!/bin/bash

resourceGroupName=""
location="westus"

TEMPLURI="https://raw.githubusercontent.com/ritazh/azure-saltstack-elasticsearch/master/azuredeploy.json"

operation=""
adminUid=""
adminPassword=""
NamePrefix=$resourceGroupName
vmSizeMaster="Standard_D1"
subnetName="salt"
storageAccountName=""
virtualNetworkName=""

while test $# -gt 0
do
    case "$1" in
    -o|--op)        shift ; operation=$1
            ;;
    -u|--uid)       shift ; adminUid=$1
            ;;
    -p|--pwd)       shift ; adminPassword=$1
            ;;
    -r|--rg)         shift ; resourceGroupName=$1
            ;;
    -n|--nameprefix) shift ; NamePrefix=$1
            ;;
    -l|--location) shift ; location=$1
            ;;
    esac
    shift
done

if [ -z "$resourceGroupName" ]; then
  resourceGroupName=$NamePrefix"rg1"
fi

if [ -z "$storageAccountName" ]; then
  storageAccountName=$resourceGroupName"stg1"
fi

if [ -z "$virtualNetworkName" ]; then
  virtualNetworkName=$resourceGroupName"vnet1"
fi

function deleteCluster() {
  azure group delete -q -n $resourceGroupName
}

function createCluster() {
  if [ -z "$adminPassword" ]; then
     read -s -p "Password for user $adminUid:" adminPassword
  fi

# create the parameters form the tamplate in JSON format
PARAMS=$(echo "{\
\"adminUsername\":{\"value\":\"$adminUid\"},\
\"adminPassword\":{\"value\":\"$adminPassword\"},\
\"NamePrefix\":{\"value\":\"$NamePrefix\"},\
\"vmSizeMaster\":{\"value\":\"$vmSizeMaster\"},\
\"storageAccountName\":{\"value\":\"$storageAccountName\"},\
\"virtualNetworkName\":{\"value\":\"$virtualNetworkName\"},\
\"subnetName\":{\"value\":\"$subnetName\"}\
}")

#echo $PARAMS

  # create the resource group
  azure group create -n $resourceGroupName -l $location

  # deploy the template
  azure group deployment create $resourceGroupName $NamePrefix -f $TEMPLURI -p "$PARAMS"
}


case "$operation" in
   "delete")    deleteCluster
          ;;
   "create")    createCluster
          ;;
   *)           echo "bad -o switch"
          ;;
esac

