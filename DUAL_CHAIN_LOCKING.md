# Dual-Chain Token Locking for LayerZero DVN

This document describes the dual-chain token locking mechanism that enables simultaneous ETH deposits on both local blockchain and Holesky testnet for the LayerZero DVN hackathon implementation.

## 🎯 Overview

The dual-chain approach locks tokens on two networks simultaneously:
- **Local Blockchain (Anvil)**: Fast signature verification via Symbiotic Relay
- **Holesky Testnet**: Real finality proofs via GolemDB (~14 minute delay)

This provides dual security: immediate stake-backed verification and cryptographic finality proof.

## 🏗️ Architecture

```
User calls dual-lock-tokens.ts
├── LOCAL: AppSource.depositETH() → immediate LayerZero packet → DVN verifies Relay signatures
├── HOLESKY: AppSource.depositETH() → LayerZero packet → wait ~14min for finality
└── DVN Worker: coordinates both verifications before minting bETH
```

## 📁 Files Structure

### Smart Contract Deployment Scripts
```
script/
├── DeployAppSourceLocal.s.sol    # Deploy AppSource on local Anvil (Chain ID: 31337)
├── DeployAppSourceHolesky.s.sol  # Deploy AppSource on Holesky (Chain ID: 17000)
```

### Orchestration Scripts  
```
scripts/
├── deploy-dual-appsource.sh      # Deploy contracts on both networks
├── dual-lock-tokens.ts           # Execute simultaneous token locking
```

### Generated Files
```
deployed-addresses.env            # Contract addresses from deployment
```

## 🚀 Quick Start

### Prerequisites
- Foundry (forge, cast)
- Node.js with TypeScript support (`ts-node`)
- Environment variables:
  - `PRIVATE_KEY` - Your wallet private key
  - `HOLESKY_RPC_URL` - Holesky testnet RPC endpoint

### 1. Deploy AppSource Contracts

Deploy AppSource contracts on both local and Holesky networks:

```bash
# Set required environment variables
export PRIVATE_KEY="0x..."  
export HOLESKY_RPC_URL="https://ethereum-holesky-rpc.publicnode.com"

# Deploy on both networks
./scripts/deploy-dual-appsource.sh
```

Expected output:
```
🚀 Deploying AppSource on both LOCAL and HOLESKY networks...

📦 Deploying AppSource on LOCAL network (Chain ID: 31337)...
✅ LOCAL AppSource deployed: 0x742d35Cc6C6C21e5B23B03Bb7E0E702A1C6C0f5f

🌐 Deploying AppSource on HOLESKY network (Chain ID: 17000)...  
✅ HOLESKY AppSource deployed: 0x8A791620dd6260079BF849Dc5567aDC3F2FdC318

📝 Addresses saved to deployed-addresses.env:
   LOCAL:  0x742d35Cc6C6C21e5B23B03Bb7E0E702A1C6C0f5f
   HOLESKY: 0x8A791620dd6260079BF849Dc5567aDC3F2FdC318

🎯 Ready for dual token locking!
```

### 2. Execute Dual Token Locking

Lock tokens simultaneously on both networks:

```bash
# Lock 0.1 ETH on both networks
ts-node scripts/dual-lock-tokens.ts 0.1
```

Expected output:
```
🔐 Dual Token Locking Started...
💰 Amount: 0.1 ETH
👤 User: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266

📊 Balances before locking:
   LOCAL:  9999.998 ETH
   HOLESKY: 0.856 ETH

🚀 Executing simultaneous deposits...
⏳ Waiting for transaction confirmations...
   LOCAL TX:  0x1a2b3c4d5e6f789...
   HOLESKY TX: 0x9f8e7d6c5b4a321...

✅ Both transactions confirmed!
   LOCAL block:  123
   HOLESKY block: 456789

🎯 LayerZero GUIDs:
   LOCAL:  0xabcd1234...
   HOLESKY: 0xef567890...

📊 Final status:
   LOCAL balance:  9999.897 ETH (locked: 0.1 ETH)
   HOLESKY balance: 0.755 ETH (locked: 0.1 ETH)

🎉 Dual locking completed successfully!
⏰ Holesky finality will be available in ~14 minutes

🔗 Transaction summary:
{
  "local": {
    "tx": "0x1a2b3c4d5e6f789...",
    "guid": "0xabcd1234...",
    "block": 123
  },
  "holesky": {
    "tx": "0x9f8e7d6c5b4a321...",
    "guid": "0xef567890...",
    "block": 456789
  }
}
```

