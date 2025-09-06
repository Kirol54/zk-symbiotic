# Phase 0: DVN + Real Relay Integration

This guide shows how to integrate the LayerZero DVN with the **real local Symbiotic Relay infrastructure**.

## 🚀 Quick Start

### 1. Start Relay Infrastructure
```bash
# Generate network config and start all services
./generate_network.sh
cd temp-network && docker compose up -d && cd ..

# Verify services are running
cd temp-network && docker compose ps && cd ..
```

Expected services:
- **anvil** (port 8545) - Source chain
- **anvil-settlement** (port 8546) - Destination chain  
- **relay-sidecar-1,2,3** (ports 8081,8082,8083) - Relay sidecars
- **sum-node-1,2,3** (ports 9091,9092,9093) - Task nodes

### 2. Deploy DVN with Real Settlement
```bash
# Deploy DVN using real Settlement contract
forge script script/DvnRelayIntegration.s.sol --rpc-url http://127.0.0.1:8546 --broadcast --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```

This will output the contract addresses you need for the DVN worker.

### 3. Configure DVN Worker
```bash
cd offchain/dvn-worker

# Create .env file with real contract addresses
cat > .env << EOF
ETH_RPC_URL=http://127.0.0.1:8545
DEST_RPC_URL=http://127.0.0.1:8546
RELAY_AGGREGATOR_URL=http://127.0.0.1:8082
SETTLEMENT_ADDRESS=0xF058C08Ba8ED8465606e534b48b05d2075Dd7ce0
DVN_ADDRESS=<output_from_deploy_script>
LAYERZERO_ENDPOINT_ETH=0x1a44076050125825900e736c501f859c50fE728c
LAYERZERO_ENDPOINT_DEST=0x1a44076050125825900e736c501f859c50fE728c
APP_SOURCE_ADDRESS=<output_from_deploy_script>
APP_DEST_ADDRESS=<output_from_deploy_script>
BETH_TOKEN_ADDRESS=<output_from_deploy_script>
PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
CONFIRMATIONS=2
EOF

# Install and start worker
npm install
npm run build
npm start
```

### 4. Test End-to-End Flow

```bash
# Test 1: Check Settlement has committed epochs
cast call 0xF058C08Ba8ED8465606e534b48b05d2075Dd7ce0 "getLastCommittedHeaderEpoch()" --rpc-url http://127.0.0.1:8546

# Should return > 0 if Relay sidecars are running properly

# Test 2: Simulate LayerZero packet (for now, manually trigger DVN)
cast send <DVN_ADDRESS> "submitVerification(bytes32,bytes32,uint48,bytes,bytes,tuple(uint64,bytes32,bytes32,address,bytes32,uint32,uint64))" \
  0x1234567890123456789012345678901234567890123456789012345678901234 \
  0x0987654321098765432109876543210987654321098765432109876543210987 \
  1 \
  0x000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000 \
  0x0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000 \
  "[1000,0x0000000000000000000000000000000000000000000000000000000000000000,0x0000000000000000000000000000000000000000000000000000000000000000,0x0000000000000000000000000000000000000000,0x0000000000000000000000000000000000000000000000000000000000000000,0,64]" \
  --rpc-url http://127.0.0.1:8546 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```

## 🔍 Verification Steps

### Check Relay Status
```bash
# Check if sidecars are responding
curl -s http://127.0.0.1:8082/health || echo "Aggregator not ready"

# Check Settlement epochs
cast call 0xF058C08Ba8ED8465606e534b48b05d2075Dd7ce0 "getLastCommittedHeaderEpoch()" --rpc-url http://127.0.0.1:8546
```

### Test DVN Integration
```bash
# Run integration tests
forge test --match-contract DvnRelayIntegrationTest -vv --rpc-url http://127.0.0.1:8546
```

Expected output:
- ✅ Settlement connection working
- ✅ Message hash consistency 
- ⚠️  No epochs committed (if sidecars not running)
- ✅ Epochs committed with validator data (if sidecars running)

## 🎯 Current Status

**✅ Completed:**
- DVN contract integrated with real Settlement
- Settlement contract address detection from deployment
- DVN worker updated with proper Relay API calls
- Integration tests with real contracts

**🔄 In Progress:**
- Getting real BLS signatures from running sidecars
- End-to-end verification with actual operator signatures

**🎯 Next Steps:**
- Ensure sidecars are running and committing epochs
- Test real signature aggregation
- Add LayerZero ULN packet verification

## 🐛 Troubleshooting

### "No epochs committed yet"
- Relay sidecars may not be running
- Check: `cd temp-network && docker compose logs relay-sidecar-1`
- Ensure interval mining is enabled: `cast rpc evm_setIntervalMining 1 --rpc-url http://127.0.0.1:8545`

### "Aggregator not responding"
- Sidecar may not have aggregator role
- Check: `cd temp-network && docker compose logs relay-sidecar-2`
- Aggregator should be on port 8082

### "Settlement contract not accessible"
- Check Settlement address in `temp-network/deploy-data/relay_contracts.json`
- Ensure anvil-settlement is running on port 8546

## 📋 Integration Checklist

- [ ] Relay services running (docker compose ps shows all services up)
- [ ] Settlement epochs being committed (getLastCommittedHeaderEpoch > 0)
- [ ] DVN deployed with correct Settlement address
- [ ] DVN worker configured with proper endpoints
- [ ] Integration tests passing
- [ ] Real signature aggregation working

This completes **Phase 0** - DVN working with real local Relay infrastructure!