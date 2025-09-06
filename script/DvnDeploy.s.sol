// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {console} from "forge-std/console.sol";
import {Script} from "forge-std/Script.sol";

import {SymbioticDvn} from "../src/layerzero/dvn/SymbioticDvn.sol";
import {StubZkEthStateVerifier} from "../src/layerzero/zk/StubZkEthStateVerifier.sol";
import {BETH} from "../src/layerzero/app/BETH.sol";
import {AppSource} from "../src/layerzero/app/AppSource.sol";
import {AppDest} from "../src/layerzero/app/AppDest.sol";

contract DvnDeploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        address settlementAddress = vm.envAddress("SETTLEMENT_ADDRESS");
        address endpointV2Address = vm.envAddress("LAYERZERO_ENDPOINT_V2");
        
        vm.startBroadcast(deployerPrivateKey);

        StubZkEthStateVerifier zkVerifier = new StubZkEthStateVerifier();
        console.log("ZK Verifier deployed at:", address(zkVerifier));

        SymbioticDvn dvn = new SymbioticDvn(settlementAddress, address(zkVerifier));
        console.log("Symbiotic DVN deployed at:", address(dvn));

        BETH bETH = new BETH(deployer);
        console.log("BETH Token deployed at:", address(bETH));

        AppSource appSource = new AppSource(endpointV2Address);
        console.log("AppSource deployed at:", address(appSource));

        AppDest appDest = new AppDest(endpointV2Address, address(bETH));
        console.log("AppDest deployed at:", address(appDest));

        bETH.transferOwnership(address(appDest));
        console.log("BETH ownership transferred to AppDest");

        vm.stopBroadcast();

        console.log("\n=== Deployment Summary ===");
        console.log("ZK Verifier:", address(zkVerifier));
        console.log("DVN:", address(dvn));
        console.log("BETH Token:", address(bETH));
        console.log("AppSource:", address(appSource));
        console.log("AppDest:", address(appDest));
        console.log("Settlement:", settlementAddress);
        console.log("LayerZero Endpoint:", endpointV2Address);
    }
}