// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./interfaces/IRewardCalculator.sol";
import "./interfaces/IRewardStrategy.sol";
import "./interfaces/IStakingStorage.sol";

import "./RewardStrategyRegistry.sol";

contract RewardManager is IRewardCalculator, AccessControl {
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    bytes32 public constant CONTROLLER_ROLE = keccak256("CONTROLLER_ROLE");

    RewardStrategyRegistry public strategyRegistry;
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
    ) external view returns (uint256) {}

    // Calculate rewards for multiple stakes
    function calculateReward(
        address staker,
        uint256 stakeId
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
    function previewReward(address staker) external view returns (uint256) {}
}
