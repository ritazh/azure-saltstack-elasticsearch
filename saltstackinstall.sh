#!/bin/bash

echo $(date +"%F %T%z") "starting script saltstackinstall.sh"

# arguments
adminUsername=${1}
adminPassword=${2}
subscriptionId=${3}
storageName=${4}
vnetName=${5}
subnetName=${6}
clientid=${7}
secret=${8}
tenantid=${9}
nsgname=${10}

echo "----------------------------------"
echo "INSTALLING SALT"
echo "----------------------------------"

curl -s -o $HOME/bootstrap_salt.sh -L https://bootstrap.saltstack.com
sh $HOME/bootstrap_salt.sh -M -p python-pip git 2017.7

easy_install-2.7 pip==9.0.1
yum install -y gcc gcc-c++ git make libffi-devel openssl-devel python-devel
curl -s -o $HOME/requirements.txt -L https://raw.githubusercontent.com/jpoon/azure-saltstack-elasticsearch/master/requirements.txt
pip install -r $HOME/requirements.txt

vmPrivateIpAddress=$(curl -H Metadata:true "http://169.254.169.254/metadata/instance/network/interface/0/ipv4/ipAddress/0/privateIpAddress?api-version=2017-04-02&format=text")
vmPublicIpAddress=$(curl -H Metadata:true "http://169.254.169.254/metadata/instance/network/interface/0/ipv4/ipAddress/0/publicIpAddress?api-version=2017-04-02&format=text")
vmLocation=$(curl -H Metadata:true "http://169.254.169.254/metadata/instance/compute/location?api-version=2017-08-01&format=text")
resourceGroupName=$(curl -H Metadata:true "http://169.254.169.254/metadata/instance/compute/resourceGroupName?api-version=2017-08-01&format=text")

echo "----------------------------------"
echo "CONFIGURING SALT-MASTER"
echo "----------------------------------"

echo "
interface: ${vmPrivateIpAddress}
file_roots:
  base:
    - /srv/salt
    - /srv/salt/elasticsearch
    - /srv/salt/elasticsearchmaster
" | tee --append /etc/salt/master

systemctl start salt-master.service
systemctl enable salt-master.service
salt-cloud -u

echo "----------------------------------"
echo "CONFIGURING SALT-CLOUD"
echo "----------------------------------"

# cloud providers
mkdir -p /etc/salt/cloud.providers.d
echo "
azurearm-conf:
  driver: azurearm
  subscription_id: $subscriptionId
  client_id: $clientid
  secret: $secret
  tenant: $tenantid
  minion:
    master: ${vmPublicIpAddress}
  grains:
    home: /home/$adminUsername
    provider: azure
    user: $adminUsername
" | tee /etc/salt/cloud.providers.d/azure.conf

# cloud profiles
mkdir -p /etc/salt/cloud.profiles.d 
echo "
azure-vm:
  provider: azurearm-conf
  image: OpenLogic|CentOS|7.2n|7.2.20160629
  size: Standard_DS2_v2
  location: ${vmLocation}
  ssh_username: $adminUsername
  ssh_password: $adminPassword
  storage_account: $storageName
  resource_group: ${resourceGroupName}
  security_group: $nsgname
  network_resource_group: ${resourceGroupName}
  network: $vnetName
  subnet: $subnetName
  public_ip: True

azure-vm-esnode:
  extends: azure-vm
  size: Standard_DS2_v2
  volumes:
    - {disk_size_gb: 50, name: 'datadisk1' }
  minion:
    grains:
      region: $vmLocation
      roles: elasticsearch
      elasticsearch:
        cluster: es-cluster-local-01

azure-vm-esmaster:
  extends: azure-vm
  size: Standard_DS2_v2
  volumes:
    - {disk_size_gb: 50, name: 'datadisk1' }
  minion:
    grains:
      region: $vmLocation
      roles: elasticsearchmaster
      elasticsearchmaster:
        cluster: es-cluster-local-01
" | tee /etc/salt/cloud.profiles.d/azure.conf

echo "----------------------------------"
echo "RUNNING SALT-CLOUD"
echo "----------------------------------"

salt-cloud -p azure-vm-esmaster "${resourceGroupName}-esmaster"
salt-cloud -p azure-vm-esnode "${resourceGroupName}-esnode"

echo "----------------------------------"
echo "CONFIGURING ELASTICSEARCH"
echo "----------------------------------"

mkdir -p /srv/salt
echo "
base:
  '*':
    - common_packages
  'roles:elasticsearch':
    - match: grain
    - elasticsearch
  'roles:elasticsearchmaster':
    - match: grain
    - elasticsearchmaster
" | tee /srv/salt/top.sls

echo "
common_packages:
    pkg.installed:
        - names:
            - git
            - tmux
            - tree
" | tee /srv/salt/common_packages.sls

mkdir -p /srv/salt/elasticsearchmaster 
cd /srv/salt/elasticsearchmaster
wget http://packages.elasticsearch.org/GPG-KEY-elasticsearch -O GPG-KEY-elasticsearch

