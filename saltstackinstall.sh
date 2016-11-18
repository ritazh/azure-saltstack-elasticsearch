#!/bin/bash

echo $(date +"%F %T%z") "starting script saltstackinstall.sh"

curl --silent --location https://rpm.nodesource.com/setup_6.x | bash -
yum -y install nodejs

echo $(date +"%F %T%z") "ending script saltstackinstall.sh"
