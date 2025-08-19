// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

import {IStakingStorage} from "../src/interfaces/staking/IStakingStorage.sol";
import {PoolManager} from "../src/reward-system/PoolManager.sol";
import {StrategiesRegistry} from "../src/reward-system/StrategiesRegistry.sol";
import {RewardManager} from "../src/reward-system/RewardManager.sol";
import {ClaimsJournal} from "../src/reward-system/ClaimsJournal.sol";

contract DeployRewardSystem is Script {
    // --- Hardcoded Addresses ---
    address constant STAKING_STORAGE_ADDRESS =
        0xA71dF04aAC1DC6a0E62bC5a396ECaa976fF29f5A;
    // 0xfaa8a501cf7ffd8080b0864f2c959e8cbcf83030;

    // --- Roles ---
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    bytes32 public constant CONTROLLER_ROLE = keccak256("CONTROLLER_ROLE");
    bytes32 public constant REWARD_MANAGER_ROLE =
        keccak256("REWARD_MANAGER_ROLE");

    function run()
        external
        returns (PoolManager, StrategiesRegistry, RewardManager, ClaimsJournal)
    {
        // --- Read environment variables ---
        uint256 deployerPk = vm.envUint("DEPLOYER_PK");
        uint256 adminPk = vm.envUint("ADMIN_PK");
        address admin = vm.envAddress("ADMIN");
        address manager = vm.envAddress("MANAGER");
        address controller = vm.envAddress("CONTROLLER"); // For PoolManager

        if (
            admin == address(0) ||
            manager == address(0) ||
            controller == address(0)
        ) {
            console.log(
                "Error: ADMIN, MANAGER, CONTROLLERmust be set in your environment."
            );
            revert("Missing environment variables");
        }

        vm.startBroadcast(deployerPk);

        // --- 1. Deploy independent reward contracts ---
        console.log("Deploying PoolManager...");
        PoolManager poolManager = new PoolManager(admin, manager, controller);
        console.log("PoolManager deployed at:", address(poolManager));

        console.log("Deploying StrategiesRegistry...");
        StrategiesRegistry strategiesRegistry = new StrategiesRegistry(
            admin,
            manager
        );
        console.log(
            "StrategiesRegistry deployed at:",
            address(strategiesRegistry)
        );

        IStakingStorage stakingStorage = IStakingStorage(
            STAKING_STORAGE_ADDRESS
        );

        // --- 2. Deploy contracts with circular dependency ---

        console.log("Deploying ClaimsJournal...");
        ClaimsJournal claimsJournal = new ClaimsJournal(admin);
        console.log("ClaimsJournal deployed at:", address(claimsJournal));

        console.log("Deploying RewardManager (ClaimsJournal)...");
        RewardManager rewardManager = new RewardManager(
            admin,
            manager,
            stakingStorage,
            strategiesRegistry,
            claimsJournal,
            poolManager
        );
        console.log("RewardManager deployed at:", address(rewardManager));

        // --- 3. Finalize dependency connection ---
        console.log("Setting real ClaimsJournal address in RewardManager...");
        vm.stopBroadcast();

        vm.startBroadcast(adminPk);
        rewardManager.setClaimsJournal(ClaimsJournal(claimsJournal));

        // --- 4. Grant roles ---
        console.log(
            "Granting REWARD_MANAGER_ROLE to RewardManager in ClaimsJournal..."
        );
        claimsJournal.grantRole(REWARD_MANAGER_ROLE, address(rewardManager));

        console.log(
            "Granting CONTROLLER_ROLE to off-chain service in PoolManager..."
        );
        poolManager.grantRole(CONTROLLER_ROLE, controller);
        vm.stopBroadcast();

        // --- Verification logs ---
        console.log("\n--- Deployment Summary ---");
        console.log("PoolManager:        ", address(poolManager));
        console.log("StrategiesRegistry: ", address(strategiesRegistry));
        console.log("ClaimsJournal:      ", address(claimsJournal));
        console.log("RewardManager:      ", address(rewardManager));
        console.log("--- Roles Configuration ---");
        console.log(
            "ClaimsJournal's REWARD_MANAGER_ROLE granted to RewardManager:",
            claimsJournal.hasRole(REWARD_MANAGER_ROLE, address(rewardManager))
        );
        console.log(
            "PoolManager's CONTROLLER_ROLE granted to address",
            controller,
            ":",
            poolManager.hasRole(CONTROLLER_ROLE, controller)
        );
        console.log(
            "RewardManager's claimsJournal address set to:",
            address(rewardManager.claimsJournal())
        );

        return (poolManager, strategiesRegistry, rewardManager, claimsJournal);
    }
}
