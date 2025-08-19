// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "../../interfaces/reward/IRewardStrategy.sol";
import "../../interfaces/staking/IStakingStorage.sol";

/**
 * @title StandardStakingStrategy
 * @author @Tudmotu
 * @notice A strategy for calculating rewards for standard, cyclical pools.
 * @dev This is an ADMIN_GRANTED strategy. Rewards are calculated based on stake weight and duration within the pool.
 */
contract StandardStakingStrategy is IRewardStrategy {
    address public immutable rewardToken;
    bool public immutable isReStakingAllowed;

    error MethodNotSupported();

    constructor(address _rewardToken, bool _isReStakingAllowed) {
        rewardToken = _rewardToken;
        isReStakingAllowed = _isReStakingAllowed;
    }

    function getName() external pure override returns (string memory) {
        return "Standard Staking Strategy";
    }

    function getRewardToken() external view override returns (address) {
        return rewardToken;
    }

    function getRewardLayer() external pure override returns (uint8) {
        return 0; // Base Layer
    }

    function getStrategyType() external pure override returns (StrategyType) {
        return StrategyType.POOL_SIZE_DEPENDENT;
    }

    function calculateReward(
        address, // user
        IStakingStorage.Stake calldata stake,
        uint256 totalPoolWeight,
        uint256 totalRewardAmount,
        uint16 poolStartDay,
        uint16 poolEndDay
    ) external pure returns (uint256) {
        if (totalPoolWeight == 0) {
            return 0;
        }

        // Step 1: Calculate user's weight (as before).
        if (
            stake.stakeDay > poolEndDay ||
            (stake.unstakeDay != 0 && stake.unstakeDay < poolEndDay)
        ) {
            return 0;
        }
        uint256 effectiveStart = stake.stakeDay > poolStartDay
            ? stake.stakeDay
            : poolStartDay;
        uint256 effectiveDays = poolEndDay - effectiveStart;
        uint256 userWeight = stake.amount * effectiveDays;

        // Step 2: Calculate and return the final reward.
        return (userWeight * totalRewardAmount) / totalPoolWeight;
    }

    function calculateReward(
        address, // user
        IStakingStorage.Stake calldata, // stake
        uint16, // lastClaimDay
        uint16, // poolStartDay
        uint16 // poolEndDay
    ) external pure returns (uint256) {
        revert("MethodNotSupported");
    }
}
