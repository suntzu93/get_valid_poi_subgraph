#!/bin/sh
# Find all subgraph health:
#query {
#  indexingStatuses {
#    subgraph
#    synced
#    health
#  }
#}
INDEXER_ADDRESS='change_your_indexer_address'
INDEXER_EVM_RPC_URL="change_your_eth_rpc"

SUBGRAPH_DEPLOYMENT=$1
BLOCK_NUMBER=$2


if [ -z "$INDEXER_ADDRESS" ]; then
        echo 'Environment variable INDEXER_ADDRESS must be set to a valid indexer address'
        exit 1
fi

if [ -z "$SUBGRAPH_DEPLOYMENT" ] || [ -z "$BLOCK_NUMBER" ]; then
        echo "Usage: $0 [subgraph deployment IPFS hash] [last good block number]"
        exit 1
fi

if [ "$BLOCK_NUMBER" -lt 11446768 ]; then
        startBlock=11446768
        echo "startBlock: $startBlock"
else
        start_block='{epoches(where: {startBlock_lt: '$BLOCK_NUMBER', endBlock_gt: '$BLOCK_NUMBER'}){startBlock}}'
        start_block_json="{\"query\":\"$start_block\"}"

        startBlock=$(curl \
                -s -L -X POST -H 'Content-Type: application/json' \
                -d "$start_block_json" https://api.thegraph.com/subgraphs/name/graphprotocol/graph-network-mainnet | \
                jq -r '.data.epoches[0].startBlock')
        echo "query startBlock: " $startBlock
fi

BLOCK_HEX=$(echo "obase=16; $startBlock" | bc | xargs printf "0x%s\n")


BLOCK_HASH=$(curl \
        -s -X POST -H 'Content-Type: application/json' \
        --data '{"jsonrpc":"2.0","method":"eth_getBlockByNumber","params":["'$BLOCK_HEX'", false],"id":1}' \
        $INDEXER_EVM_RPC_URL | \
        jq -r '.result.hash')
if [ -z "$BLOCK_HASH" ]; then
                echo "Block $startBlock not found"
                exit 2
fi


gql_query='query { proofOfIndexing(subgraph: \"'$SUBGRAPH_DEPLOYMENT'\", blockHash: \"'$BLOCK_HASH'\", blockNumber: '$startBlock', indexer: \"'$INDEXER_ADDRESS'\") }'
json="{\"query\":\"$gql_query\"}"

POI=$(curl \
        -s -L -X POST -H 'Content-Type: application/json' \
        -d "$json" http://127.0.0.1:8030/graphql | \
        jq -r '.data.proofOfIndexing')
echo $POI
