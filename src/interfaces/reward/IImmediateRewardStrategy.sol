// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "./IBaseRewardStrategy.sol";

/**
 * @title IImmediateRewardStrategy
 * @notice Interface for immediate reward strategies (APR-style)
 */
interface IImmediateRewardStrategy is IBaseRewardStrategy {
    error HistoricalRewardCalculationFailed(
        address staker,
        bytes32 stakeId,
        uint32 fromDay,
        uint32 toDay
    );
    error InvalidTimeRange(uint32 fromDay, uint32 toDay);
    error StakeNotFound(address staker, bytes32 stakeId);
    error StakeNotApplicable(address staker, bytes32 stakeId);

    /// @notice Calculate historical reward for a stake over a time period
    /// @param stakeId The stake identifier
    /// @param fromDay Start day for calculation (inclusive)
    /// @param toDay End day for calculation (exclusive)
    /// @return reward The calculated reward amount
    function calculateHistoricalReward(
        bytes32 stakeId,
        uint32 fromDay,
        uint32 toDay
    ) external view returns (uint256 reward);
}
