import { ethers } from 'ethers';

export function buildMessageHash(
  srcEid: number,
  dstEid: number,
  packetHeader: string,
  payloadHash: string,
  srcBlockHash: string,
  logIndex: number,
  emitter: string
): string {
  return ethers.keccak256(
    ethers.solidityPacked(
      ['string', 'uint32', 'uint32', 'bytes', 'bytes32', 'bytes32', 'uint32', 'address'],
      ['LZ_DVN_V1', srcEid, dstEid, packetHeader, payloadHash, srcBlockHash, logIndex, emitter]
    )
  );
}

export function generatePacketId(
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