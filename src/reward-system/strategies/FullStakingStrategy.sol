// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "../../interfaces/reward/IRewardStrategy.sol";
import "../../interfaces/staking/IStakingStorage.sol";

/**
 * @title FullStakingStrategy
 * @author @Tudmotu
 * @notice A strategy that rewards stakers who keep their stake for the entire duration of a parent pool.
 * @dev This is an ADMIN_GRANTED strategy. It returns the stake amount as the weight for final calculation.
 */
contract FullStakingStrategy is IRewardStrategy {
    address public immutable rewardToken;
    uint16 public immutable gracePeriod; // Grace period in days.

    error MethodNotSupported();

    constructor(address _rewardToken, uint16 _gracePeriod) {
        rewardToken = _rewardToken;
        gracePeriod = _gracePeriod;
    }

    function getName() external pure override returns (string memory) {
        return "Full Staking Strategy";
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
    ) external view returns (uint256) {
        if (totalPoolWeight == 0) {
            return 0;
        }

        // Eligibility check:
        // 1. Staked within grace period.
        // 2. Held until (or past) the pool end day.
        bool isEligible = stake.stakeDay <= (poolStartDay + gracePeriod) &&
            (stake.unstakeDay == 0 || stake.unstakeDay > poolEndDay);

        if (!isEligible) {
            return 0;
        }

        uint256 userWeight = stake.amount;

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
