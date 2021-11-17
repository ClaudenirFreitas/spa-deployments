#!/bin/bash

#############################################################################
# A script to deploy Token Handler resources for the financial-grade scenario
#############################################################################

RESTCONF_BASE_URL='https://localhost:6749/admin/api/restconf/data'
ADMIN_USER='admin'
ADMIN_PASSWORD='Password1'
IDENTITY_SERVER_TLS_NAME='Identity_Server_TLS'
PRIVATE_KEY_PASSWORD='Password1'

#
# First check prerequisites
#
if [ ! -f './idsvr/license.json' ]; then
  echo "Please provide a license.json file in the financial/idsvr folder in order to deploy the system"
  exit 1
fi

#
# Spin up all containers, using the Docker Compose file, which applies the deployed configuration
#
docker compose --project-name spa up --detach --force-recreate --remove-orphans
if [ $? -ne 0 ]; then
  echo "Problem encountered starting Docker components"
  exit 1
fi

#
# Wait for the admin endpoint to become available
#
echo "Waiting for the Curity Identity Server ..."
while [ "$(curl -k -s -o /dev/null -w ''%{http_code}'' -u "$ADMIN_USER:$ADMIN_PASSWORD" "$RESTCONF_BASE_URL?content=config")" != "200" ]; do
  sleep 2s
done

#
# Add the SSL key and use the private key password to protect it in transit
#
export IDENTITY_SERVER_TLS_DATA=$(openssl base64 -in ./certs/example.com.p12 | tr -d '\n')
echo "Updating SSL certificate ..."
HTTP_STATUS=$(curl -k -s \
-X POST "$RESTCONF_BASE_URL/base:facilities/crypto/add-ssl-server-keystore" \
-u "$ADMIN_USER:$ADMIN_PASSWORD" \
-H 'Content-Type: application/yang-data+json' \
-d "{\"id\":\"$IDENTITY_SERVER_TLS_NAME\",\"password\":\"$PRIVATE_KEY_PASSWORD\",\"keystore\":\"$IDENTITY_SERVER_TLS_DATA\"}" \
-o /dev/null -w '%{http_code}')
if [ "$HTTP_STATUS" != '200' ]; then
  echo "Problem encountered updating the runtime SSL certificate: $HTTP_STATUS"
  exit 1
fi

#
# Set the SSL key as active for the runtime service role
#
HTTP_STATUS=$(curl -k -s \
-X PATCH "$RESTCONF_BASE_URL/base:environments/base:environment/base:services/base:service-role=default" \
-u "$ADMIN_USER:$ADMIN_PASSWORD" \
-H 'Content-Type: application/yang-data+json' \
-d "{\"base:service-role\": [{\"ssl-server-keystore\":\"$IDENTITY_SERVER_TLS_NAME\"}]}" \
-o /dev/null -w '%{http_code}')
if [ "$HTTP_STATUS" != '204' ]; then
  echo "Problem encountered updating the runtime SSL certificate: $HTTP_STATUS"
  exit 1
fi

#
# Provide a user prompt to run the test script
#
echo "System is ready for Mutual TLS connections ..."