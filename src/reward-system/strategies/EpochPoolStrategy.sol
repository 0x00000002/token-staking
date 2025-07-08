// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "../../interfaces/reward/IEpochRewardStrategy.sol";
import "../../interfaces/staking/IStakingStorage.sol";

contract EpochPoolStrategy is IEpochRewardStrategy {
    StrategyParameters public params;
    address public manager;
    uint32 public epochDurationDays;
    IStakingStorage public stakingStorage;

    error OnlyManagerCanUpdate();
    error InvalidParams();
    error UseCalculateEpochRewardForEpochStrategies();

    constructor(
        StrategyParameters memory _params,
        address _manager,
        uint32 _epochDurationDays,
        IStakingStorage _stakingStorage
    ) {
        params = _params;
        manager = _manager;
        epochDurationDays = _epochDurationDays;
        stakingStorage = _stakingStorage;
    }

    function getStrategyType() external pure returns (StrategyType) {
        return StrategyType.EPOCH_BASED;
    }

    function getEpochDuration() external view returns (uint32) {
        return epochDurationDays;
    }

    function getParameters() external view returns (StrategyParameters memory) {
        return params;
    }

    function updateParameters(uint256[] calldata newParams) external {
        require(msg.sender == manager, OnlyManagerCanUpdate());
        require(newParams.length > 0, InvalidParams());
        epochDurationDays = uint32(newParams[0]);
    }

    function isApplicable(bytes32 stakeId) external view returns (bool) {
        IStakingStorage.Stake memory stake = stakingStorage.getStake(stakeId);
        return
            stake.stakeDay >= params.startDay &&
            (params.endDay == 0 || stake.stakeDay <= params.endDay);
    }

    function calculateEpochReward(
        uint32 epochId, // TODO: use it!
        uint256 userStakeWeight,
        uint256 totalStakeWeight,
        uint256 poolSize
    ) external pure returns (uint256) {
        if (totalStakeWeight == 0) return 0;
        return (userStakeWeight * poolSize) / totalStakeWeight;
    }

    function validateEpochParticipation(
        bytes32 stakeId,
        uint32 epochStartDay,
        uint32 epochEndDay
    ) external view returns (bool) {
        IStakingStorage.Stake memory stake = stakingStorage.getStake(stakeId);
        return
            stake.stakeDay <= epochEndDay &&
            (stake.unstakeDay == 0 || stake.unstakeDay >= epochStartDay);
    }
}
