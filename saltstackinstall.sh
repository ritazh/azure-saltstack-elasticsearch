#!/bin/bash

echo $(date +"%F %T%z") "starting script saltstackinstall.sh"

curl -s -o $HOME/bootstrap_salt.sh -L https://bootstrap.saltstack.com
sh $HOME/bootstrap_salt.sh -M -p python2-boto 2e8e56c
easy_install-2.7 pip==7.1.0
yum install -y gcc gcc-c++ git make libffi-devel openssl-devel python-devel
pip install -y azure

echo $(date +"%F %T%z") "ending script saltstackinstall.sh"
