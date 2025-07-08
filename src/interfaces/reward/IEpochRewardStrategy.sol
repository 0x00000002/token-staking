// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "./IBaseRewardStrategy.sol";

/**
 * @title IEpochRewardStrategy
 * @notice Interface for epoch-based reward strategies (fixed pool distribution)
 */
interface IEpochRewardStrategy is IBaseRewardStrategy {
    error EpochRewardCalculationFailed(
        address staker,
        bytes32 stakeId,
        uint32 epochId
    );
    error InvalidEpochId(uint32 epochId);
    error InvalidWeightParameters(uint256 userWeight, uint256 totalWeight);
    error ZeroPoolSize(uint32 epochId);
    error StakeNotActiveInEpoch(
        bytes32 stakeId,
        uint32 epochStart,
        uint32 epochEnd
    );

    /// @notice Get epoch duration in days
    function getEpochDuration() external view returns (uint32);

    /// @notice Calculate reward for a user in a specific epoch
    /// @param epochId The epoch identifier
    /// @param userStakeWeight User's total stake weight in the epoch
    /// @param totalStakeWeight Total stake weight of all participants
    /// @param poolSize Total reward pool size for the epoch
    /// @return reward The calculated reward amount
    function calculateEpochReward(
        uint32 epochId,
        uint256 userStakeWeight,
        uint256 totalStakeWeight,
        uint256 poolSize
    ) external pure returns (uint256 reward);

    /// @notice Validate if a stake participated in an epoch
    /// @param stakeId The stake identifier
    /// @param epochStartDay Epoch start day
    /// @param epochEndDay Epoch end day
    /// @return participated True if stake overlapped with epoch period
    function validateEpochParticipation(
        bytes32 stakeId,
        uint32 epochStartDay,
        uint32 epochEndDay
    ) external view returns (bool participated);
}
