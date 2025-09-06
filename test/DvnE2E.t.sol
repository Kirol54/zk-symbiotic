// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {SymbioticDvn} from "../src/layerzero/dvn/SymbioticDvn.sol";
import {ILayerZeroDVN} from "../src/layerzero/dvn/interfaces/ILayerZeroDVN.sol";
import {StubZkEthStateVerifier} from "../src/layerzero/zk/StubZkEthStateVerifier.sol";
import {IZkEthStateVerifier} from "../src/layerzero/zk/IZkEthStateVerifier.sol";
import {BETH} from "../src/layerzero/app/BETH.sol";
import {AppSource} from "../src/layerzero/app/AppSource.sol";
import {AppDest} from "../src/layerzero/app/AppDest.sol";
import {SettlementMock} from "./mock/SettlementMock.sol";

contract DvnE2ETest is Test {
    SymbioticDvn dvn;
    StubZkEthStateVerifier zkVerifier;
    SettlementMock settlement;
    BETH bETH;
    AppSource appSource;
    AppDest appDest;
    
    address mockEndpoint = address(0x123);
    address user = address(0x456);
    address worker = address(0x789);
    
    uint32 constant SRC_EID = 30101; // Ethereum
    uint32 constant DST_EID = 30184; // Base
    
    function setUp() public {
        // Deploy contracts
        settlement = new SettlementMock();
        zkVerifier = new StubZkEthStateVerifier();
        dvn = new SymbioticDvn(address(settlement), address(zkVerifier));
        
        bETH = new BETH(address(this));
        appSource = new AppSource(mockEndpoint);
        appDest = new AppDest(mockEndpoint, address(bETH));
        
        // Transfer bETH ownership to AppDest
        bETH.transferOwnership(address(appDest));
        
        // Set up mock settlement to return true for signature verification
        settlement.setVerificationResult(true);
        
        vm.label(address(dvn), "SymbioticDVN");
        vm.label(address(settlement), "Settlement");
        vm.label(address(zkVerifier), "ZKVerifier");
        vm.label(user, "User");
        vm.label(worker, "Worker");
    }
    
    function testDvnEndToEnd() public {
        console.log("=== DVN End-to-End Test ===");
        
        // 1. Create a mock packet
        bytes memory packetHeader = abi.encodePacked(
            uint8(1), // version
            uint32(SRC_EID),
            uint32(DST_EID),
            bytes32(uint256(1)) // nonce
        );
        
        bytes32 payloadHash = keccak256(abi.encode(user, 1 ether));
        bytes32 srcBlockHash = blockhash(block.number - 1);
        uint32 logIndex = 0;
        address emitter = mockEndpoint;
        
        bytes32 packetId = keccak256(
            abi.encode(SRC_EID, DST_EID, packetHeader, payloadHash)
        );
        
        console.log("Packet ID:", vm.toString(packetId));
        
        // 2. Build message hash that DVN expects
        bytes32 messageHash = dvn.buildMessageHash(
            SRC_EID,
            DST_EID,
            packetHeader,
            payloadHash,
            srcBlockHash,
            logIndex,
            emitter
        );
        
        console.log("Message Hash:", vm.toString(messageHash));
        
        // 3. Create mock relay proof and ZK inputs
        bytes memory relayProof = new bytes(96); // Mock BLS signature
        uint48 epoch = 1;
        
        bytes memory zkProof = new bytes(128); // Mock proof
        IZkEthStateVerifier.Inputs memory zkInputs = IZkEthStateVerifier.Inputs({
            slot: 1000,
            blockHash: srcBlockHash,
            receiptsRoot: bytes32(uint256(0x456)),
            emitter: emitter,
            topicsHash: keccak256(abi.encodePacked("PacketSent")),
            logIndex: logIndex,
            minFinality: 64
        });
        
        // 4. Verify packet is not yet verified
        assertFalse(dvn.verified(packetId), "Packet should not be verified initially");
        
        // 5. Submit verification as worker
        vm.prank(worker);
        vm.expectEmit(true, true, false, true);
        emit SymbioticDvn.Verified(packetId, messageHash);
        
        dvn.submitVerification(
            packetId,
            messageHash,
            epoch,
            relayProof,
            zkProof,
            zkInputs
        );
        
        // 6. Verify packet is now verified
        assertTrue(dvn.verified(packetId), "Packet should be verified");
        
        console.log("[SUCCESS] DVN verification successful");
    }
    
    function testDvnRejectsInvalidQuorum() public {
        bytes32 packetId = bytes32(uint256(1));
        bytes32 messageHash = bytes32(uint256(2));
        
        // Set settlement to return false for signature verification
        settlement.setVerificationResult(false);
        
        bytes memory relayProof = new bytes(96);
        bytes memory zkProof = new bytes(128);
        IZkEthStateVerifier.Inputs memory zkInputs;
        
        vm.expectRevert(SymbioticDvn.NoQuorum.selector);
        dvn.submitVerification(packetId, messageHash, 1, relayProof, zkProof, zkInputs);
    }
    
    function testDvnRejectsDoubleVerification() public {
        bytes32 packetId = bytes32(uint256(1));
        bytes32 messageHash = bytes32(uint256(2));
        
        bytes memory relayProof = new bytes(96);
        bytes memory zkProof = new bytes(128);
        IZkEthStateVerifier.Inputs memory zkInputs;
        
        // First verification should succeed
        dvn.submitVerification(packetId, messageHash, 1, relayProof, zkProof, zkInputs);
        
        // Second verification should fail
        vm.expectRevert(SymbioticDvn.AlreadyVerified.selector);
        dvn.submitVerification(packetId, messageHash, 1, relayProof, zkProof, zkInputs);
    }
    
    function testAppFlow() public {
        console.log("=== App Flow Test ===");
        
        // Mock LayerZero endpoint behavior
        vm.mockCall(
            mockEndpoint,
            abi.encodeWithSignature(
                "send(uint32,bytes,bytes,bytes)",
                DST_EID,
                abi.encodePacked(bytes32(uint256(uint160(address(appDest))))),
                abi.encode(user, 1 ether),
                ""
            ),
            abi.encode(bytes32(uint256(0x123))) // Mock GUID
        );
        
        // 1. User deposits ETH on source chain
        uint256 initialBalance = user.balance;
        vm.deal(user, 1 ether);
        
        vm.prank(user);
        bytes32 guid = appSource.depositETH{value: 1 ether}(
            DST_EID,
            bytes32(uint256(uint160(address(appDest)))),
            ""
        );
        
        console.log("Deposit GUID:", vm.toString(guid));
        assertEq(appSource.getTLockedBalance(), 1 ether, "ETH should be locked in source");
        
        // 2. Simulate message delivery on destination chain
        vm.prank(mockEndpoint);
        appDest.onLzReceive(abi.encode(user, 1 ether));
        
        // 3. Verify bETH was minted
        assertEq(bETH.balanceOf(user), 1 ether, "bETH should be minted to user");
        
        console.log("[SUCCESS] App flow successful");
    }
    
    function testDvnFeeHandling() public {
        // Test fee estimation
        uint256 fee = dvn.getFee(DST_EID, 64, user, "");
        assertEq(fee, 0, "Fee should be 0 in stub implementation");
        
        // Test job assignment with fee
        ILayerZeroDVN.AssignJobParam memory param = ILayerZeroDVN.AssignJobParam({
            dstEid: DST_EID,
            packetHeader: abi.encodePacked(uint256(1)),
            payloadHash: bytes32(uint256(2)),
            confirmations: 64,
            sender: user
        });
        
        uint256 paidFee = dvn.assignJob{value: 0.1 ether}(param, "");
        assertEq(paidFee, 0.1 ether, "Should return paid fee amount");
    }
}