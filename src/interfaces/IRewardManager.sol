// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

interface IRewardManager {
  // Events
  event RewardClaimed(address indexed staker, bytes32[] stakeIds, uint256 amount);
  event StakeRewardClaimed(address indexed staker, bytes32 indexed stakeId, uint256 amount);

  // Core functions
  // Claim rewards for all stakes
  function claimAllRewards() external returns (uint256);

  // Claim rewards for specific stakes
  function claimRewards(bytes32[] calldata stakeIds) external returns (uint256);

  // Claim reward for a single stake
  function claimStakeReward(bytes32 stakeId) external returns (uint256);

  // View functions
  function getClaimableReward(address staker) external view returns (uint256);

  function getStakeClaimableReward(address staker, bytes32 stakeId) external view returns (uint256);

  function getStakesClaimableRewards(
    address staker,
    bytes32[] calldata stakeIds
  )
    external
    view
    returns (uint256[] memory, uint256 total);

  // Admin functions
  function addRewardFunds(uint256 amount) external;

  function withdrawRewardFunds(uint256 amount) external;

  function setRewardCalculator(address calculatorAddress) external;
}
