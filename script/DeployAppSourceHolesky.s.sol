// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "forge-std/Script.sol";
import "../src/layerzero/app/AppSource.sol";

contract DeployAppSourceHolesky is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);
        
        // LayerZero V2 Endpoint on Holesky testnet
        address endpoint = 0x6EDCE65403992e310A62460808c4b910D972f10f;
        
        AppSource appSource = new AppSource(endpoint);
        
        console.log("AppSource deployed on HOLESKY to:", address(appSource));
        console.log("Endpoint used:", endpoint);
        
        vm.stopBroadcast();
    }
}