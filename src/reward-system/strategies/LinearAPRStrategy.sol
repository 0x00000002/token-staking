// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "../../interfaces/reward/IImmediateRewardStrategy.sol";
import "../../interfaces/staking/IStakingStorage.sol";

contract LinearAPRStrategy is IImmediateRewardStrategy {
    StrategyParameters public params;
    address public manager;
    uint256 public annualRateBasisPoints; // e.g., 1000 = 10%
    IStakingStorage public stakingStorage;

    error OnlyManagerCanUpdate();
    error InvalidParams();
    error NotSupportedForImmediateStrategies();

    constructor(
        StrategyParameters memory _params,
        address _manager,
        uint256 _annualRateBasisPoints,
        IStakingStorage _stakingStorage
    ) {
        params = _params;
        manager = _manager;
        annualRateBasisPoints = _annualRateBasisPoints;
        stakingStorage = _stakingStorage;
    }

    function getStrategyType() external pure returns (StrategyType) {
        return StrategyType.IMMEDIATE;
    }

    function getEpochDuration() external pure returns (uint32) {
        return 0;
    }

    function getParameters() external view returns (StrategyParameters memory) {
        return params;
    }

    function updateParameters(uint256[] calldata newParams) external {
        require(msg.sender == manager, OnlyManagerCanUpdate());
        require(newParams.length > 0, InvalidParams());
        annualRateBasisPoints = newParams[0];
    }

    function isApplicable(bytes32 stakeId) external view returns (bool) {
        IStakingStorage.Stake memory stake = stakingStorage.getStake(stakeId);
        return
            stake.stakeDay >= params.startDay &&
            (params.endDay == 0 || stake.stakeDay <= params.endDay);
    }

    function calculateHistoricalReward(
        bytes32 stakeId,
        uint32 fromDay,
        uint32 toDay
    ) external view returns (uint256) {
        IStakingStorage.Stake memory stake = stakingStorage.getStake(stakeId);

        uint32 effectiveStart = stake.stakeDay > fromDay
            ? stake.stakeDay
            : fromDay;

        uint32 calculatedEnd = toDay;
        if (stake.unstakeDay > 0 && stake.unstakeDay < calculatedEnd)
            calculatedEnd = stake.unstakeDay;

        uint32 effectiveEnd = calculatedEnd;
        if (params.endDay > 0 && params.endDay < effectiveEnd)
            effectiveEnd = params.endDay;

        if (effectiveStart >= effectiveEnd) return 0;

        uint256 effectiveDays = effectiveEnd - effectiveStart;
        return
            (stake.amount * annualRateBasisPoints * effectiveDays) /
            (365 * 10_000);
    }
}
