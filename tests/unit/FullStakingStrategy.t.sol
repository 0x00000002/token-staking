// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "forge-std/Test.sol";
import "../../src/reward-system/strategies/FullStakingStrategy.sol";
import "../helpers/MockERC20.sol";
import "../../src/interfaces/staking/IStakingStorage.sol";
import "../../src/interfaces/reward/IRewardStrategy.sol";
import "../../src/interfaces/staking/IStakingStorage.sol";

// Lean Mock: Implements only necessary functions and reverts on unexpected calls.
contract MockStakingStorageForFullStrategy is IStakingStorage {
    mapping(bytes32 => Stake) public stakes;

    function getStake(
        bytes32 _stakeId
    ) external view override returns (Stake memory) {
        return stakes[_stakeId];
    }

    function mockStake(
        bytes32 _stakeId,
        address _owner,
        uint128 _amount,
        uint16 _stakeDay,
        uint16 _unstakeDay,
        uint16 _daysLock,
        uint16 _flags
    ) public {
        stakes[_stakeId] = Stake({
            amount: _amount,
            stakeDay: _stakeDay,
            unstakeDay: _unstakeDay,
            daysLock: _daysLock,
            flags: _flags
        });
    }

    // --- Unused functions revert to catch unexpected calls ---
    function createStake(
        address,
        uint128,
        uint16,
        uint16
    ) external override returns (bytes32) {
        revert("Not Implemented");
    }
    function removeStake(address, bytes32) external override {
        revert("Not Implemented");
    }
    function isActiveStake(bytes32) external view override returns (bool) {
        revert("Not Implemented");
    }
    function getStakerInfo(
        address
    ) external view override returns (StakerInfo memory) {
        revert("Not Implemented");
    }
    function getStakerBalance(
        address
    ) external view override returns (uint128) {
        revert("Not Implemented");
    }
    function getStakerBalanceAt(
        address,
        uint16
    ) external view override returns (uint128) {
        revert("Not Implemented");
    }
    function batchGetStakerBalances(
        address[] memory,
        uint16
    ) external view override returns (uint128[] memory) {
        revert("Not Implemented");
    }
    function getDailySnapshot(
        uint16
    ) external view override returns (DailySnapshot memory) {
        revert("Not Implemented");
    }
    function getCurrentTotalStaked() external view override returns (uint128) {
        revert("Not Implemented");
    }
    function getStakersPaginated(
        uint256,
        uint256
    ) external view override returns (address[] memory) {
        revert("Not Implemented");
    }
    function getTotalStakersCount() external view override returns (uint256) {
        revert("Not Implemented");
    }
    function getStakerStakeIds(
        address
    ) external view override returns (bytes32[] memory) {
        revert("Not Implemented");
    }
}

contract FullStakingStrategyTest is Test {
    FullStakingStrategy public strategy;
    MockERC20 public mockRewardToken;
    MockStakingStorageForFullStrategy public mockStakingStorage;

    address public user = address(0x123);
    bytes32 public stakeId;

    uint16 public constant GRACE_PERIOD = 14; // 14 days
    uint16 public constant PARENT_POOL_START_DAY = 1;
    uint16 public constant PARENT_POOL_END_DAY = 90;
    uint256 public constant TOTAL_REWARD_AMOUNT = 1_000_000 * 1e18;

    function setUp() public {
        mockRewardToken = new MockERC20("RewardToken", "RWT");
        mockStakingStorage = new MockStakingStorageForFullStrategy();
        strategy = new FullStakingStrategy(
            address(mockRewardToken),
            GRACE_PERIOD
        );
        stakeId = _generateStakeId(user, 0);
    }

    function _generateStakeId(
        address staker,
        uint32 counter
    ) internal pure returns (bytes32) {
        return bytes32((uint256(uint160(staker)) << 96) | counter);
    }

    function test_CalculateReward_Eligible_StakedEarlyHeldToEnd() public {
        // Stake starts on day 10 (within grace period), held until end
        mockStakingStorage.mockStake(stakeId, user, 1000, 10, 0, 0, 0);
        IStakingStorage.Stake memory stake = mockStakingStorage.getStake(
            stakeId
        );

        // Assume total weight from 2 eligible users (1000 + 500)
        uint128 totalPoolWeight = 1500;

        uint256 reward = strategy.calculateReward(
            user,
            stake,
            totalPoolWeight,
            TOTAL_REWARD_AMOUNT,
            PARENT_POOL_START_DAY,
            PARENT_POOL_END_DAY
        );
        // Expected reward = (user_weight / total_weight) * total_reward
        // (1000 / 1500) * 1_000_000 = 666,666.66...
        assertEq(reward, (1000 * TOTAL_REWARD_AMOUNT) / totalPoolWeight);
    }

    function test_CalculateReward_Eligible_StakedOnLastGraceDayHeldToEnd()
        public
    {
        // Stake starts on day 14 (last day of grace period), held until end
        mockStakingStorage.mockStake(stakeId, user, 1000, 14, 0, 0, 0);
        IStakingStorage.Stake memory stake = mockStakingStorage.getStake(
            stakeId
        );

        uint128 totalPoolWeight = 1000; // Only one user eligible

        uint256 reward = strategy.calculateReward(
            user,
            stake,
            totalPoolWeight,
            TOTAL_REWARD_AMOUNT,
            PARENT_POOL_START_DAY,
            PARENT_POOL_END_DAY
        );
        assertEq(reward, TOTAL_REWARD_AMOUNT); // Full reward
    }

    function test_CalculateReward_NotEligible_UnstakedOnEndDay() public {
        // Stake starts early, unstaked on day 90 (end of parent pool) - should be not eligible
        mockStakingStorage.mockStake(stakeId, user, 1000, 10, 90, 0, 0);
        IStakingStorage.Stake memory stake = mockStakingStorage.getStake(
            stakeId
        );

        uint128 totalPoolWeight = 2000;
        uint256 reward = strategy.calculateReward(
            user,
            stake,
            totalPoolWeight,
            TOTAL_REWARD_AMOUNT,
            PARENT_POOL_START_DAY,
            PARENT_POOL_END_DAY
        );
        assertEq(reward, 0);
    }

    function test_CalculateReward_Eligible_UnstakedAfterEndDay() public {
        // Stake starts early, unstaked on day 95 (after end of parent pool) - should be eligible
        mockStakingStorage.mockStake(stakeId, user, 1000, 10, 95, 0, 0);
        IStakingStorage.Stake memory stake = mockStakingStorage.getStake(
            stakeId
        );

        uint128 totalPoolWeight = 1000;
        uint256 reward = strategy.calculateReward(
            user,
            stake,
            totalPoolWeight,
            TOTAL_REWARD_AMOUNT,
            PARENT_POOL_START_DAY,
            PARENT_POOL_END_DAY
        );
        assertEq(reward, TOTAL_REWARD_AMOUNT);
    }

    function test_CalculateReward_ZeroTotalWeight() public {
        mockStakingStorage.mockStake(stakeId, user, 1000, 10, 0, 0, 0);
        IStakingStorage.Stake memory stake = mockStakingStorage.getStake(
            stakeId
        );

        uint128 totalPoolWeight = 0;
        uint256 reward = strategy.calculateReward(
            user,
            stake,
            totalPoolWeight,
            TOTAL_REWARD_AMOUNT,
            PARENT_POOL_START_DAY,
            PARENT_POOL_END_DAY
        );
        assertEq(reward, 0);
    }
}
