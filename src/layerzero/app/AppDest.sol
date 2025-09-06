// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

interface IBETH {
    function mint(address to, uint256 amount) external;
}

contract AppDest {
    event BETHMinted(address indexed user, uint256 amount);

    address public immutable endpoint;
    IBETH public immutable bETH;

    modifier onlyEndpoint() {
        require(msg.sender == endpoint, "Only endpoint can call");
        _;
    }

    constructor(address _endpoint, address _bETH) {
        endpoint = _endpoint;
        bETH = IBETH(_bETH);
    }

    function onLzReceive(
        bytes calldata message
    ) external onlyEndpoint {
        (address user, uint256 amount) = abi.decode(message, (address, uint256));
        
        bETH.mint(user, amount);
        
        emit BETHMinted(user, amount);
    }
}