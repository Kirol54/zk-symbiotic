# LayerZero DVN with Symbiotic Relay & ZK Finality

This implementation extends the existing Symbiotic Relay task network into a LayerZero DVN (Decentralized Verifier Network) that provides dual security: 
- **Stake-backed verification** through Symbiotic Relay operators  
- **ZK-finalized proof** that LayerZero packets are included in finalized Ethereum blocks

## Architecture Overview

### Core Components

1. **SymbioticDvn Contract** (`src/layerzero/dvn/SymbioticDvn.sol`)
   - Implements LayerZero DVN interface
   - Verifies aggregated BLS signatures from Symbiotic operators
   - Verifies ZK proofs of Ethereum finality
   - Marks packets as verified for LayerZero ULN

2. **LayerZero App Contracts**
   - **AppSource** (`src/layerzero/app/AppSource.sol`): ETH deposit on source chain
   - **AppDest** (`src/layerzero/app/AppDest.sol`): bETH minting on destination chain  
   - **BETH** (`src/layerzero/app/BETH.sol`): Bridged ETH token

3. **ZK Verifier** (`src/layerzero/zk/`)
   - **IZkEthStateVerifier**: Interface for ZK verification
   - **StubZkEthStateVerifier**: Stub implementation for Phase 1

4. **DVN Worker** (`offchain/dvn-worker/`)
   - Listens for LayerZero `PacketSent` events
   - Builds message hash for operator signatures
   - Requests aggregated BLS signature from Relay
   - Fetches ZK proofs from GolemDB
   - Submits verification to DVN contract

## Development Phases

### Phase 1: MVP with Stub ZK ✅
- [x] DVN contract with Symbiotic Settlement integration
- [x] LayerZero app contracts (ETH ↔ bETH)
- [x] Off-chain worker with event listening
- [x] Stub ZK verifier for fast iteration
- [x] End-to-end tests

### Phase 2: Relay Integration (Next)
- [ ] Deploy using existing Symbiotic Relay stack
- [ ] Real BLS signature verification
- [ ] Proper epoch management

### Phase 3: Real ZK Integration (Future)
- [ ] Ethereum finality proof circuit
- [ ] GolemDB integration for proof storage
- [ ] On-chain ZK verifier deployment

## Quick Start

### 1. Deploy Relay Infrastructure
Use existing setup from the base repository:
```bash
./generate_network.sh
cd temp-network && docker compose up -d && cd ..
```

### 2. Deploy DVN Contracts
```bash
# Copy environment template
cp .env.dvn.example .env

# Edit .env with your configuration
# Then deploy:
forge script script/DvnDeploy.s.sol --rpc-url http://127.0.0.1:8546 --broadcast
```

### 3. Start DVN Worker
```bash
cd offchain/dvn-worker
npm install
npm run build

# Copy and edit environment
cp .env.example .env

# Start worker
npm start
```

### 4. Test End-to-End
```bash
forge test --match-test DvnE2E -vv
```

## Message Hash Specification

The DVN uses this hash format for operator signatures:

```
H = keccak256(
  "LZ_DVN_V1" ||
  srcEid || dstEid ||
  packetHeader || payloadHash ||
  srcBlockHash || logIndex || emitter
)
```

This binds exactly the data needed for both LayerZero verification and ZK finality proof.

## Key Files

### Contracts
- `src/layerzero/dvn/SymbioticDvn.sol` - Main DVN implementation
- `src/layerzero/app/` - LayerZero application contracts
- `src/layerzero/zk/` - ZK verification interfaces
- `script/DvnDeploy.s.sol` - Deployment script
- `test/DvnE2E.t.sol` - End-to-end tests

### Off-chain
- `offchain/dvn-worker/src/index.ts` - Main worker entry point  
- `offchain/dvn-worker/src/dvn-worker.ts` - Core worker logic
- `offchain/dvn-worker/src/event-listener.ts` - LayerZero event monitoring
- `offchain/dvn-worker/src/relay-client.ts` - Symbiotic Relay API client
- `offchain/dvn-worker/src/zk-client.ts` - ZK proof fetching

## Security Model

This DVN only verifies packets when **both** conditions are met:

1. **Symbiotic Quorum**: ≥2/3 of stake-weighted operators have signed the message hash
2. **ZK Finality**: A zero-knowledge proof confirms the `PacketSent` log was included in a finalized Ethereum block (≥64 slots/~14 minutes)

This provides dual security: economic (via staking) and cryptographic (via ZK proofs of finality).

## Configuration

Key environment variables:

- `SETTLEMENT_ADDRESS` - Deployed Symbiotic Settlement contract
- `DVN_ADDRESS` - Deployed SymbioticDvn contract  
- `LAYERZERO_ENDPOINT_V2` - LayerZero V2 endpoint addresses
- `RELAY_AGGREGATOR_URL` - Symbiotic Relay aggregator endpoint
- `PRIVATE_KEY` - DVN worker signing key

See `.env.dvn.example` for full configuration.

## Next Steps

1. **Integration Testing**: Deploy on testnets with real LayerZero endpoints
2. **ZK Circuit Development**: Build Ethereum finality proof circuits
3. **Production Hardening**: Error handling, monitoring, gas optimization
4. **Multi-chain Support**: Extend to other LayerZero-supported chains

## References

- [LayerZero V2 DVN Guide](https://docs.layerzero.network/v2/workers/off-chain/build-dvns)
- [Symbiotic Relay Documentation](https://docs.symbiotic.fi/relay-sdk/)
- [LayerZero V2 Protocol Overview](https://docs.layerzero.network/v2/developers/evm/protocol-contracts-overview)