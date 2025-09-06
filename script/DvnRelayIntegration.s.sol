// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {console} from "forge-std/console.sol";
import {Script} from "forge-std/Script.sol";

import {SymbioticDvn} from "../src/layerzero/dvn/SymbioticDvn.sol";
import {StubZkEthStateVerifier} from "../src/layerzero/zk/StubZkEthStateVerifier.sol";
import {BETH} from "../src/layerzero/app/BETH.sol";
import {AppSource} from "../src/layerzero/app/AppSource.sol";
import {AppDest} from "../src/layerzero/app/AppDest.sol";

contract DvnRelayIntegration is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        // Use real Settlement contract addresses from relay_contracts.json
        address settlementAddress = 0xF058C08Ba8ED8465606e534b48b05d2075Dd7ce0;
        
        // Mock LayerZero endpoint for local testing
        address endpointV2Address = vm.envOr("LAYERZERO_ENDPOINT_V2", address(0x1a44076050125825900e736c501f859c50fE728c));
        
        vm.startBroadcast(deployerPrivateKey);

        // Deploy ZK verifier (stub for Phase 0)
        StubZkEthStateVerifier zkVerifier = new StubZkEthStateVerifier();
        console.log("ZK Verifier deployed at:", address(zkVerifier));

        // Deploy DVN with real Settlement
        SymbioticDvn dvn = new SymbioticDvn(settlementAddress, address(zkVerifier));
        console.log("Symbiotic DVN deployed at:", address(dvn));
        console.log("Using Settlement at:", settlementAddress);

        // Deploy app contracts
        BETH bETH = new BETH(deployer);
        console.log("BETH Token deployed at:", address(bETH));

        AppSource appSource = new AppSource(endpointV2Address);
        console.log("AppSource deployed at:", address(appSource));

        AppDest appDest = new AppDest(endpointV2Address, address(bETH));
        console.log("AppDest deployed at:", address(appDest));

        // Transfer bETH ownership to AppDest
        bETH.transferOwnership(address(appDest));
        console.log("BETH ownership transferred to AppDest");

        vm.stopBroadcast();

        // Output configuration for DVN worker
        console.log("\n=== DVN Worker Configuration ===");
        console.log("DVN_ADDRESS=", address(dvn));
        console.log("SETTLEMENT_ADDRESS=", settlementAddress);
        console.log("ZK_VERIFIER_ADDRESS=", address(zkVerifier));
        console.log("BETH_TOKEN_ADDRESS=", address(bETH));
        console.log("APP_SOURCE_ADDRESS=", address(appSource));
        console.log("APP_DEST_ADDRESS=", address(appDest));
        console.log("LAYERZERO_ENDPOINT_V2=", endpointV2Address);
        
        console.log("\n=== Next Steps ===");
        console.log("1. Ensure Relay sidecars are running (Aggregator on :8082)");
        console.log("2. Update DVN worker .env with above addresses");
        console.log("3. Test with: cast send AppSource 'depositETH(uint32,bytes32,bytes)'");
    }
}