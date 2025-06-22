// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import "../interfaces/IRewardStrategy.sol";
import "../interfaces/IStakingStorage.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract LinearAPRStrategy is IRewardStrategy, AccessControl {
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    IRewardStrategy.StrategyParameters public strategyParameters;
    IStakingStorage public immutable stakingStorage;
    uint256 public immutable annualRate; // in basis points (e.g., 500 = 5%)
    uint256 public immutable blocksPerYear;
    mapping(address => bool) blacklist;

    constructor(
        IRewardStrategy.StrategyParameters memory _strategyParameters,
        address _manager,
        uint256 _annualRate,
        uint256 _blocksPerYear,
        IStakingStorage _stakingStorage
    ) {
        strategyParameters = _strategyParameters;
        _grantRole(MANAGER_ROLE, _manager);

        annualRate = _annualRate;
        blocksPerYear = _blocksPerYear;
        stakingStorage = _stakingStorage;
    }

    function calculateReward(
        address,
        uint32[] calldata timestamps,
        uint256[] calldata stakeValues
    ) external view returns (uint256) {
        uint256 reward = 0;

        // require(
        //     isApplicable(msg.sender, stakeId),
        //     "Strategy is not applicable"
        // );

        for (uint256 i = 0; i < timestamps.length - 1; i++) {
            uint256 duration = timestamps[i + 1] - timestamps[i];
            uint256 stakeAmount = stakeValues[i];

            // Calculate reward for this period
            reward +=
                (stakeAmount * annualRate * duration) /
                (blocksPerYear * 10_000);
        }

        // Handle period from last checkpoint to current block
        if (timestamps.length > 0) {
            uint256 lastIndex = timestamps.length - 1;
            uint256 duration = block.timestamp - timestamps[lastIndex];
            uint256 stakeAmount = stakeValues[lastIndex];

            reward +=
                (stakeAmount * annualRate * duration) /
                (blocksPerYear * 10_000);
        }

        return reward;
    }

    /**
     * @notice Returns the strategy parameters
     * @return Array of parameter values (depends on specific strategy)
     */
    function getParameters()
        external
        view
        onlyRole(MANAGER_ROLE)
        returns (IRewardStrategy.StrategyParameters memory)
    {
        return strategyParameters;
    }

    /**
     * @notice Updates the strategy parameters
     * @param params Array of parameter values to update
     */
    function updateParameters(uint256[] calldata params) external onlyRole(MANAGER_ROLE) {
        // Basic implementation - update strategy parameters
        if (params.length >= 2) {
            strategyParameters.startDay = uint16(params[0]);
            strategyParameters.endDay = uint16(params[1]);
        }
    }

    /**
     * @notice Validates if this strategy can be applied to a given stake
     * @param staker The address of the staker
     * @param stakeId The stake ID
     * @return canApply True if strategy can be applied, false otherwise
     */
    function isApplicable(
        address staker,
        bytes32 stakeId
    ) public view returns (bool canApply) {
        canApply = true;
        IStakingStorage.Stake memory stake = stakingStorage.getStake(
            staker,
            stakeId
        );

        if (blacklist[staker]) canApply = false;
        if (
            stake.stakeDay > strategyParameters.endDay &&
            stake.stakeDay < strategyParameters.startDay
        ) {
            canApply = false;
        }
    }

    function calculateReward(
        address staker,
        bytes32 stakeId
    ) external view override returns (uint256) {
        IStakingStorage.Stake memory stake = stakingStorage.getStake(
            staker,
            stakeId
        );

        uint256 blocksPassed = block.timestamp / 86400 - stake.stakeDay;
        
        return (stake.amount * annualRate * blocksPassed) / (blocksPerYear * 10_000);
    }
}
