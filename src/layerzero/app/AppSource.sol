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
        
        // Reserve some ETH for LayerZero gas fees (0.01 ETH = 1e16 wei)
        uint256 layerZeroFee = 1e16; // 0.01 ETH for cross-chain gas (increased for real LZ)
        require(msg.value > layerZeroFee, "Insufficient value for LayerZero fees");
        
        uint256 depositAmount = msg.value - layerZeroFee;
        totalLocked += depositAmount;
        
        bytes memory payload = abi.encode(msg.sender, depositAmount);
        
        guid = endpoint.send{value: layerZeroFee}(
            dstEid, 
            abi.encodePacked(receiver), 
            payload, 
            options
        );
        
        emit ETHDeposited(msg.sender, depositAmount, guid);

        lockedTokens[msg.sender] += depositAmount;
        emit TokensLocked(msg.sender, depositAmount, block.timestamp);
    }

    function getTLockedBalance() external view returns (uint256) {
        return address(this).balance;
    }

    // get locked tokens for a user
    function getUserLockedTokens(address user) external view returns (uint256) {
        return lockedTokens[user];
    }
}
