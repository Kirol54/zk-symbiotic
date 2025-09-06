import { ethers } from 'ethers';
import { PacketSentEvent } from './types';

export class EventListener {
  private provider: ethers.Provider;

  constructor(rpcUrl: string) {
    this.provider = new ethers.JsonRpcProvider(rpcUrl);
  }

  async listenForPacketSentEvents(
    endpointAddress: string,
    callback: (event: PacketSentEvent) => void,
    fromBlock: number | 'latest' = 'latest'
  ): Promise<void> {
    console.log(`Starting to listen for PacketSent events on ${endpointAddress}`);

    // PacketSent event signature from LayerZero V2
    const eventTopic = ethers.id('PacketSent(bytes,bytes32,address)');
    
    const filter = {
      address: endpointAddress,
      topics: [eventTopic],
      fromBlock: fromBlock,
    };

    this.provider.on(filter, async (log) => {
      try {
        const parsedLog = this.parsePacketSentLog(log);
        callback(parsedLog);
      } catch (error) {
        console.error('Error parsing PacketSent event:', error);
      }
    });

    console.log('Event listener started successfully');
  }

  private parsePacketSentLog(log: ethers.Log): PacketSentEvent {
    const iface = new ethers.Interface([
      'event PacketSent(bytes encodedPacket, bytes32 payloadHash, address sender)'
    ]);
    
    const parsed = iface.parseLog({
      topics: log.topics,
      data: log.data
    });

    if (!parsed) {
      throw new Error('Failed to parse PacketSent event');
    }

    // Extract packet details from encodedPacket
    // This is a simplified parsing - in production you'd need proper LZ V2 packet parsing
    const encodedPacket = parsed.args.encodedPacket;
    const payloadHash = parsed.args.payloadHash;
    
    // Mock packet parsing for demo
    const srcEid = 30101; // Ethereum mainnet EID
    const dstEid = 30184; // Base mainnet EID
    const packetHeader = encodedPacket.slice(0, 66); // Mock header extraction
    
    return {
      packetId: this.generatePacketId(srcEid, dstEid, packetHeader, payloadHash),
      srcEid,
      dstEid,
      packetHeader,
      payloadHash,
      blockHash: log.blockHash!,
      logIndex: log.index,
      emitter: log.address,
      transactionHash: log.transactionHash!,
      blockNumber: log.blockNumber!,
    };
  }

  private generatePacketId(
    srcEid: number,
    dstEid: number,
    packetHeader: string,
    payloadHash: string
  ): string {
    return ethers.keccak256(
      ethers.AbiCoder.defaultAbiCoder().encode(
        ['uint32', 'uint32', 'bytes', 'bytes32'],
        [srcEid, dstEid, packetHeader, payloadHash]
      )
    );
  }

  async getBlockFinality(blockNumber: number): Promise<boolean> {
    const currentBlock = await this.provider.getBlockNumber();
    const confirmations = currentBlock - blockNumber;
    
    // Consider block finalized after 64 blocks (~14 minutes on ETH)
    return confirmations >= 64;
  }
}