// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

contract MockEndpoint {
    event PacketSent(
        bytes encodedPacket,
        bytes options,
        address sendLibrary
    );

    function send(
        uint32 dstEid,
        bytes calldata receiver,
        bytes calldata message,
        bytes calldata options
    ) external payable returns (bytes32 guid) {
        // Generate a mock GUID
        guid = keccak256(abi.encodePacked(block.timestamp, msg.sender, dstEid, receiver, message));
        
        // Emit mock event for testing
        bytes memory encodedPacket = abi.encodePacked(dstEid, receiver, message);
        emit PacketSent(encodedPacket, options, address(this));
        
        return guid;
    }
    
    // Mock function to check if the endpoint is working
    function version() external pure returns (string memory) {
        return "MockEndpoint-v1.0.0";
    }
}
