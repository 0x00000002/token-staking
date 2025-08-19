// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import "forge-std/Script.sol";
import "../src/StakingStorage.sol";

/**
 * @title DeployStorage
 * @notice Deployment script for the StakingStorage contract
 */
contract DeployStorage is Script {
    bool isMainnet = vm.envBool("IS_MAINNET");

    // Configuration
    uint256 deployerPk;
    address public ADMIN;
    address public MANAGER;
    address public VAULT_ADDRESS; // This will be set manually after vault deployment

    function run() external {
        if (isMainnet) {
            deployerPk = vm.envUint("MAIN_DEPLOYER_PRIVATE_KEY");
            ADMIN = vm.envAddress("MAIN_ADMIN");
            MANAGER = vm.envAddress("MAIN_MANAGER");
            VAULT_ADDRESS = vm.envAddress("MAIN_VAULT_ADDRESS");
        } else {
            deployerPk = vm.envUint("DEV_DEPLOYER_PRIVATE_KEY");
            ADMIN = vm.envAddress("DEV_ADMIN");
            MANAGER = vm.envAddress("DEV_MANAGER");
            VAULT_ADDRESS = vm.envAddress("DEV_VAULT_ADDRESS"); // Should be 0 initially if vault is not deployed
        }

        vm.startBroadcast(deployerPk);

        // Deploy StakingStorage
        StakingStorage stakingStorage = new StakingStorage(
            ADMIN,
            MANAGER,
            VAULT_ADDRESS // Initially address(0) if vault is deployed later
        );
        console.log("StakingStorage deployed at:", address(stakingStorage));

        vm.stopBroadcast();

        console.log("\n=== STORAGE DEPLOYMENT SUMMARY ===");
        console.log("StakingStorage: ", address(stakingStorage));
        console.log("Admin:          ", ADMIN);
        console.log("Manager:        ", MANAGER);
        console.log("Vault Address:  ", VAULT_ADDRESS);
        console.log("===================================");
    }
}
