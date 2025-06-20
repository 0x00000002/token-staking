// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

interface IStakingVault {
    // Core functions
    function stake(
        uint128 amount,
        uint16 daysLock
    ) external returns (bytes32 stakeId);

    function unstake(bytes32 stakeId) external;

    /**
     * @notice Stake tokens from a claim with a timelock period in days
     * @param staker The address of the staker
     * @param amount The amount to stake
     * @param daysLock The timelock period in days
     * @return stakeId The ID of the created stake
     */
    function stakeFromClaim(
        address staker,
        uint128 amount,
        uint16 daysLock
    ) external returns (bytes32 stakeId);
}
