// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "./RewardEnums.sol";

/**
 * @title IBaseRewardStrategy
 * @notice Base interface for all reward strategies
 */
interface IBaseRewardStrategy {
    struct StrategyParameters {
        string name;
        string description;
        uint16 startDay; // When strategy becomes active
        uint16 endDay; // When strategy expires (0 = permanent)
        StrategyType strategyType;
    }

    /// @notice Get the strategy type
    function getStrategyType() external view returns (StrategyType);

    /// @notice Get strategy parameters
    function getParameters() external view returns (StrategyParameters memory);

    /// @notice Update strategy parameters (admin only)
    function updateParameters(uint256[] calldata params) external;

    /// @notice Check if strategy applies to a specific stake
    function isApplicable(bytes32 stakeId) external view returns (bool);
}