echo "
# Elasticsearch configuration for {{ grains['fqdn'] }}
# Cluster: {{ grains[grains['roles']]['cluster'] }}

cluster.name: {{ grains[grains['roles']]['cluster'] }}
node.name: '{{ grains['fqdn'] }}'
node.master: true
node.data: false
discovery.zen.ping.multicast.enabled: false
discovery.zen.ping.unicast.hosts: ['{{ grains['fqdn'] }}']
" | tee /srv/salt/elasticsearchmaster/elasticsearch.yml

cookie="'Cookie: oraclelicense=accept-securebackup-cookie'"

echo "
Download Oracle JDK:
    cmd.run:
        - name: \"wget --no-check-certificate --no-cookies --header $cookie http://download.oracle.com/otn-pub/java/jdk/8u101-b13/jdk-8u101-linux-x64.rpm\"
        - cwd: /home/$adminUsername/
        - runas: root
        - onlyif: if [ -f /home/$adminUsername/jdk-8u101-linux-x64.rpm ]; then exit 1; else exit 0; fi;

Install Oracle JDK:
    cmd.run:
        - name: yum install -y /home/$adminUsername/jdk-8u101-linux-x64.rpm
        - onlyif: if yum list installed jdk-8u101 >/dev/null 2>&1; then exit 1; else exit 0; fi;

elasticsearch_repo:
    pkgrepo.managed:
        - humanname: Elasticsearch Official Centos Repository
        - name: elasticsearch
        - baseurl: https://packages.elastic.co/elasticsearch/1.7/centos
        - gpgkey: https://packages.elastic.co/GPG-KEY-elasticsearch
        - gpgcheck: 1

elasticsearch:
    pkg:
        - installed
        - require:
            - pkgrepo: elasticsearch_repo

    service:
        - running
        - enable: True
        - require:
            - pkg: elasticsearch
            - file: /etc/elasticsearch/elasticsearch.yml

/etc/elasticsearch/elasticsearch.yml:
  file:
    - managed
    - user: root
    - group: root
    - mode: 644
    - template: jinja
    - source: salt://elasticsearchmaster/elasticsearch.yml
" | tee /srv/salt/elasticsearchmaster/init.sls

mkdir -p /srv/salt/elasticsearch
cd /srv/salt/elasticsearch
wget http://packages.elasticsearch.org/GPG-KEY-elasticsearch -O GPG-KEY-elasticsearch

echo "
# Elasticsearch configuration for {{ grains['fqdn'] }}
# Cluster: {{ grains[grains['roles']]['cluster'] }}

cluster.name: {{ grains[grains['roles']]['cluster'] }}
node.name: '{{ grains['fqdn'] }}'
node.master: false
node.data: true
discovery.zen.ping.multicast.enabled: false
discovery.zen.ping.unicast.hosts: ['${resourceGroupName}minionesmaster']
" | tee /srv/salt/elasticsearch/elasticsearch.yml

echo "
Download Oracle JDK:
    cmd.run:
        - name: \"wget --no-check-certificate --no-cookies --header $cookie http://download.oracle.com/otn-pub/java/jdk/8u101-b13/jdk-8u101-linux-x64.rpm\"
        - cwd: /home/$adminUsername/
        - runas: root
        - onlyif: if [ -f /home/$adminUsername/jdk-8u101-linux-x64.rpm ]; then exit 1; else exit 0; fi;

Install Oracle JDK:
    cmd.run:
        - name: yum install -y /home/$adminUsername/jdk-8u101-linux-x64.rpm
        - onlyif: if yum list installed jdk-8u101 >/dev/null 2>&1; then exit 1; else exit 0; fi;

elasticsearch_repo:
    pkgrepo.managed:
        - humanname: Elasticsearch Official Centos Repository
        - name: elasticsearch
        - baseurl: https://packages.elastic.co/elasticsearch/1.7/centos
        - gpgkey: https://packages.elastic.co/GPG-KEY-elasticsearch
        - gpgcheck: 1

elasticsearch:
    pkg:
        - installed
        - require:
            - pkgrepo: elasticsearch_repo

    service:
        - running
        - enable: True
        - require:
            - pkg: elasticsearch
            - file: /etc/elasticsearch/elasticsearch.yml

/etc/elasticsearch/elasticsearch.yml:
  file:
    - managed
    - user: root
    - group: root
    - mode: 644
    - template: jinja
    - source: salt://elasticsearch/elasticsearch.yml
" | sudo tee /srv/salt/elasticsearch/init.sls

echo "----------------------------------"
echo "INSTALLING ELASTICSEARCH"
echo "----------------------------------"

cd /srv/salt
salt -G 'roles:elasticsearchmaster' state.highstate
salt -G 'roles:elasticsearch' state.highstate

echo $(date +"%F %T%z") "ending script saltstackinstall.sh"
