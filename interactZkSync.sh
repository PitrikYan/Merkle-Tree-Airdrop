#!/bin/bash

# Define constants
DEFAULT_ZKSYNC_LOCAL_KEY="0x7726827caac94a7f9e1b160f7ea819f172f7b6f9d2a97f992c38edeab82d4110"
DEFAULT_ANVIL_KEY="0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d"
DEFAULT_ZKSYNC_ADDRESS="0x36615Cf349d7F6344891B1e7CA7C72883F5dc049"
DEFAULT_ANVIL_ADDRESS="0x70997970C51812dc3A010C7d01b50e0d17dc79C8"

ROOT="0x9335a07b393fa3eb382c11e887392af4abc10680ff91a264ed0a2def5ebed8ec"
PROOF_1="0xdc7479a528fc67c3f81ed45dd6316933b4f30024c76aa56f3577de243455a76d"
PROOF_2="0x37c15d62c3b3b12269d59d1eada7a8dcb48a48ff0d8cce622899968d775dd814"


# Compile and deploy BagelToken contract
echo "Creating zkSync local node..."
npx zksync-cli dev start
echo "Deploying token contract..."
TOKEN_ADDRESS=$(forge create src/VacuumToken.sol:VacuumToken --rpc-url http://127.0.0.1:8011 --private-key ${DEFAULT_ZKSYNC_LOCAL_KEY} --legacy --zksync | awk '/Deployed to:/ {print $3}' )
echo "Token contract deployed at: $TOKEN_ADDRESS"

# Deploy MerkleAirdrop contract
echo "Deploying MerkleAirdrop contract..."
AIRDROP_ADDRESS=$(forge create src/MerkleAirdrop.sol:MerkleAirdrop --rpc-url http://127.0.0.1:8011 --private-key ${DEFAULT_ZKSYNC_LOCAL_KEY} --constructor-args ${ROOT} ${TOKEN_ADDRESS} --legacy --zksync | awk '/Deployed to:/ {print $3}' )
echo "MerkleAirdrop contract deployed at: $AIRDROP_ADDRESS"

# Get message hash
MESSAGE_HASH=$(cast call ${AIRDROP_ADDRESS} "getMessageHash(address,uint256)" ${DEFAULT_ANVIL_ADDRESS} 25000000000000000000 --rpc-url http://127.0.0.1:8011)

# Sign message
echo "Signing message..."
SIGNATURE=$(cast wallet sign --private-key ${DEFAULT_ANVIL_KEY} --no-hash ${MESSAGE_HASH})
CLEAN_SIGNATURE=$(echo "$SIGNATURE" | sed 's/^0x//')
echo -n "$CLEAN_SIGNATURE" >> signature.txt

# Split signature and logs v,r,s to the terminal
SIGN_OUTPUT=$(forge script script/SplitSignature.s.sol:SplitSignature)

# Read from the terminal
V=$(echo "$SIGN_OUTPUT" | grep -A 1 "v value:" | tail -n 1 | xargs)
R=$(echo "$SIGN_OUTPUT" | grep -A 1 "r value:" | tail -n 1 | xargs)
S=$(echo "$SIGN_OUTPUT" | grep -A 1 "s value:" | tail -n 1 | xargs)

# Execute remaining steps
echo "Sending tokens to the token contract owner..."
cast send ${TOKEN_ADDRESS} 'mint(address,uint256)' ${DEFAULT_ZKSYNC_ADDRESS} 100000000000000000000 --private-key ${DEFAULT_ZKSYNC_LOCAL_KEY} --rpc-url http://127.0.0.1:8011 > /dev/null
echo "Sending tokens to the airdrop contract..."
cast send ${TOKEN_ADDRESS} 'transfer(address,uint256)' ${AIRDROP_ADDRESS} 100000000000000000000 --private-key ${DEFAULT_ZKSYNC_LOCAL_KEY} --rpc-url http://127.0.0.1:8011 > /dev/null
echo "Claiming tokens on behalf of 0x70997970C51812dc3A010C7d01b50e0d17dc79C8..."
cast send ${AIRDROP_ADDRESS} 'claim(address,uint256,bytes32[],uint8,bytes32,bytes32)' ${DEFAULT_ANVIL_ADDRESS} 25000000000000000000 "[${PROOF_1},${PROOF_2}]" ${V} ${R} ${S} --private-key ${DEFAULT_ZKSYNC_LOCAL_KEY} --rpc-url http://127.0.0.1:8011 > /dev/null

HEX_BALANCE=$(cast call ${TOKEN_ADDRESS} 'balanceOf(address)' ${DEFAULT_ANVIL_ADDRESS} --rpc-url http://127.0.0.1:8011)

# Assuming OUTPUT is defined somewhere in your process or script
echo "Balance of the claiming address (0x70997970C51812dc3A010C7d01b50e0d17dc79C8): $(cast --to-dec ${HEX_BALANCE})"

# Clean up
rm signature.txt