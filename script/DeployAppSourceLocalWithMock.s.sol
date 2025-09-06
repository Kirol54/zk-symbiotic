// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Script.sol";
import "../src/layerzero/app/AppSource.sol";
import "../src/layerzero/app/MockEndpoint.sol";

contract DeployAppSourceLocalWithMock is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Deploy mock LayerZero endpoint for local testing
        MockEndpoint mockEndpoint = new MockEndpoint();
        console.log("Mock Endpoint deployed at:", address(mockEndpoint));
        
        AppSource appSource = new AppSource(address(mockEndpoint));
        
        console.log("AppSource deployed on LOCAL to:", address(appSource));
        console.log("Mock Endpoint used:", address(mockEndpoint));
        
        vm.stopBroadcast();
    }
}
