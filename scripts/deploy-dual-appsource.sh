#!/bin/bash

# set -e  # Exit on any error

echo "🚀 Deploying AppSource on both LOCAL and HOLESKY networks..."
echo ""

# Load .env file if it exists
if [ -f .env ]; then
    echo "📋 Loading environment variables from .env file..."
    export $(grep -v '^#' .env | xargs)
fi

# Use Anvil's first prefunded account for local deployment
LOCAL_ETH_PRIV_KEY="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"

# Function to ensure private key has 0x prefix for Forge commands
ensure_0x_prefix() {
    local key=$1
    if [[ $key == 0x* ]]; then
        echo "$key"
    else
        echo "0x$key"
    fi
}

# Function to normalize private key (remove 0x prefix if present)
normalize_private_key() {
    local key=$1
    if [[ $key == 0x* ]]; then
        echo "${key:2}"
    else
        echo "$key"
    fi
}

# Check required environment variables
if [ -z "$HOLESKY_ETH_PRIV_KEY" ]; then
    echo "❌ HOLESKY_ETH_PRIV_KEY environment variable not set"
    echo "Please set it in .env file or export it directly"
    echo "You can include the 0x prefix or omit it"
    exit 1
fi

if [ -z "$HOLESKY_RPC_URL" ]; then
    echo "❌ HOLESKY_RPC_URL environment variable not set"
    echo "Please set it in .env file or export it directly"
    exit 1
fi

# Normalize the Holesky private key
HOLESKY_ETH_PRIV_KEY=$(normalize_private_key "$HOLESKY_ETH_PRIV_KEY")
LOCAL_ETH_PRIV_KEY=$(normalize_private_key "$LOCAL_ETH_PRIV_KEY")

echo "🔑 Using Anvil prefunded account #0 for LOCAL deployment"

# Function to check if address is a valid contract
check_contract_deployment() {
    local address=$1
    local rpc_url=$2
    local network_name=$3
    
    echo "🔍 Verifying contract deployment at $address on $network_name..."
    
    # Check if address is valid format
    if [[ ! $address =~ ^0x[a-fA-F0-9]{40}$ ]]; then
        echo "❌ Invalid contract address format: $address"
        return 1
    fi
    
    # Check if address contains code (is a contract)
    local code=$(cast code $address --rpc-url $rpc_url 2>/dev/null || echo "")
    if [ "$code" == "0x" ] || [ -z "$code" ]; then
        echo "❌ No contract code found at address $address on $network_name"
        return 1
    fi
    
    echo "✅ Contract verified at $address on $network_name"
    return 0
}

# Function to verify contract functionality
verify_contract_functionality() {
    local address=$1
    local rpc_url=$2
    local network_name=$3
    local expected_endpoint=$4
    
    echo "🧪 Testing contract functionality at $address on $network_name..."
    
    # Test that we can call the endpoint() function
    local actual_endpoint=$(cast call $address "endpoint()(address)" --rpc-url $rpc_url 2>/dev/null || echo "")
    if [ -z "$actual_endpoint" ]; then
        echo "❌ Failed to call endpoint() function on $network_name contract"
        return 1
    fi
    
    # Normalize addresses for comparison (convert to lowercase)
    actual_endpoint=$(echo "$actual_endpoint" | tr '[:upper:]' '[:lower:]')
    expected_endpoint=$(echo "$expected_endpoint" | tr '[:upper:]' '[:lower:]')
    
    if [ "$actual_endpoint" != "$expected_endpoint" ]; then
        echo "❌ Endpoint mismatch on $network_name: expected $expected_endpoint, got $actual_endpoint"
        return 1
    fi
    
    echo "✅ Contract functionality verified on $network_name (endpoint: $actual_endpoint)"
    return 0
}

# Function to check account balance
check_balance() {
    local rpc_url=$1
    local network_name=$2
    local private_key=$3
    
    echo "💰 Checking balance on $network_name..."
    local deployer_address=$(cast wallet address --private-key $private_key)
    local balance=$(cast balance $deployer_address --rpc-url $rpc_url 2>/dev/null || echo "0")
    
    if [ "$balance" == "0" ]; then
        echo "⚠️  Warning: Zero balance detected for $deployer_address on $network_name"
        return 1
    fi
    
    local balance_eth=$(cast --to-unit $balance ether)
    echo "✅ Balance on $network_name: $balance_eth ETH ($deployer_address)"
    return 0
}

# Check balances before deployment
echo "🔍 Pre-deployment checks..."
check_balance "http://127.0.0.1:8545" "LOCAL" "$LOCAL_ETH_PRIV_KEY" || {
    echo "⚠️  Continuing with LOCAL deployment despite balance warning..."
}
check_balance "$HOLESKY_RPC_URL" "HOLESKY" "$HOLESKY_ETH_PRIV_KEY" || {
    echo "❌ Insufficient balance on HOLESKY network"
    exit 1
}
echo ""

