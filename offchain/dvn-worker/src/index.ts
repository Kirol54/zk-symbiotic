import dotenv from 'dotenv';
import { DvnWorker } from './dvn-worker';
import { Config } from './types';

dotenv.config();

async function main() {
  const config: Config = {
    ethRpcUrl: process.env.ETH_RPC_URL || 'http://127.0.0.1:8545',
    destRpcUrl: process.env.DEST_RPC_URL || 'http://127.0.0.1:8546',
    relayAggregatorUrl: process.env.RELAY_AGGREGATOR_URL || 'http://127.0.0.1:8082',
    dvnAddress: process.env.DVN_ADDRESS || '',
    settlementAddress: process.env.SETTLEMENT_ADDRESS || '',
    layerzeroEndpointEth: process.env.LAYERZERO_ENDPOINT_ETH || '',
    layerzeroEndpointDest: process.env.LAYERZERO_ENDPOINT_DEST || '',
    appSourceAddress: process.env.APP_SOURCE_ADDRESS || '',
    appDestAddress: process.env.APP_DEST_ADDRESS || '',
    confirmations: parseInt(process.env.CONFIRMATIONS || '64'),
    privateKey: process.env.PRIVATE_KEY || '',
    golemDbUrl: process.env.GOLEM_DB_URL,
  };

  // Validate required config
  const requiredFields = [
    'dvnAddress', 
    'settlementAddress', 
    'layerzeroEndpointEth', 
    'layerzeroEndpointDest', 
    'privateKey'
  ];
  
  const missingFields = requiredFields.filter(field => !config[field as keyof Config]);
  if (missingFields.length > 0) {
    console.error('❌ Missing required environment variables:', missingFields);
    process.exit(1);
  }

  console.log('🔧 DVN Worker Configuration:');
  console.log(`   ETH RPC: ${config.ethRpcUrl}`);
  console.log(`   Dest RPC: ${config.destRpcUrl}`);
  console.log(`   DVN Address: ${config.dvnAddress}`);
  console.log(`   Settlement: ${config.settlementAddress}`);
  console.log(`   LZ Endpoint ETH: ${config.layerzeroEndpointEth}`);
  console.log(`   LZ Endpoint Dest: ${config.layerzeroEndpointDest}`);
  console.log(`   Confirmations: ${config.confirmations}`);
  console.log(`   GolemDB URL: ${config.golemDbUrl || 'Not configured (using stubs)'}`);

  const worker = new DvnWorker(config);

  // Handle graceful shutdown
  process.on('SIGINT', () => {
    console.log('\n🛑 Shutting down DVN Worker...');
    process.exit(0);
  });

  process.on('SIGTERM', () => {
    console.log('\n🛑 Shutting down DVN Worker...');
    process.exit(0);
  });

  try {
    await worker.start();
    
    // Keep the process running
    console.log('🏃 DVN Worker is running... Press Ctrl+C to stop');
    await new Promise(() => {}); // Keep alive indefinitely
    
  } catch (error) {
    console.error('❌ Failed to start DVN Worker:', error);
    process.exit(1);
  }
}

main().catch((error) => {
  console.error('❌ Unhandled error:', error);
  process.exit(1);
});