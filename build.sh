#!/bin/bash

###########################################
# A script to build Token Handler resources
###########################################

#
# Ensure that we are in the folder containing this script
#
cd "$(dirname "${BASH_SOURCE[0]}")"
cp ./hooks/pre-commit ./.git/hooks

#
# Get the OAuth agent and default to Node.js
#
OAUTH_AGENT="$1"
if [ "$OAUTH_AGENT" == '' ]; then
  OAUTH_AGENT="NODE"
fi
if [ "$OAUTH_AGENT" != 'NODE' ] && [ "$OAUTH_AGENT" != 'NET' ] && [ "$OAUTH_AGENT" != 'KOTLIN' ] && [ "$OAUTH_AGENT" != 'FINANCIAL' ]; then
  echo 'An invalid value was supplied for the OAUTH_AGENT parameter'
  exit 1
fi

#
# Get the API gateway and OAuth proxy plugin to use, and default to Kong
#
OAUTH_PROXY="$2"
if [ "$OAUTH_PROXY" == '' ]; then
  OAUTH_PROXY="KONG"
fi
if [ "$OAUTH_PROXY" != 'KONG' ] && [ "$OAUTH_PROXY" != 'NGINX' ] && [ "$OAUTH_PROXY" != 'OPENRESTY' ]; then
  echo 'An invalid value was supplied for the OAUTH_PROXY parameter'
  exit 1
fi
echo "Building resources for the $OAUTH_AGENT OAuth agent and $OAUTH_PROXY API gateway and plugin ..."

#
# Build the API gateway's custom dockerfile, which includes the OAuth proxy plugin
#
cd components/api-gateway
if [ "$OAUTH_PROXY" == 'NGINX' ]; then

  docker build --no-cache -f nginx/Dockerfile -t custom_nginx:1.21.6-alpine .
  if [ $? -ne 0 ]; then
    echo "Problem encountered building the NGINX docker image"
    exit 1
  fi
  
elif [ "$OAUTH_PROXY" == 'OPENRESTY' ]; then

  docker build --no-cache -f openresty/Dockerfile -t custom_openresty/openresty:1.21.4.1-bionic .
  if [ $? -ne 0 ]; then
    echo "Problem encountered building the OpenResty docker image"
    exit 1
  fi

elif [ "$OAUTH_AGENT" == 'KONG' ]; then
  
  docker build --no-cache -f kong/Dockerfile -t custom_kong:3.0.0 .
  if [ $? -ne 0 ]; then
    echo "Problem encountered building the Kong docker image"
    exit 1
  fi
fi
cd ..

#
# Get and build the OAuth Agent
#
rm -rf oauth-agent 2>/dev/null
if [ "$OAUTH_AGENT" == 'NODE' ]; then

  git clone https://github.com/curityio/oauth-agent-node-express oauth-agent
  if [ $? -ne 0 ]; then
    echo "Problem encountered downloading the OAuth Agent"
    exit 1
  fi
  cd oauth-agent

  npm install
  if [ $? -ne 0 ]; then
    echo "Problem encountered installing the OAuth Agent dependencies"
    exit 1
  fi

  npm run build
  if [ $? -ne 0 ]; then
    echo "Problem encountered building the OAuth Agent code"
    exit 1
  fi

elif [ "$OAUTH_AGENT" == 'NET' ]; then

  git clone https://github.com/curityio/oauth-agent-dotnet oauth-agent
  if [ $? -ne 0 ]; then
    echo "Problem encountered downloading the OAuth Agent"
    exit 1
  fi
  cd oauth-agent

  dotnet publish oauth-agent.csproj -c Release -r linux-x64 --no-self-contained
  if [ $? -ne 0 ]; then
    echo "Problem encountered building the OAuth Agent's Java code"
    exit 1
  fi

elif [ "$OAUTH_AGENT" == 'KOTLIN' ]; then

  git clone https://github.com/curityio/oauth-agent-kotlin-spring oauth-agent
  if [ $? -ne 0 ]; then
    echo "Problem encountered downloading the OAuth Agent"
    exit 1
  fi
  cd oauth-agent

  ./gradlew bootJar
  if [ $? -ne 0 ]; then
    echo "Problem encountered building the OAuth Agent's Kotlin code"
    exit 1
  fi

elif [ "$OAUTH_AGENT" == 'FINANCIAL' ]; then
  
  git clone https://github.com/curityio/oauth-agent-kotlin-spring-fapi oauth-agent
  if [ $? -ne 0 ]; then
    echo "Problem encountered downloading the OAuth Agent"
    exit 1
  fi
  cd oauth-agent

  ./gradlew bootJar
  if [ $? -ne 0 ]; then
    echo "Problem encountered building the OAuth Agent's Kotlin code"
    exit 1
  fi
fi
docker build -t oauthagent:1.0.0 .
if [ $? -ne 0 ]; then
  echo "Problem encountered building the OAuth Agent docker image"
  exit 1
fi