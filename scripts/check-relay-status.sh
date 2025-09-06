#!/bin/bash

echo "🔍 Checking Relay Infrastructure Status..."
echo ""

# Check if Docker services are running
echo "📦 Docker Services:"
if [ -d "temp-network" ]; then
    cd temp-network
    docker compose ps --format "table {{.Service}}\t{{.State}}\t{{.Ports}}"
    cd ..
else
    echo "❌ temp-network directory not found. Run ./generate_network.sh first"
    exit 1
fi

echo ""
echo "🏗️  Settlement Contract Status:"

# Check Settlement contract addresses
if [ -f "temp-network/deploy-data/relay_contracts.json" ]; then
    SETTLEMENT_ADDR=$(jq -r '.settlements[0].addr' temp-network/deploy-data/relay_contracts.json)
    echo "Settlement Address: $SETTLEMENT_ADDR"
    
    # Check last committed epoch
    EPOCH=$(cast call $SETTLEMENT_ADDR "getLastCommittedHeaderEpoch()" --rpc-url http://127.0.0.1:8546 2>/dev/null)
    if [ $? -eq 0 ]; then
        EPOCH_DEC=$((EPOCH))
        if [ $EPOCH_DEC -gt 0 ]; then
            echo "✅ Last committed epoch: $EPOCH_DEC"
            
            # Get epoch details
            KEY_TAG=$(cast call $SETTLEMENT_ADDR "getRequiredKeyTagFromValSetHeaderAt(uint48)" $EPOCH --rpc-url http://127.0.0.1:8546 2>/dev/null)
            THRESHOLD=$(cast call $SETTLEMENT_ADDR "getQuorumThresholdFromValSetHeaderAt(uint48)" $EPOCH --rpc-url http://127.0.0.1:8546 2>/dev/null)
            
            if [ $? -eq 0 ]; then
                echo "   Key Tag: $KEY_TAG"  
                echo "   Quorum Threshold: $THRESHOLD"
            fi
        else
            echo "⚠️  No epochs committed yet (epoch: $EPOCH_DEC)"
            echo "   Relay sidecars may not be running properly"
        fi
    else
        echo "❌ Cannot connect to Settlement contract"
    fi
else
    echo "❌ relay_contracts.json not found"
fi

echo ""
echo "🤝 Relay Sidecars:"

# Check sidecar health (they respond with 302 redirect to /docs/, so any response means UP)
for port in 8081 8082 8083; do
    if curl -s "http://127.0.0.1:$port/" | grep -q "Found"; then
        echo "✅ Sidecar on port $port: UP"
    else
        echo "❌ Sidecar on port $port: DOWN"
    fi
done

echo ""
echo "⛓️  Chain Status:"

# Check if interval mining is enabled
ETH_BLOCK=$(cast block-number --rpc-url http://127.0.0.1:8545 2>/dev/null)
DEST_BLOCK=$(cast block-number --rpc-url http://127.0.0.1:8546 2>/dev/null)

if [ $? -eq 0 ]; then
    echo "✅ ETH chain (8545): Block $ETH_BLOCK"
    echo "✅ Dest chain (8546): Block $DEST_BLOCK"
else
    echo "❌ Cannot connect to chains"
fi

echo ""
echo "🎯 Integration Readiness:"

# Check for Settlement verification errors
echo "📋 Committer Status:"
cd temp-network 2>/dev/null
if docker compose logs relay-sidecar-1 2>/dev/null | grep -q "Settlement_VerificationFailed"; then
    echo "❌ Committer failing with Settlement_VerificationFailed"
    echo "   This is a known issue with the current Relay setup"
    echo "   DVN can still be tested with mock signatures"
else
    echo "✅ No Settlement verification errors found"
fi
cd .. 2>/dev/null

echo ""

# Determine if ready for DVN testing
READY=true

if [ ! -f "temp-network/deploy-data/relay_contracts.json" ]; then
    echo "❌ Relay infrastructure not deployed"
    READY=false
fi

echo "🎯 DVN Integration Status:"

if [ "$READY" = true ]; then
    if [ $EPOCH_DEC -gt 0 ] 2>/dev/null; then
        echo "✅ Ready for DVN with REAL signatures!"
    else
        echo "⚠️  Ready for DVN with MOCK signatures (Settlement verification issues)"
        echo "   DVN will work but fall back to mock BLS signatures"
    fi
    echo ""
    echo "Next steps:"
    echo "1. forge script script/DvnRelayIntegration.s.sol --rpc-url http://127.0.0.1:8546 --broadcast"
    echo "2. cd offchain/dvn-worker && npm install && npm start" 
    echo "3. The DVN worker will gracefully handle mock vs real signatures"
else
    echo "❌ Not ready - fix infrastructure issues first"
fi