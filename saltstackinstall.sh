#!/bin/bash

echo $(date +"%F %T%z") "starting script saltstackinstall.sh"

# arguments
adminUsername=$1
adminPassword=$2
subscriptionId=$3
storageName=$4
vnetName=$5
location=$6
resourceGroupname=$7
subnetName=$8
clientid=$9
secret=${10}
tenantid=${11}
publicip=${12}

echo "----------------------------------"
echo "INSTALLING SALT"
echo "----------------------------------"

curl -s -o $HOME/bootstrap_salt.sh -L https://bootstrap.saltstack.com
sh $HOME/bootstrap_salt.sh -M -p python2-boto git 5b1af94

# latest commit from develop branch
sh $HOME/bootstrap_salt.sh -M -p python2-boto git eb7b1e8
easy_install-2.7 pip==7.1.0
yum install -y gcc gcc-c++ git make libffi-devel openssl-devel python-devel
pip install azure
pip install -U azure-mgmt-compute azure-mgmt-network azure-mgmt-resource azure-mgmt-storage azure-mgmt-web

cd /etc/salt
myip=$(hostname --ip-address)
echo "interface: $myip" >> master
echo "hash_type: sha256" >> master

systemctl start salt-master.service
systemctl enable salt-master.service
salt-cloud -u

echo "----------------------------------"
echo "CONFIGURING SALT-CLOUD"
echo "----------------------------------"

mkdir cloud.providers.d && cd cloud.providers.d
echo "azure:
  driver: azurearm
  subscription_id: $subscriptionId
  client_id: $clientid
  secret: $secret
  tenant: $tenantid
  minion:
    master: $publicip
  grains:
    home: /home/$adminUsername
    provider: azure
    user: $adminUsername" > azure.conf
cd ..
mkdir cloud.profiles.d && cd cloud.profiles.d

echo "azure-wus1:
  provider: azure
  image: OpenLogic|CentOS|7.2n|7.2.20160629
  size: Standard_DS2_v2
  location: $location
  ssh_username: $adminUsername
  ssh_password: $adminPassword
  storage_account: $storageName
  resource_group: $resourceGroupname
  network_resource_group: $resourceGroupname
  network: $vnetName
  subnet: $subnetName
  public_ip: True
  script: bootstrap-salt.sh
  script_args: -U
  sync_after_install: grains

azure-wus1-es:
  extends: azure-wus1
  size: Standard_DS2_v2
  volumes:
    - {name: 'datadisk1' }
  minion:
    grains:
      region: $location
      role: elasticsearch" > azure.conf

echo "----------------------------------"
echo "RUNNING SALT-CLOUD"
echo "----------------------------------"

salt-cloud -p azure-wus1-es "${resourceGroupname}minion"



echo $(date +"%F %T%z") "ending script saltstackinstall.sh"
