// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import "../interfaces/IRewardStrategy.sol";
import "../interfaces/IStakingStorage.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract TieredRewardStrategy is IRewardStrategy, AccessControl {
    uint256 public baseRewardRate;
    uint256[] public tierThresholds;
    uint256[] public tierMultipliers; // In basis points (e.g., 12000 = 1.2x)

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
        address staker,
        bytes32 stakeId
    ) external view returns (uint256) {
        IStakingStorage.Stake memory stake = stakingStorage.getStake(
            staker,
            stakeId
        );
        uint256 blocksPassed = block.timestamp / 86400 - stake.stakeDay;

        // Find applicable tier
        uint256 multiplier = 10_000; // Default 1.0x
        for (uint256 i = 0; i < tierThresholds.length; i++) {
            if (stake.amount >= tierThresholds[i])
                multiplier = tierMultipliers[i];
        }

        return
            (stake.amount * baseRewardRate * blocksPassed * multiplier) /
            (blocksPerYear * 10_000 * 10_000);
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
    {}

    /**
     * @notice Updates the strategy parameters
     * @param params Array of parameter values to update
     */
    function updateParameters(uint256[] calldata params) external {}

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
}
