// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

interface IRewardStorage {
    struct Reward {
        uint32 timestamp; // 32 bits - grouped for packing
        uint224 rewardAmount; // 224 bits - fits with timestamp in 1 slot
        uint256 stakeId; // 256 bits - requires its own slot
    }

    function setReward(
        address staker,
        uint256 stakeId,
        uint224 rewardAmount,
        uint32 timestamp
    ) external;

    function deleteReward(address staker, uint256 stakeId) external;

    function getReward(
        address staker,
        uint256 stakeId
    ) external view returns (Reward memory);

    function getRewardsCount(address staker) external view returns (uint256);

    function getTotalRewards(address staker) external view returns (uint224);

    function getRewardsByTimestamp(
        address staker,
        uint32 timestamp
    ) external view returns (Reward[] memory);

    function setController(address _controller) external;
}
