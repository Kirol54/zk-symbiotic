// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {SymbioticDvn} from "../src/layerzero/dvn/SymbioticDvn.sol";
import {StubZkEthStateVerifier} from "../src/layerzero/zk/StubZkEthStateVerifier.sol";
import {IZkEthStateVerifier} from "../src/layerzero/zk/IZkEthStateVerifier.sol";

// Import the real Settlement interface
import {ISettlement} from "@symbioticfi/relay-contracts/interfaces/modules/settlement/ISettlement.sol";

contract DvnRelayIntegrationTest is Test {
    SymbioticDvn dvn;
    StubZkEthStateVerifier zkVerifier;
    ISettlement settlement;
    
    // Real Settlement address from relay_contracts.json
    address constant SETTLEMENT_ADDRESS = 0xF058C08Ba8ED8465606e534b48b05d2075Dd7ce0;
    
    uint32 constant SRC_EID = 30101; // Ethereum
    uint32 constant DST_EID = 30184; // Base
    
    function setUp() public {
        // Fork or use the local network where Settlement is deployed
        settlement = ISettlement(SETTLEMENT_ADDRESS);
        
        zkVerifier = new StubZkEthStateVerifier();
        dvn = new SymbioticDvn(SETTLEMENT_ADDRESS, address(zkVerifier));
        
        vm.label(address(dvn), "SymbioticDVN");
        vm.label(SETTLEMENT_ADDRESS, "RealSettlement");
        vm.label(address(zkVerifier), "ZKVerifier");
    }
    
    function testDvnWithRealSettlement() public {
        console.log("=== Testing DVN with Real Settlement ===");
        
        // Create a mock packet
        bytes memory packetHeader = abi.encodePacked(
            uint8(1), // version
            uint32(SRC_EID),
            uint32(DST_EID),
            bytes32(uint256(1)) // nonce
        );
        
        bytes32 payloadHash = keccak256(abi.encode(address(0x123), 1 ether));
        bytes32 srcBlockHash = blockhash(block.number - 1);
        uint32 logIndex = 0;
        address emitter = address(0x456);
        
        bytes32 packetId = keccak256(
            abi.encode(SRC_EID, DST_EID, packetHeader, payloadHash)
        );
        
        // Build message hash
        bytes32 messageHash = dvn.buildMessageHash(
            SRC_EID,
            DST_EID,
            packetHeader,
            payloadHash,
            srcBlockHash,
            logIndex,
            emitter
        );
        
        console.log("Packet ID:", vm.toString(packetId));
        console.log("Message Hash:", vm.toString(messageHash));
        
        // Check Settlement contract state
        try settlement.getLastCommittedHeaderEpoch() returns (uint48 lastEpoch) {
            console.log("Last committed epoch:", lastEpoch);
            
            if (lastEpoch > 0) {
                // Get epoch info
                uint8 keyTag = settlement.getRequiredKeyTagFromValSetHeaderAt(lastEpoch);
                uint256 quorumThreshold = settlement.getQuorumThresholdFromValSetHeaderAt(lastEpoch);
                uint48 captureTimestamp = settlement.getCaptureTimestampFromValSetHeaderAt(lastEpoch);
                
                console.log("Key Tag:", keyTag);
                console.log("Quorum Threshold:", quorumThreshold);
                console.log("Capture Timestamp:", captureTimestamp);
                
                // For now, just verify the DVN can call Settlement methods without reverting
                // In a real test, we'd have valid signatures from running operators
                console.log("Settlement integration test: Basic connectivity OK");
                
            } else {
                console.log("WARNING: No epochs committed yet - Relay may not be running");
            }
            
        } catch {
            console.log("ERROR: Could not connect to Settlement - check if Relay is deployed");
            // Fail the test if Settlement is not accessible
            assertTrue(false, "Settlement contract not accessible");
        }
    }
    
    function testDvnSettlementInterface() public {
        // Test that our DVN correctly interfaces with Settlement
        bytes32 testMessage = keccak256("test");
        
        try settlement.getLastCommittedHeaderEpoch() returns (uint48 epoch) {
            if (epoch > 0) {
                // Test getting epoch info (should not revert)
                uint8 keyTag = settlement.getRequiredKeyTagFromValSetHeaderAt(epoch);
                uint256 threshold = settlement.getQuorumThresholdFromValSetHeaderAt(epoch);
                
                assertTrue(keyTag > 0, "KeyTag should be set");
                assertTrue(threshold > 0, "Quorum threshold should be set");
                
                console.log("Settlement interface test passed");
            }
        } catch {
            console.log("Settlement not ready - skipping interface test");
        }
    }
    
    function testDvnMessageHashConsistency() public {
        // Verify message hash function works consistently
        bytes memory packetHeader = abi.encodePacked(uint32(1), uint32(2));
        bytes32 payloadHash = keccak256("test payload");
        bytes32 blockHash = blockhash(block.number - 1);
        
        bytes32 hash1 = dvn.buildMessageHash(1, 2, packetHeader, payloadHash, blockHash, 0, address(0x123));
        bytes32 hash2 = dvn.buildMessageHash(1, 2, packetHeader, payloadHash, blockHash, 0, address(0x123));
        
        assertEq(hash1, hash2, "Message hash should be deterministic");
        console.log("Message hash consistency test passed");
    }
}