# Local deployment (Anvil)
echo "📦 Deploying AppSource on LOCAL network (Chain ID: 31337)..."
LOCAL_PRIV_KEY_WITH_PREFIX=$(ensure_0x_prefix "$LOCAL_ETH_PRIV_KEY")
LOCAL_RESULT=$(PRIVATE_KEY=$LOCAL_PRIV_KEY_WITH_PREFIX forge script script/DeployAppSourceLocal.s.sol --rpc-url http://127.0.0.1:8545 --broadcast --private-key $LOCAL_PRIV_KEY_WITH_PREFIX 2>&1)
LOCAL_ADDRESS=$(echo "$LOCAL_RESULT" | grep "AppSource deployed on LOCAL to:" | awk '{print $6}')

if [ -z "$LOCAL_ADDRESS" ]; then
    echo "❌ Failed to deploy AppSource on LOCAL network"
    echo "Deployment output:"
    echo "$LOCAL_RESULT"
    exit 1
fi

echo "✅ LOCAL AppSource deployed: $LOCAL_ADDRESS"

# Verify LOCAL deployment
LOCAL_ENDPOINT="0x1a44076050125825900e736c501f859c50fE728c"
check_contract_deployment "$LOCAL_ADDRESS" "http://127.0.0.1:8545" "LOCAL" || exit 1
verify_contract_functionality "$LOCAL_ADDRESS" "http://127.0.0.1:8545" "LOCAL" "$LOCAL_ENDPOINT" || exit 1
echo ""

# Holesky deployment  
echo "🌐 Deploying AppSource on HOLESKY network (Chain ID: 17000)..."
HOLESKY_PRIV_KEY_WITH_PREFIX=$(ensure_0x_prefix "$HOLESKY_ETH_PRIV_KEY")
HOLESKY_RESULT=$(PRIVATE_KEY=$HOLESKY_PRIV_KEY_WITH_PREFIX forge script script/DeployAppSourceHolesky.s.sol --rpc-url $HOLESKY_RPC_URL --broadcast --private-key $HOLESKY_PRIV_KEY_WITH_PREFIX 2>&1)
HOLESKY_ADDRESS=$(echo "$HOLESKY_RESULT" | grep "AppSource deployed on HOLESKY to:" | awk '{print $6}')

if [ -z "$HOLESKY_ADDRESS" ]; then
    echo "❌ Failed to deploy AppSource on HOLESKY network"
    echo "Deployment output:"
    echo "$HOLESKY_RESULT"
    exit 1
fi

echo "✅ HOLESKY AppSource deployed: $HOLESKY_ADDRESS"

# Verify HOLESKY deployment
HOLESKY_ENDPOINT="0x6EDCE65403992e310A62460808c4b910D972f10f"
check_contract_deployment "$HOLESKY_ADDRESS" "$HOLESKY_RPC_URL" "HOLESKY" || exit 1
verify_contract_functionality "$HOLESKY_ADDRESS" "$HOLESKY_RPC_URL" "HOLESKY" "$HOLESKY_ENDPOINT" || exit 1
echo ""

# Final verification and summary
echo "🔍 Final deployment verification..."

# Verify both contracts are still accessible and functional
echo "Testing LOCAL contract accessibility..."
cast call "$LOCAL_ADDRESS" "endpoint()(address)" --rpc-url "http://127.0.0.1:8545" > /dev/null || {
    echo "❌ LOCAL contract verification failed in final check"
    exit 1
}

echo "Testing HOLESKY contract accessibility..."
cast call "$HOLESKY_ADDRESS" "endpoint()(address)" --rpc-url "$HOLESKY_RPC_URL" > /dev/null || {
    echo "❌ HOLESKY contract verification failed in final check"
    exit 1
}

# Save addresses for dual locking script
echo "💾 Saving deployment addresses..."
cat > deployed-addresses.env << EOF
# Deployment completed on $(date)
# Contracts verified and functional
LOCAL_APPSOURCE_ADDRESS=$LOCAL_ADDRESS
HOLESKY_APPSOURCE_ADDRESS=$HOLESKY_ADDRESS
LOCAL_RPC_URL=http://127.0.0.1:8545
EOF

echo ""
echo "🎉 Deployment successful and verified!"
echo "📝 Addresses saved to deployed-addresses.env:"
echo "   LOCAL:  $LOCAL_ADDRESS"
echo "   HOLESKY: $HOLESKY_ADDRESS"
echo ""
echo "✅ Both contracts deployed and verified successfully"
echo "🎯 Ready for dual token locking!"