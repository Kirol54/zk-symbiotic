// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

interface IZkEthStateVerifier {
    struct Inputs {
        uint64 slot;          // finalized beacon slot
        bytes32 blockHash;    // ETH block containing the log
        bytes32 receiptsRoot; // receipts root of that block
        address emitter;      // LZ Endpoint/MessageLib address on ETH
        bytes32 topicsHash;   // keccak256(abi.encodePacked(topics))
        uint32 logIndex;      // index in the receipt
        uint64 minFinality;   // slots/confirmations threshold
    }
    
    function verifySourceEvent(bytes calldata proof, Inputs calldata publicInputs)
        external view returns (bool);
}