use alloy::sol;

sol!(
    // SPDX-License-Identifier: MIT
    pragma solidity ^0.8.25;

    interface IEndpointV2 {
        function send(
            uint32 dstEid,
            bytes calldata receiver,
            bytes calldata message,
            bytes calldata options
        ) external payable returns (bytes32 guid);
    }

    contract AppSource {
        event ETHDeposited(address indexed user, uint256 amount, bytes32 guid);

        IEndpointV2 public immutable endpoint;
        uint256 public totalLocked;
        mapping(address => uint256) public lockedTokens; // address => amount

        event TokensLocked(address indexed user, uint256 amount, uint256 when);

        constructor(address _endpoint) {
            endpoint = IEndpointV2(_endpoint);
        }

        function depositETH(
            uint32 dstEid, 
            bytes32 receiver, 
            bytes calldata options
        ) external payable returns (bytes32 guid) {
            require(msg.value > 0, "Amount must be greater than 0");
            
            totalLocked += msg.value;
            
            bytes memory payload = abi.encode(msg.sender, msg.value);
            
            guid = endpoint.send{value: 0}(
                dstEid, 
                abi.encodePacked(receiver), 
                payload, 
                options
            );
            
            emit ETHDeposited(msg.sender, msg.value, guid);

            lockedTokens[msg.sender] += msg.value;
            emit TokensLocked(msg.sender, msg.value, block.timestamp);
        }

        function getTLockedBalance() external view returns (uint256) {
            return address(this).balance;
        }

        // get locked tokens for a user
        function getUserLockedTokens(address user) external view returns (uint256) {
            return lockedTokens[user];
        }
    }

);

// AppSource::TokensLocked