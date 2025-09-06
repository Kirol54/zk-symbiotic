import { ethers } from 'ethers';
import { Config, PacketSentEvent, VerificationRequest } from './types';
import { EventListener } from './event-listener';
import { RelayClient } from './relay-client';
import { ZkClient } from './zk-client';
import { buildMessageHash } from './utils/hash';

export class DvnWorker {
  private ethProvider: ethers.Provider;
  private destProvider: ethers.Provider;
  private eventListener: EventListener;
  private relayClient: RelayClient;
  private zkClient: ZkClient;
  private wallet: ethers.Wallet;
  private dvnContract: ethers.Contract;

  constructor(private config: Config) {
    this.ethProvider = new ethers.JsonRpcProvider(config.ethRpcUrl);
    this.destProvider = new ethers.JsonRpcProvider(config.destRpcUrl);
    this.eventListener = new EventListener(config.ethRpcUrl);
    this.relayClient = new RelayClient(config.relayAggregatorUrl);
    this.zkClient = new ZkClient(config.golemDbUrl);
    this.wallet = new ethers.Wallet(config.privateKey, this.destProvider);
    
    // DVN contract ABI (simplified)
    const dvnAbi = [
      'function submitVerification(bytes32 packetId, bytes32 H, uint48 epoch, bytes calldata relayProof, bytes calldata zkProof, tuple(uint64 slot, bytes32 blockHash, bytes32 receiptsRoot, address emitter, bytes32 topicsHash, uint32 logIndex, uint64 minFinality) zkInputs)',
      'function verified(bytes32) view returns (bool)',
      'event Verified(bytes32 indexed packetId, bytes32 H)',
      'event Submitted(bytes32 indexed packetId)'
    ];
    
    this.dvnContract = new ethers.Contract(config.dvnAddress, dvnAbi, this.wallet);
  }

  async start(): Promise<void> {
    console.log('🚀 Starting DVN Worker...');
    console.log(`📡 Listening on ETH: ${this.config.ethRpcUrl}`);
    console.log(`🎯 Submitting to Dest: ${this.config.destRpcUrl}`);
    console.log(`🔗 DVN Contract: ${this.config.dvnAddress}`);

    await this.eventListener.listenForPacketSentEvents(
      this.config.layerzeroEndpointEth,
      this.handlePacketSentEvent.bind(this),
      'latest'
    );

    console.log('✅ DVN Worker started successfully');
  }

  private async handlePacketSentEvent(event: PacketSentEvent): Promise<void> {
    console.log(`📦 New PacketSent event: ${event.packetId}`);
    console.log(`   Block: ${event.blockNumber}, TX: ${event.transactionHash}`);

    try {
      // Check if already verified
      const isVerified = await this.dvnContract.verified(event.packetId);
      if (isVerified) {
        console.log(`⏭️  Packet ${event.packetId} already verified, skipping`);
        return;
      }

      // Wait for finality (simplified check)
      console.log(`⏳ Waiting for block finality...`);
      const isFinalized = await this.eventListener.getBlockFinality(event.blockNumber);
      if (!isFinalized) {
        console.log(`⏱️  Block not finalized yet, will retry later`);
        // In production, you'd queue this for later processing
        return;
      }

      // Build verification request
      const verificationRequest = await this.buildVerificationRequest(event);
      
      // Submit verification
      await this.submitVerification(verificationRequest);
      
    } catch (error) {
      console.error(`❌ Error processing packet ${event.packetId}:`, error);
    }
  }

  private async buildVerificationRequest(event: PacketSentEvent): Promise<VerificationRequest> {
    console.log(`🔨 Building verification request for packet: ${event.packetId}`);

    // Build message hash that operators sign
    const messageHash = buildMessageHash(
      event.srcEid,
      event.dstEid,
      event.packetHeader,
      event.payloadHash,
      event.blockHash,
      event.logIndex,
      event.emitter
    );

    console.log(`🔐 Message hash: ${messageHash}`);

    // Request aggregated signature from Relay
    const relayResponse = await this.relayClient.requestSignature(messageHash);
    console.log(`✅ Got Relay signature for epoch: ${relayResponse.epoch}`);

    // Get ZK proof
    const zkResponse = await this.zkClient.getZkProof(event.packetId);
    console.log(`🔍 Got ZK proof (stub mode)`);

    return {
      packetId: event.packetId,
      messageHash,
      epoch: relayResponse.epoch,
      relayProof: relayResponse.aggregatedSignature,
      zkProof: zkResponse.proof,
      zkInputs: zkResponse.inputs,
    };
  }

  private async submitVerification(request: VerificationRequest): Promise<void> {
    console.log(`📤 Submitting verification for packet: ${request.packetId}`);

    try {
      const tx = await this.dvnContract.submitVerification(
        request.packetId,
        request.messageHash,
        request.epoch,
        request.relayProof,
        request.zkProof,
        request.zkInputs,
        { gasLimit: 500000 } // Adjust gas limit as needed
      );

      console.log(`📋 Verification submitted, TX: ${tx.hash}`);
      
      const receipt = await tx.wait();
      console.log(`✅ Verification confirmed in block: ${receipt.blockNumber}`);
      
      // Look for Verified event
      const verifiedEvent = receipt.logs?.find((log: any) => 
        log.topics[0] === ethers.id('Verified(bytes32,bytes32)')
      );
      
      if (verifiedEvent) {
        console.log(`🎉 Packet ${request.packetId} successfully verified!`);
      }
      
    } catch (error) {
      console.error(`❌ Failed to submit verification:`, error);
      throw error;
    }
  }
}