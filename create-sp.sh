#!/bin/bash

set -ex

SUBSCRIPTION_ID=""
SERVICE_PRINCIPAL_NAME=""
SERVICE_PRINCIPAL_PASSWORD=`date | md5 | head -c10; echo`

az ad sp create-for-rbac --name $SERVICE_PRINCIPAL_NAME --role="Contributor" --scopes="/subscriptions/$SUBSCRIPTION_ID" --password $SERVICE_PRINCIPAL_PASSWORD -o json
