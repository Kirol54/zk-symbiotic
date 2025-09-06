export interface PacketSentEvent {
  packetId: string;
  srcEid: number;
  dstEid: number;
  packetHeader: string;
  payloadHash: string;
  blockHash: string;
  logIndex: number;
  emitter: string;
  transactionHash: string;
  blockNumber: number;
}

export interface ZkInputs {
  slot: bigint;
  blockHash: string;
  receiptsRoot: string;
  emitter: string;
  topicsHash: string;
  logIndex: number;
  minFinality: bigint;
}

export interface VerificationRequest {
  packetId: string;
  messageHash: string;
  epoch: number;
  relayProof: string;
  zkProof: string;
  zkInputs: ZkInputs;
}

export interface Config {
  ethRpcUrl: string;
  destRpcUrl: string;
  relayAggregatorUrl: string;
  dvnAddress: string;
  settlementAddress: string;
  layerzeroEndpointEth: string;
  layerzeroEndpointDest: string;
  appSourceAddress: string;
  appDestAddress: string;
  confirmations: number;
  privateKey: string;
  golemDbUrl?: string;
}