## 🔧 Configuration

### Contract Addresses

After deployment, addresses are saved in `deployed-addresses.env`:

```env
LOCAL_APPSOURCE_ADDRESS=0x742d35Cc6C6C21e5B23B03Bb7E0E702A1C6C0f5f
HOLESKY_APPSOURCE_ADDRESS=0x8A791620dd6260079BF849Dc5567aDC3F2FdC318
LOCAL_RPC_URL=http://127.0.0.1:8545
HOLESKY_RPC_URL=https://ethereum-holesky-rpc.publicnode.com
```

### LayerZero Configuration

Both contracts use the same LayerZero V2 endpoint:
- **Endpoint Address**: `0x1a44076050125825900e736c501f859c50fE728c`
- **Destination EID**: `40267` (configured in script)
- **Receiver**: `0x0000000000000000000000000000000000000000000000000000000000000001`

## ⚡ Technical Details

### Simultaneous Execution

The `dual-lock-tokens.ts` script uses `Promise.all()` to execute both transactions simultaneously:

```typescript
const [localTx, holeskyTx] = await Promise.all([
    localAppSource.depositETH(DST_EID_DEST, RECEIVER, OPTIONS, { value: amountWei }),
    holeskyAppSource.depositETH(DST_EID_DEST, RECEIVER, OPTIONS, { value: amountWei })
]);
```

### Transaction Monitoring

The script:
1. **Executes** both deposits simultaneously
2. **Waits** for 2 confirmations on each network  
3. **Extracts** LayerZero GUIDs from `ETHDeposited` events
4. **Reports** transaction hashes, block numbers, and timing

### Error Handling

If one transaction fails, the script will:
- Log the specific error
- Show which transactions may still be pending
- Provide transaction hashes for manual checking

## 🎯 Integration with DVN

### Timeline

1. **T+0**: Dual locking executes, LOCAL packet verified immediately via Relay
2. **T+0-2min**: LOCAL DVN verification completes (stake-backed)
3. **T+14min**: Holesky finality achieved, proof available in GolemDB
4. **T+14min**: Holesky DVN verification completes (ZK finality)
5. **T+14min**: Both verifications complete → bETH minted

### DVN Worker Coordination

The DVN worker will need to:
- Monitor PacketSent events from both LOCAL and HOLESKY AppSource contracts
- Verify LOCAL packets immediately using Symbiotic Relay signatures
- Poll GolemDB for Holesky finality proofs (~14 minute delay)
- Only proceed with final verification once BOTH are complete

## 🧪 Testing

### Local Testing

Ensure local Symbiotic Relay infrastructure is running:

```bash
# Check relay status  
./scripts/check-relay-status.sh

# Should show sidecars UP on ports 8081, 8082, 8083
```

### Holesky Testing

Ensure you have Holesky ETH for gas and locking:
- Get testnet ETH from [Holesky faucet](https://faucet.holesky.ethpandaops.io/)
- Verify RPC connectivity: `cast block-number --rpc-url $HOLESKY_RPC_URL`

## 🚨 Important Notes

### Timing Considerations

- **LOCAL**: Instant verification via Relay signatures
- **HOLESKY**: ~14 minutes for consensus finality (≥64 slots)
- **Total Flow**: Complete verification requires BOTH to succeed

### Gas Considerations

- **LOCAL**: Minimal gas costs on Anvil
- **HOLESKY**: Real testnet gas costs apply
- **Safety**: Script checks balances before execution

### Security

- Private keys are loaded from environment variables
- Transactions are executed with 2-confirmation requirement
- Both networks must complete successfully for DVN verification

## 🔄 Next Steps

After dual locking is working:

1. **GolemDB Integration**: Implement real polling for Holesky finality proofs
2. **DVN Worker Updates**: Coordinate dual verification (LOCAL Relay + HOLESKY ZK)  
3. **ZK Verifier**: Create hackathon ZK verifier that returns `true`
4. **End-to-end Testing**: Test complete flow from lock → verify → mint

## 📚 Related Documentation

- [LAYERZERO_DVN_STATUS.md](./LAYERZERO_DVN_STATUS.md) - Overall project status
- [PHASE0_RELAY_INTEGRATION.md](./PHASE0_RELAY_INTEGRATION.md) - Relay integration guide
- [AppSource.sol](./src/layerzero/app/AppSource.sol) - Token locking contract