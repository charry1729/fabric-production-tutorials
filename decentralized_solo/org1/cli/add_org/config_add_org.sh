#!/bin/bash
#
# Copyright IBM Corp All Rights Reserved
#
# SPDX-License-Identifier: Apache-2.0
#

#######################################################################
################################ org2 CA ##############################
echo "************************ START org2 CA **************************"
# Setup the org2 CA and register the CA ADMIN
docker-compose -f org2/ca/docker-compose.yaml up -d


#######################################################################
################################ org2 CLI #############################
docker-compose -f org2/cli/docker-compose.yaml up -d

# Enroll the CA ADMIN
# Register the ORG ADMIN, USER & PEER
# Get CA CERT and complete MSP tree
# Enroll the ORG ADMIN & complete ADMIN MSP tree
# Generate the PEER ANCHOR TX (ACTUALLY NO, THE UPDATE ENVELOPE DOES THIS)

docker exec -it org2-cli bash

# The org2 CLI startup script should have created the needed artifacts (MSP tree)

# Ensure the ORG ADMIN is enrolled and env vars are set
source /etc/hyperledger/fabric/setup/switchToAdmin.sh

# Move to the directory with the configtx.yaml file
cd /etc/hyperledger/fabric/setup
export FABRIC_CFG_PATH=$PWD #DIR FOR configtx.yaml WITH org2
configtxgen -channelID mychannel -printOrg org2 > org2.json

# pass org2.json to common folder for use by authorizing org(s)
cp org2.json /data/org2.json

# MANUALLY TRANSFER JSON TO org1 directory with "add org" scripts


#######################################################################
################################ org1 CLI #############################
docker exec -it org1-cli bash

# Ensure the ORG ADMIN is enrolled and env vars are set
source /etc/hyperledger/fabric/setup/switchToAdmin.sh

#setOrdererGlobals
source /etc/hyperledger/fabric/setup/.env

echo "*************** createConfigTx & UPDATE CHANNEL *****************"
cd /etc/hyperledger/fabric/setup/add_org
./config_add_org_cli.sh

echo "*********************** CURRENT ADMINS SIGN *********************"
# HAVE OTHER EXISTING ORG ADMINS SIGN IF NEEDED, THEN FINAL EXISTING ORG ADMIN:
peer channel update -f update_in_envelope.pb -c mychannel $ORDERER_CONN_ARGS


######## MIGHT BE WRONG-
# MANUALLY TRANSFER GENESIS BLOCK TO org2 common dir


#######################################################################
############################### org2 PEER #############################
echo "*********************** START org2 PEER **********************"
# Might be able to wait until after block fetch for org2 CLI?  Seems to work fine starting before though.
docker-compose -f org2/peer0/docker-compose.yaml up -d


#######################################################################
################################ org2 CLI #############################
docker exec -it org2-cli bash

echo "************************ CHECK CRYPTO ***************************"
# Copy over the ORDERER CA CERT (or TLSCACERT, either one - should be the same)

echo "============= Getting org2 onto the network =============="
# Move to the directory mapped to the local dir with the files needed
cd /etc/hyperledger/fabric/setup

# Ensure the ORG ADMIN is enrolled and env vars are set
source /etc/hyperledger/fabric/setup/switchToAdmin.sh

#setOrdererGlobals
source /etc/hyperledger/fabric/setup/.env

# # Get the genesis block into org2 dir
# echo "Fetching channel config block from orderer..."
peer channel fetch 0 mychannel.block -c mychannel $ORDERER_CONN_ARGS

## Sometimes Join takes time hence RETRY at least 5 times
peer channel join -b mychannel.block
echo "============ org2 peer joined channel 'mychannel' ============"

peer chaincode install -n mycc -v 2.0 -l golang -p github.com/hyperledger/fabric-samples/chaincode/abac/go
echo "========= org2 peer chaincode installed ========="


#######################################################################
################################ org1 CLI #############################
docker exec -it org1-cli bash

# Ensure the ORG ADMIN is enrolled and env vars are set
source /etc/hyperledger/fabric/setup/switchToAdmin.sh

#setOrdererGlobals
source /etc/hyperledger/fabric/setup/.env

peer chaincode install -n mycc -v 2.0 -l golang -p github.com/hyperledger/fabric-samples/chaincode/abac/go
echo "========= org1 peer chaincode installed ========= "

# USE ".member" NOT ".peer" - need to figure out NodeOUs to use ".peer", ".client", etc
peer chaincode upgrade -C mychannel -n mycc -v 2.0 -c '{"Args":["init","a","1000","b","2000"]}' -P "OR('org1MSP.member','org2MSP.member')" $ORDERER_CONN_ARGS #"AND ('org1MSP.peer','org2MSP.peer')" $ORDERER_CONN_ARGS

# peer chaincode instantiate -C mychannel -n mycc -v 2.0 -c '{"Args":["init","a","100","b","200"]}' -P "OR('org1MSP.member')" $ORDERER_CONN_ARGS
echo "========= org1 peer chaincode updated ========= "





#######################################################################
#######################################################################
################################# TEST ################################
#######################################################################
#######################################################################

#######################################################################
################################ org2 CLI #############################
docker exec -it org2-cli bash

# Ensure the ORG ADMIN is enrolled and env vars are set
source /etc/hyperledger/fabric/setup/switchToAdmin.sh

#setOrdererGlobals
source /etc/hyperledger/fabric/setup/.env

# Query chaincode on org2-peer0, check if the result is 90
peer chaincode query -C mychannel -n mycc -c '{"Args":["query","a"]}'

# Invoke chaincode on org1-peer0
peer chaincode invoke -C mychannel -n mycc -c '{"Args":["invoke","a","b","10"]}' $ORDERER_CONN_ARGS


# Invoke chaincode on org2-peer0
peer chaincode invoke -C mychannel -n mycc -c '{"Args":["invoke","a","b","10"]}' $ORDERER_CONN_ARGS

# Query chaincode on org2-peer0, check if the result is 80
peer chaincode query -C mychannel -n mycc -c '{"Args":["query","a"]}'

# Query chaincode on org1-peer0, check if the result is 80
peer chaincode query -C mychannel -n mycc -c '{"Args":["query","a"]}'


#######################################################################
################################ org1 CLI #############################
docker exec -it org1-cli bash

source /etc/hyperledger/fabric/setup/.env


# peer channel fetch 1 /data/genesis.block -c mychannel -o org1-orderer:7050 --tls --cafile /data/org2-ca-cert.pem --clientauth --keyfile /data/tls/org1-peer0-client.key --certfile /data/tls/org1-peer0-client.crt
# peer channel fetch config /tmp/config_block.pb -c mychannel -o org1-orderer:7050 --tls --cafile /data/org1-ca-cert.pem --clientauth --keyfile /data/tls/org1-peer0-client.key --certfile /data/tls/org1-peer0-client.crt
# peer channel fetch config /tmp/config_block.pb -c mychannel -o org1-orderer:7050 --tls --cafile /data/org1-ca-cert.pem --clientauth --keyfile /data/tls/org1-peer0-client.key --certfile /data/tls/org1-peer0-client.crt
