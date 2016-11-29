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
echo "my-azure-config:
      driver: azure
      subscription_id: $subscriptionId
      username: $adminUsername
      password: $adminPassword" > azure.conf
cd ..
mkdir cloud.profiles.d && cd cloud.profiles.d
echo "azure-eus1:
  provider: azure
  image: OpenLogic|CentOS|7.2n|7.2.20160629
  location: $location
  ssh_username: $adminUsername
  ssh_password: $adminPassword
  storage_account: $storageName
  resource_group: $resourceGroupname
  network_resource_group: $resourceGroupname
  network: $resourceGroupname
  subnet: $resourceGroupname
  public_ip: True
  script: bootstrap-salt.sh
  script_args: -U
  sync_after_install: grains

azure-eus1-ldes:
  extends: azure-eus1
  size: Standard_DS1_v2
  volumes:
    - { size: 50, name: 'datadisk1' }
  minion:
    grains:
      region: $location
      role: elasticsearch" > azure.conf

echo "----------------------------------"
echo "RUNNING SALT-CLOUD"
echo "----------------------------------"

#salt-cloud -p azure-eus1-ldes saltminionelastic



echo $(date +"%F %T%z") "ending script saltstackinstall.sh"
