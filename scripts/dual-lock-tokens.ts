#!/usr/bin/env ts-node

import { ethers } from 'ethers';
import * as dotenv from 'dotenv';

// Load environment variables from both .env and deployed-addresses.env
dotenv.config(); // Load .env first
dotenv.config({ path: './deployed-addresses.env' }); // Then load deployed addresses

// Environment variables
const LOCAL_ETH_PRIV_KEY = "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"; // Anvil prefunded account #0
const HOLESKY_ETH_PRIV_KEY = process.env.HOLESKY_ETH_PRIV_KEY;
const LOCAL_RPC_URL = process.env.LOCAL_RPC_URL || 'http://127.0.0.1:8545';
const HOLESKY_RPC_URL = process.env.HOLESKY_RPC_URL;
const LOCAL_APPSOURCE_ADDRESS = process.env.LOCAL_APPSOURCE_ADDRESS;
const HOLESKY_APPSOURCE_ADDRESS = process.env.HOLESKY_APPSOURCE_ADDRESS;

// AppSource ABI (minimal for depositETH function)
const APP_SOURCE_ABI = [
    "function depositETH(uint32 dstEid, bytes32 receiver, bytes options) external payable returns (bytes32 guid)",
    "function totalLocked() external view returns (uint256)",
    "function getUserLockedTokens(address user) external view returns (uint256)"
];

// LayerZero destination endpoint IDs
const HOLESKY_EID = 40217; // Holesky testnet endpoint ID
const LOCAL_EID = 40231; // Local Anvil endpoint ID (for testing)
const RECEIVER = "0x0000000000000000000000000000000000000000000000000000000000000001"; // 32-byte receiver
const OPTIONS = "0x"; // Empty options for simplicity

interface LockResult {
    local: {
        tx: string;
        guid: string;
        block: number;
    };
    holesky: {
        tx: string;
        guid: string;
        block: number;
    };
}

async function dualLockTokens(amountETH: string): Promise<LockResult> {
    if (!HOLESKY_ETH_PRIV_KEY || !HOLESKY_RPC_URL || !LOCAL_APPSOURCE_ADDRESS || !HOLESKY_APPSOURCE_ADDRESS) {
        throw new Error('Missing required environment variables. Run deploy-dual-appsource.sh first and ensure HOLESKY_ETH_PRIV_KEY is set in .env');
    }

    // Create providers and wallets
    const localProvider = new ethers.JsonRpcProvider(LOCAL_RPC_URL);
    const holeskyProvider = new ethers.JsonRpcProvider(HOLESKY_RPC_URL);
    
    const localWallet = new ethers.Wallet(LOCAL_ETH_PRIV_KEY, localProvider);
    const holeskyWallet = new ethers.Wallet(HOLESKY_ETH_PRIV_KEY, holeskyProvider);
    
    // Create contract instances
    const localAppSource = new ethers.Contract(LOCAL_APPSOURCE_ADDRESS, APP_SOURCE_ABI, localWallet);
    const holeskyAppSource = new ethers.Contract(HOLESKY_APPSOURCE_ADDRESS, APP_SOURCE_ABI, holeskyWallet);
    
    console.log('🔐 Dual Token Locking Started...');
    console.log(`💰 Amount: ${amountETH} ETH`);
    console.log(`👤 LOCAL User:  ${localWallet.address} (Anvil prefunded account #0)`);
    console.log(`👤 HOLESKY User: ${holeskyWallet.address}`);
    console.log('');
    
    // Show initial balances
    const localBalanceBefore = await localProvider.getBalance(localWallet.address);
    const holeskyBalanceBefore = await holeskyProvider.getBalance(holeskyWallet.address);
    
    console.log(`📊 Balances before locking:`);
    console.log(`   LOCAL:  ${ethers.formatEther(localBalanceBefore)} ETH`);
    console.log(`   HOLESKY: ${ethers.formatEther(holeskyBalanceBefore)} ETH`);
    console.log('');

    const amountWei = ethers.parseEther(amountETH);
    
    try {
        console.log('🚀 Executing deposits...');
        console.log('⚠️  Note: LOCAL deployment skipped - LayerZero endpoint not available on Anvil');
        console.log('🌐 Testing only HOLESKY deployment...');
        
        // For now, only test Holesky since LayerZero endpoint exists there
        const holeskyTx = await holeskyAppSource.depositETH(LOCAL_EID, RECEIVER, OPTIONS, { value: amountWei });
        
        console.log('⏳ Waiting for transaction confirmations...');
        console.log(`   HOLESKY TX: ${holeskyTx.hash}`);
        console.log('');
        
        // Wait for confirmations
        const holeskyReceipt = await holeskyTx.wait(2);
        
        console.log('✅ Holesky transaction confirmed!');
        console.log(`   HOLESKY block: ${holeskyReceipt.blockNumber}`);
        console.log('');
        
        // Extract GUID from event
        const holeskyGuid = holeskyReceipt.logs.find((log: any) => 
            log.topics[0] === ethers.id('ETHDeposited(address,uint256,bytes32)')
        )?.topics[3] || 'N/A';
        
        console.log('🎯 LayerZero GUID:');
        console.log(`   HOLESKY: ${holeskyGuid}`);
        console.log('');
        
        // Show final balances and locked amounts
        const holeskyBalanceAfter = await holeskyProvider.getBalance(holeskyWallet.address);
        const holeskyLocked = await holeskyAppSource.getUserLockedTokens(holeskyWallet.address);
        
        console.log('📊 Final status:');
        console.log(`   HOLESKY balance: ${ethers.formatEther(holeskyBalanceAfter)} ETH (locked: ${ethers.formatEther(holeskyLocked)} ETH)`);
        console.log('');
        
        console.log('🎉 Holesky locking completed successfully!');
        console.log('⏰ Finality will be available in ~14 minutes');
        console.log('⚠️  LOCAL locking skipped due to missing LayerZero endpoint on Anvil');
        
        return {
            local: { tx: 'SKIPPED', guid: 'N/A', block: 0 },
            holesky: { tx: holeskyTx.hash, guid: holeskyGuid, block: holeskyReceipt.blockNumber }
        };
        
    } catch (error: any) {
        console.error('❌ Dual locking failed:', error.message);
        throw error;
    }
}

// CLI interface
if (require.main === module) {
    const args = process.argv.slice(2);
    const amount = args[0];
    
    if (!amount) {
        console.log('Usage: ts-node dual-lock-tokens.ts <amount_in_eth>');
        console.log('Example: ts-node dual-lock-tokens.ts 0.1');
        process.exit(1);
    }
    
    dualLockTokens(amount)
        .then((result) => {
            console.log('\n🔗 Transaction summary:');
            console.log(JSON.stringify(result, null, 2));
        })
        .catch((error) => {
            console.error('💥 Script failed:', error.message);
            process.exit(1);
        });
}

export { dualLockTokens };