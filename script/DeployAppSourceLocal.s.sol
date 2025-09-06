// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Script.sol";
import "../src/layerzero/app/AppSource.sol";

contract DeployAppSourceLocal is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // LayerZero V2 Endpoint on local Anvil (31337)
        address endpoint = 0x1a44076050125825900e736c501f859c50fE728c;
        
        AppSource appSource = new AppSource(endpoint);
        
        console.log("AppSource deployed on LOCAL to:", address(appSource));
        console.log("Endpoint used:", endpoint);
        
        vm.stopBroadcast();
    }
}