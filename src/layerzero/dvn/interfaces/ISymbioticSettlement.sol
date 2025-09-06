// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

interface ISymbioticSettlement {
    function verifyQuorumSigAt(
        bytes calldata message,
        bytes32 requiredKeyTag,
        uint256 quorumThreshold,
        bytes calldata signature,
        uint48 epoch,
        bytes calldata verifierProof
    ) external view returns (bool);

    function getRequiredKeyTagFromValSetHeaderAt(uint48 epoch) external view returns (bytes32);
    
    function getQuorumThresholdFromValSetHeaderAt(uint48 epoch) external view returns (uint256);
    
    function getCaptureTimestampFromValSetHeaderAt(uint48 epoch) external view returns (uint48);
}