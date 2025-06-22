// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import "forge-std/Script.sol";
import "../src/StakingStorage.sol";
import "../src/StakingVault.sol";

/**
 * @title DeployWithExistingToken
 * @notice Deployment script for existing token deployments (like staking token)
 */
contract DeployWithExistingToken is Script {
    function run() external {
        // Read from environment variables
        address admin = vm.envAddress("ADMIN");
        address manager = vm.envAddress("MANAGER");
        address multisig = vm.envAddress("MULTISIG");
        address token = vm.envAddress("TOKEN");

        require(admin != address(0), "ADMIN not set");
        require(manager != address(0), "MANAGER not set");
        require(multisig != address(0), "MULTISIG not set");
        require(token != address(0), "TOKEN not set");

        vm.startBroadcast();

        console.log("Deploying with configuration:");
        console.log("Admin:    ", admin);
        console.log("Manager:  ", manager);
        console.log("Multisig: ", multisig);
        console.log("Token:    ", token);

        // 1. Deploy StakingStorage
        StakingStorage stakingStorage = new StakingStorage(
            admin,
            manager,
            address(0) // Vault address will be set after vault deployment
        );
        console.log("StakingStorage deployed at:", address(stakingStorage));

        // 2. Deploy StakingVault
        StakingVault stakingVault = new StakingVault(
            IERC20(token),
            address(stakingStorage),
            admin,
            manager,
            multisig
        );
        console.log("StakingVault deployed at:", address(stakingVault));

        // 3. Grant CONTROLLER_ROLE to vault
        bytes32 CONTROLLER_ROLE = keccak256("CONTROLLER_ROLE");
        stakingStorage.grantRole(CONTROLLER_ROLE, address(stakingVault));
        console.log("Granted CONTROLLER_ROLE to vault");

        vm.stopBroadcast();

        // Output for verification commands
        console.log("\n=== VERIFICATION COMMANDS ===");
        console.log("Export deployed addresses:");
        console.log("export STAKING_STORAGE=", address(stakingStorage));
        console.log("export STAKING_VAULT=", address(stakingVault));

        console.log("\nStakingStorage verification:");
        console.log("forge verify-contract $STAKING_STORAGE \\");
        console.log("  src/StakingStorage.sol:StakingStorage \\");
        console.log("  --chain sepolia \\");
        console.log("  --compiler-version v0.8.30 \\");
        console.log("  --num-of-optimizations 200 \\");
        console.log("  --etherscan-api-key $ETHERSCAN_API_KEY \\");
        console.log(
            '  --constructor-args $(cast abi-encode "constructor(address,address,address)" ',
            admin,
            " ",
            manager,
            " ",
            address(stakingVault),
            ")"
        );

        console.log("\nStakingVault verification:");
        console.log("forge verify-contract $STAKING_VAULT \\");
        console.log("  src/StakingVault.sol:StakingVault \\");
        console.log("  --chain sepolia \\");
        console.log("  --compiler-version v0.8.30 \\");
        console.log("  --num-of-optimizations 200 \\");
        console.log("  --etherscan-api-key $ETHERSCAN_API_KEY \\");
        console.log(
            '  --constructor-args $(cast abi-encode "constructor(address,address,address,address,address)" ',
            token,
            " ",
            address(stakingStorage),
            " ",
            admin,
            " ",
            manager,
            " ",
            multisig,
            ")"
        );
    }
}
