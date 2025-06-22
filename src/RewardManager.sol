// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./interfaces/IRewardManager.sol";
import "./interfaces/IRewardStrategy.sol";
import "./interfaces/IStakingStorage.sol";

import "./strategies/StrategiesRegistry.sol";

contract RewardManager is IRewardManager, AccessControl {
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    bytes32 public constant CONTROLLER_ROLE = keccak256("CONTROLLER_ROLE");

    StrategiesRegistry public strategyRegistry;
    IStakingStorage public stakingStorage;

    address public controller;
    address public manager;
    address public admin;

    event ControllerSet(address indexed controller);

    constructor(address _admin, address _manager) {
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(MANAGER_ROLE, _manager);
        admin = _admin;
        manager = _manager;
    }

    function calculateStakeReward(
        address staker,
        uint256 stakeId
    ) external view returns (uint256) {
        // Basic implementation - return 0 for now
        return 0;
    }

    // Calculate rewards for multiple stakes
    function calculateReward(
        address staker,
        bytes32 stakeId
    ) external view returns (uint256 totalReward) {
        uint256[] memory activeStrategyIds = strategyRegistry
            .getActiveStrategies();
        require(activeStrategyIds.length > 0, "No active strategy");

        for (uint256 i = 0; i < activeStrategyIds.length; i++) {
            address strategyAddress = strategyRegistry.strategies(
                activeStrategyIds[i]
            );
            uint256 reward = IRewardStrategy(strategyAddress).calculateReward(
                staker,
                stakeId
            );
            totalReward += reward;
        }
    }

    // Preview total rewards across all stakes
    function previewReward(address staker) external view returns (uint256) {
        // Basic implementation - return 0 for now
        return 0;
    }

    function claimAllRewards() external override returns (uint256) {
        // Basic implementation - return 0 for now
        return 0;
    }

    function claimRewards(
        bytes32[] calldata stakeIds
    ) external override returns (uint256) {
        // Basic implementation - return 0 for now
        return 0;
    }

    function claimStakeReward(
        bytes32 stakeId
    ) external override returns (uint256) {
        // Basic implementation - return 0 for now
        return 0;
    }

    function getClaimableReward(
        address staker
    ) external view override returns (uint256) {
        // Basic implementation - return 0 for now
        return 0;
    }

    function getStakeClaimableReward(
        address staker,
        bytes32 stakeId
    ) external view override returns (uint256) {
        // Basic implementation - return 0 for now
        return 0;
    }

    function getStakesClaimableRewards(
        address staker,
        bytes32[] calldata stakeIds
    ) external view override returns (uint256[] memory, uint256 total) {
        uint256[] memory rewards = new uint256[](stakeIds.length);
        for (uint256 i = 0; i < stakeIds.length; i++) {
            rewards[i] = 0; // Basic implementation - return 0 for now
            total += rewards[i];
        }
        return (rewards, total);
    }

    function addRewardFunds(uint256 amount) external override {
        // Basic implementation - no-op for now
    }

    function withdrawRewardFunds(uint256 amount) external override {
        // Basic implementation - no-op for now
    }

    function setRewardCalculator(address calculatorAddress) external override {
        // Basic implementation - no-op for now
    }
}
