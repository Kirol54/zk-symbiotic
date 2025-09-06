// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {ILayerZeroDVN} from "./interfaces/ILayerZeroDVN.sol";
import {ISymbioticSettlement} from "./interfaces/ISymbioticSettlement.sol";
import {IZkEthStateVerifier} from "../zk/IZkEthStateVerifier.sol";

contract SymbioticDvn is ILayerZeroDVN {
    error AlreadyVerified();
    error NoQuorum();
    error NoZkFinality();
    error InvalidVerifyingEpoch();

    event Verified(bytes32 indexed packetId, bytes32 H);
    event Submitted(bytes32 indexed packetId);

    uint32 public constant VERIFICATION_EXPIRY = 12000; // seconds

    ISymbioticSettlement public immutable settlement;
    IZkEthStateVerifier public immutable zkVerifier;

    mapping(bytes32 => bool) public verified;

    constructor(address _settlement, address _zkVerifier) {
        settlement = ISymbioticSettlement(_settlement);
        zkVerifier = IZkEthStateVerifier(_zkVerifier);
    }

    function assignJob(AssignJobParam calldata, bytes calldata)
        external payable override returns (uint256 fee)
    {
        return msg.value;
    }

    function getFee(
        uint32, uint64, address, bytes calldata
    ) external pure override returns (uint256 fee) {
        return 0;
    }

    function submitVerification(
        bytes32 packetId,
        bytes32 H,
        uint48 epoch,
        bytes calldata relayProof,
        bytes calldata zkProof,
        IZkEthStateVerifier.Inputs calldata zkInputs
    ) external {
        if (verified[packetId]) {
            revert AlreadyVerified();
        }
        emit Submitted(packetId);

        uint48 nextEpochCaptureTimestamp = settlement.getCaptureTimestampFromValSetHeaderAt(epoch + 1);
        if (nextEpochCaptureTimestamp > 0 && block.timestamp >= nextEpochCaptureTimestamp + VERIFICATION_EXPIRY) {
            revert InvalidVerifyingEpoch();
        }

        bool quorumValid = settlement.verifyQuorumSigAt(
            abi.encode(H),
            settlement.getRequiredKeyTagFromValSetHeaderAt(epoch),
            settlement.getQuorumThresholdFromValSetHeaderAt(epoch),
            relayProof,
            epoch,
            new bytes(0)
        );

        if (!quorumValid) {
            revert NoQuorum();
        }

        if (!zkVerifier.verifySourceEvent(zkProof, zkInputs)) {
            revert NoZkFinality();
        }

        verified[packetId] = true;
        emit Verified(packetId, H);
    }

    function buildMessageHash(
        uint32 srcEid,
        uint32 dstEid,
        bytes calldata packetHeader,
        bytes32 payloadHash,
        bytes32 srcBlockHash,
        uint32 logIndex,
        address emitter
    ) external pure returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                "LZ_DVN_V1",
                srcEid,
                dstEid,
                packetHeader,
                payloadHash,
                srcBlockHash,
                logIndex,
                emitter
            )
        );
    }
}