// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import "../interfaces/IRewardStrategy.sol";
import "../interfaces/IStakingStorage.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract TimeWeightedStrategy is IRewardStrategy, AccessControl {
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    IRewardStrategy.StrategyParameters public strategyParameters;
    IStakingStorage public immutable stakingStorage;

    uint256 public baseRewardRate;
    uint256 public maxBonus; // Maximum bonus in basis points
    uint256 public maxBonusBlocks; // Blocks required for max bonus

    mapping(address => bool) blacklist;

    constructor(
        IRewardStrategy.StrategyParameters memory _strategyParameters,
        address _manager,
        IStakingStorage _stakingStorage,
        uint256 _baseRewardRate,
        uint256 _maxBonus,
        uint256 _maxBonusBlocks
    ) {
        strategyParameters = _strategyParameters;
        _grantRole(MANAGER_ROLE, _manager);

        stakingStorage = _stakingStorage;
        baseRewardRate = _baseRewardRate;
        maxBonus = _maxBonus;
        maxBonusBlocks = _maxBonusBlocks;
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
        uint256 blocksPerYear = 2_102_400;

        // Calculate time bonus (capped at maxBonus)
        uint256 timeBonus = (blocksPassed * maxBonus) / maxBonusBlocks;
        if (timeBonus > maxBonus) timeBonus = maxBonus;

        uint256 effectiveRate = baseRewardRate + timeBonus;

        return
            (stake.amount * effectiveRate * blocksPassed) /
            (blocksPerYear * 10_000);
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
