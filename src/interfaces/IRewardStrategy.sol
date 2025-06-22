// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

/**
 * @title IRewardStrategy
 * @notice Interface for reward strategy implementations
 * @dev Each strategy can have its own logic for calculating rewards
 */
interface IRewardStrategy {
    struct StrategyParameters {
        string name;
        string description;
        uint16 startDay;
        uint16 endDay;
    }

    /**
     * @notice Calculate reward for a specific stake
     * @param staker The address of the staker
     * @param stakeId The stake ID
     * @return The calculated reward amount
     */
    function calculateReward(
        address staker,
        bytes32 stakeId
    ) external view returns (uint256);

    /**
     * @notice Returns the strategy parameters
     * @return Array of parameter values (depends on specific strategy)
     */
    function getParameters() external view returns (StrategyParameters memory);

    /**
     * @notice Updates the strategy parameters
     * @param params Array of parameter values to update
     */
    function updateParameters(uint256[] calldata params) external;

    /**
     * @notice Validates if this strategy can be applied to a given stake
     * @param staker The address of the staker
     * @param stakeId The stake ID
     * @return True if strategy can be applied, false otherwise
     */
    function isApplicable(
        address staker,
        bytes32 stakeId
    ) external view returns (bool);
}
