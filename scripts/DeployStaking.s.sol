// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import "forge-std/Script.sol";
import "../src/StakingStorage.sol";
import "../src/StakingVault.sol";
import "../src/Token.sol";

/**
 * @title DeployStaking
 * @notice Deployment script for the  Token staking system
 */
contract DeployStaking is Script {
    // Configuration - Replace with actual addresses
    address constant ADMIN = 0x1234567890123456789012345678901234567890;
    address constant MANAGER = 0x2345678901234567890123456789012345678901;
    address constant MULTISIG = 0x3456789012345678901234567890123456789012;

    // Optional: Use existing token address
    address constant EXISTING_TOKEN = address(0); // Set to deployed token address or leave as 0

    function run() external {
        vm.startBroadcast();

        address tokenAddress;

        // 1. Deploy or use existing token
        if (EXISTING_TOKEN == address(0)) {
            Token token = new Token();
            tokenAddress = address(token);
            console.log("Token deployed at:", tokenAddress);
        } else {
            tokenAddress = EXISTING_TOKEN;
            console.log("Using existing token at:", tokenAddress);
        }

        // 2. Deploy StakingStorage first
        StakingStorage stakingStorage = new StakingStorage(
            ADMIN,
            MANAGER,
            address(0) // Vault address will be set after vault deployment
        );
        console.log("StakingStorage deployed at:", address(stakingStorage));

        // 3. Deploy StakingVault
        StakingVault stakingVault = new StakingVault(
            IERC20(tokenAddress),
            address(stakingStorage),
            ADMIN,
            MANAGER,
            MULTISIG
        );
        console.log("StakingVault deployed at:", address(stakingVault));

        // 4. Grant CONTROLLER_ROLE to vault in storage contract
        bytes32 CONTROLLER_ROLE = keccak256("CONTROLLER_ROLE");
        stakingStorage.grantRole(CONTROLLER_ROLE, address(stakingVault));
        console.log("Granted CONTROLLER_ROLE to vault");

        vm.stopBroadcast();

        // Output deployment summary
        console.log("\n=== STAKING SYSTEM DEPLOYMENT SUMMARY ===");
        console.log("Token:          ", tokenAddress);
        console.log("StakingStorage: ", address(stakingStorage));
        console.log("StakingVault:   ", address(stakingVault));
        console.log("Admin:          ", ADMIN);
        console.log("Manager:        ", MANAGER);
        console.log("Multisig:       ", MULTISIG);
        console.log("==========================================");

        console.log("\nNext steps:");
        console.log("1. Verify contracts on Etherscan");
        console.log(
            "2. Grant CLAIM_CONTRACT_ROLE to claiming contracts (if needed)"
        );
        console.log("3. Test basic functionality");
    }
}
