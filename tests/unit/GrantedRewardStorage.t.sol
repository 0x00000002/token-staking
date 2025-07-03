// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console2} from "forge-std/Test.sol";
import {GrantedRewardStorage} from "../../src/reward-system/GrantedRewardStorage.sol";
import {MockERC20} from "../helpers/MockERC20.sol";

contract GrantedRewardStorageTest is Test {
    GrantedRewardStorage public grantedRewardStorage;
    MockERC20 public rewardToken;

    address public admin = address(0x1);
    address public controller = address(0x2);
    address public user1 = address(0x3);
    address public user2 = address(0x4);
    address public unauthorized = address(0x5);

    uint128 public constant REWARD_AMOUNT = 1000e18;
    uint16 public constant STRATEGY_VERSION = 1;
    uint256 public constant STRATEGY_ID = 1;
    uint32 public constant EPOCH_ID = 1;

    event RewardGranted(
        address indexed user,
        uint256 indexed strategyId,
        uint32 indexed epochId,
        uint256 amount,
        uint16 strategyVersion
    );

    event RewardClaimed(
        address indexed user,
        uint256 indexed rewardIndex,
        uint256 amount
    );

    event BatchRewardsClaimed(
        address indexed user,
        uint256 totalAmount,
        uint256 rewardCount
    );

    function setUp() public {
        rewardToken = new MockERC20("Reward Token", "REWARD");
        grantedRewardStorage = new GrantedRewardStorage(admin);

        // Grant CONTROLLER_ROLE to controller address
        vm.startPrank(admin);
        grantedRewardStorage.grantRole(
            grantedRewardStorage.CONTROLLER_ROLE(),
            controller
        );
        vm.stopPrank();
    }

    // TC_GRS01: Grant Reward Operations
    function test_TCR_GRS01_SuccessfulGrantReward() public {
        vm.prank(controller);
        vm.expectEmit(true, true, true, true);
        emit RewardGranted(
            user1,
            STRATEGY_ID,
            EPOCH_ID,
            REWARD_AMOUNT,
            STRATEGY_VERSION
        );

        grantedRewardStorage.grantReward(
            user1,
            STRATEGY_ID,
            STRATEGY_VERSION,
            REWARD_AMOUNT,
            EPOCH_ID
        );

        // Verify reward was granted
        GrantedRewardStorage.GrantedReward[]
            memory rewards = grantedRewardStorage.getUserRewards(user1);
        assertEq(rewards.length, 1);
        assertEq(rewards[0].amount, REWARD_AMOUNT);
        assertEq(rewards[0].strategyId, STRATEGY_ID);
        assertEq(rewards[0].strategyVersion, STRATEGY_VERSION);
        assertEq(rewards[0].epochId, EPOCH_ID);
        assertEq(rewards[0].claimed, false);
        assertEq(rewards[0].grantedAt, block.timestamp);
    }

    function test_TCR_GRS01_GrantRewardWithZeroAmount() public {
        vm.prank(controller);
        grantedRewardStorage.grantReward(
            user1,
            STRATEGY_ID,
            STRATEGY_VERSION,
            0,
            EPOCH_ID
        );

        GrantedRewardStorage.GrantedReward[]
            memory rewards = grantedRewardStorage.getUserRewards(user1);
        assertEq(rewards.length, 1);
        assertEq(rewards[0].amount, 0);
    }

    function test_TCR_GRS01_GrantRewardWithMaxAmount() public {
        uint256 maxAmount = type(uint128).max;

        vm.prank(controller);
        grantedRewardStorage.grantReward(
            user1,
            STRATEGY_ID,
            STRATEGY_VERSION,
            maxAmount,
            EPOCH_ID
        );

        GrantedRewardStorage.GrantedReward[]
            memory rewards = grantedRewardStorage.getUserRewards(user1);
        assertEq(rewards.length, 1);
        assertEq(rewards[0].amount, maxAmount);
    }

    function test_TCR_GRS01_UnauthorizedGrantReward() public {
        vm.prank(unauthorized);
        vm.expectRevert();
        grantedRewardStorage.grantReward(
            user1,
            STRATEGY_ID,
            STRATEGY_VERSION,
            REWARD_AMOUNT,
            EPOCH_ID
        );
    }

    // TC_GRS02: Single Reward Claiming
    function test_TCR_GRS02_SuccessfulMarkRewardClaimed() public {
        // First grant a reward
        vm.prank(controller);
        grantedRewardStorage.grantReward(
            user1,
            STRATEGY_ID,
            STRATEGY_VERSION,
            REWARD_AMOUNT,
            EPOCH_ID
        );

        // Mark it as claimed
        vm.prank(controller);
        vm.expectEmit(true, true, true, true);
        emit RewardClaimed(user1, 0, REWARD_AMOUNT);

        grantedRewardStorage.markRewardClaimed(user1, 0);

        // Verify reward is marked as claimed
        GrantedRewardStorage.GrantedReward[]
            memory rewards = grantedRewardStorage.getUserRewards(user1);
        assertEq(rewards[0].claimed, true);
    }

    function test_TCR_GRS02_MarkAlreadyClaimedReward() public {
        // Grant and claim reward
        vm.prank(controller);
        grantedRewardStorage.grantReward(
            user1,
            STRATEGY_ID,
            STRATEGY_VERSION,
            REWARD_AMOUNT,
            EPOCH_ID
        );

        vm.prank(controller);
        grantedRewardStorage.markRewardClaimed(user1, 0);

        // Try to claim again
        vm.prank(controller);
        vm.expectRevert(
            abi.encodeWithSelector(
                GrantedRewardStorage.RewardAlreadyClaimed.selector,
                0
            )
        );
        grantedRewardStorage.markRewardClaimed(user1, 0);
    }

    function test_TCR_GRS02_MarkRewardWithInvalidIndex() public {
        // Grant one reward
        vm.prank(controller);
        grantedRewardStorage.grantReward(
            user1,
            STRATEGY_ID,
            STRATEGY_VERSION,
            REWARD_AMOUNT,
            EPOCH_ID
        );

        // Try to claim with invalid index
        vm.prank(controller);
        vm.expectRevert();
        grantedRewardStorage.markRewardClaimed(user1, 1);
    }

    function test_TCR_GRS02_UnauthorizedMarkRewardClaimed() public {
        vm.prank(controller);
        grantedRewardStorage.grantReward(
            user1,
            STRATEGY_ID,
            STRATEGY_VERSION,
            REWARD_AMOUNT,
            EPOCH_ID
        );

        vm.prank(unauthorized);
        vm.expectRevert();
        grantedRewardStorage.markRewardClaimed(user1, 0);
    }

    // TC_GRS03: Batch Reward Claiming
    function test_TCR_GRS03_SuccessfulBatchMarkClaimed() public {
        // Grant multiple rewards
        vm.startPrank(controller);
        grantedRewardStorage.grantReward(
            user1,
            STRATEGY_ID,
            STRATEGY_VERSION,
            100e18,
            EPOCH_ID
        );
        grantedRewardStorage.grantReward(
            user1,
            STRATEGY_ID,
            STRATEGY_VERSION,
            200e18,
            EPOCH_ID
        );
        grantedRewardStorage.grantReward(
            user1,
            STRATEGY_ID,
            STRATEGY_VERSION,
            300e18,
            EPOCH_ID
        );
        vm.stopPrank();

        uint256[] memory indices = new uint256[](3);
        indices[0] = 0;
        indices[1] = 1;
        indices[2] = 2;

        vm.prank(controller);
        vm.expectEmit(true, false, false, true);
        emit BatchRewardsClaimed(user1, 600e18, 3);

        grantedRewardStorage.batchMarkClaimed(user1, indices);

        // Verify all rewards are claimed
        GrantedRewardStorage.GrantedReward[]
            memory rewards = grantedRewardStorage.getUserRewards(user1);
        assertEq(rewards[0].claimed, true);
        assertEq(rewards[1].claimed, true);
        assertEq(rewards[2].claimed, true);
    }

    function test_TCR_GRS03_BatchClaimWithMixedStatus() public {
        // Grant rewards and claim one
        vm.startPrank(controller);
        grantedRewardStorage.grantReward(
            user1,
            STRATEGY_ID,
            STRATEGY_VERSION,
            100e18,
            EPOCH_ID
        );
        grantedRewardStorage.grantReward(
            user1,
            STRATEGY_ID,
            STRATEGY_VERSION,
            200e18,
            EPOCH_ID
        );
        grantedRewardStorage.grantReward(
            user1,
            STRATEGY_ID,
            STRATEGY_VERSION,
            300e18,
            EPOCH_ID
        );

        // Claim the first one
        grantedRewardStorage.markRewardClaimed(user1, 0);
        vm.stopPrank();

        uint256[] memory indices = new uint256[](3);
        indices[0] = 0; // already claimed
        indices[1] = 1; // unclaimed
        indices[2] = 2; // unclaimed

        vm.prank(controller);
        vm.expectEmit(true, false, false, true);
        emit BatchRewardsClaimed(user1, 500e18, 2); // Only newly claimed amounts

        grantedRewardStorage.batchMarkClaimed(user1, indices);
    }

    function test_TCR_GRS03_BatchClaimWithEmptyArray() public {
        uint256[] memory indices = new uint256[](0);

        vm.prank(controller);
        vm.expectEmit(true, false, false, true);
        emit BatchRewardsClaimed(user1, 0, 0);

        grantedRewardStorage.batchMarkClaimed(user1, indices);
    }

    function test_TCR_GRS03_BatchClaimWithDuplicateIndices() public {
        vm.prank(controller);
        grantedRewardStorage.grantReward(
            user1,
            STRATEGY_ID,
            STRATEGY_VERSION,
            100e18,
            EPOCH_ID
        );

        uint256[] memory indices = new uint256[](2);
        indices[0] = 0;
        indices[1] = 0; // duplicate

        vm.prank(controller);
        vm.expectEmit(true, false, false, true);
        emit BatchRewardsClaimed(user1, 100e18, 1); // Only claimed once

        grantedRewardStorage.batchMarkClaimed(user1, indices);
    }

    // TC_GRS04: User Rewards Retrieval
    function test_TCR_GRS04_GetRewardsForUserWithNoRewards() public view {
        GrantedRewardStorage.GrantedReward[]
            memory rewards = grantedRewardStorage.getUserRewards(user1);
        assertEq(rewards.length, 0);
    }

    function test_TCR_GRS04_GetRewardsForUserWithSingleReward() public {
        vm.prank(controller);
        grantedRewardStorage.grantReward(
            user1,
            STRATEGY_ID,
            STRATEGY_VERSION,
            REWARD_AMOUNT,
            EPOCH_ID
        );

        GrantedRewardStorage.GrantedReward[]
            memory rewards = grantedRewardStorage.getUserRewards(user1);
        assertEq(rewards.length, 1);
        assertEq(rewards[0].amount, REWARD_AMOUNT);
        assertEq(rewards[0].strategyId, STRATEGY_ID);
    }

    function test_TCR_GRS04_GetRewardsForUserWithMultipleRewards() public {
        vm.startPrank(controller);
        grantedRewardStorage.grantReward(user1, 1, 1, 100e18, 1);
        grantedRewardStorage.grantReward(user1, 2, 2, 200e18, 2);
        grantedRewardStorage.grantReward(user1, 3, 3, 300e18, 3);
        vm.stopPrank();

        GrantedRewardStorage.GrantedReward[]
            memory rewards = grantedRewardStorage.getUserRewards(user1);
        assertEq(rewards.length, 3);

        // Verify chronological order
        assertEq(rewards[0].strategyId, 1);
        assertEq(rewards[1].strategyId, 2);
        assertEq(rewards[2].strategyId, 3);
    }

    function test_TCR_GRS04_GetRewardsWithMixedClaimedStatus() public {
        vm.startPrank(controller);
        grantedRewardStorage.grantReward(
            user1,
            STRATEGY_ID,
            STRATEGY_VERSION,
            100e18,
            EPOCH_ID
        );
        grantedRewardStorage.grantReward(
            user1,
            STRATEGY_ID,
            STRATEGY_VERSION,
            200e18,
            EPOCH_ID
        );

        // Claim first reward
        grantedRewardStorage.markRewardClaimed(user1, 0);
        vm.stopPrank();

        GrantedRewardStorage.GrantedReward[]
            memory rewards = grantedRewardStorage.getUserRewards(user1);
        assertEq(rewards.length, 2);
        assertEq(rewards[0].claimed, true);
        assertEq(rewards[1].claimed, false);
    }

    // TC_GRS05: Claimable Amount Calculation
    function test_TCR_GRS05_ClaimableAmountForUserWithNoRewards() public view {
        uint256 amount = grantedRewardStorage.getUserClaimableAmount(user1);
        assertEq(amount, 0); // 0
    }

    function test_TCR_GRS05_ClaimableAmountForUserWithAllRewardsClaimed()
        public
    {
        vm.startPrank(controller);
        grantedRewardStorage.grantReward(
            user1,
            STRATEGY_ID,
            STRATEGY_VERSION,
            100e18,
            EPOCH_ID
        );
        grantedRewardStorage.grantReward(
            user1,
            STRATEGY_ID,
            STRATEGY_VERSION,
            200e18,
            EPOCH_ID
        );

        grantedRewardStorage.markRewardClaimed(user1, 0);
        grantedRewardStorage.markRewardClaimed(user1, 1);
        vm.stopPrank();

        uint256 amount = grantedRewardStorage.getUserClaimableAmount(user1);
        assertEq(amount, 0);
    }

    function test_TCR_GRS05_ClaimableAmountForUserWithAllRewardsUnclaimed()
        public
    {
        vm.startPrank(controller);
        grantedRewardStorage.grantReward(
            user1,
            STRATEGY_ID,
            STRATEGY_VERSION,
            100e18,
            EPOCH_ID
        );
        grantedRewardStorage.grantReward(
            user1,
            STRATEGY_ID,
            STRATEGY_VERSION,
            200e18,
            EPOCH_ID
        );
        grantedRewardStorage.grantReward(
            user1,
            STRATEGY_ID,
            STRATEGY_VERSION,
            300e18,
            EPOCH_ID
        );
        vm.stopPrank();

        uint256 amount = grantedRewardStorage.getUserClaimableAmount(user1);
        assertEq(amount, 600e18);
    }

    function test_TCR_GRS05_ClaimableAmountWithMixedStatus() public {
        vm.startPrank(controller);
        grantedRewardStorage.grantReward(
            user1,
            STRATEGY_ID,
            STRATEGY_VERSION,
            100e18,
            EPOCH_ID
        ); // will be claimed
        grantedRewardStorage.grantReward(
            user1,
            STRATEGY_ID,
            STRATEGY_VERSION,
            200e18,
            EPOCH_ID
        ); // unclaimed
        grantedRewardStorage.grantReward(
            user1,
            STRATEGY_ID,
            STRATEGY_VERSION,
            300e18,
            EPOCH_ID
        ); // unclaimed

        grantedRewardStorage.markRewardClaimed(user1, 0);
        vm.stopPrank();

        uint256 amount = grantedRewardStorage.getUserClaimableAmount(user1);
        assertEq(amount, 500e18); // 200 + 300
    }

    function test_TCR_GRS05_ClaimableAmountWithLargeNumbers() public {
        uint256 largeAmount = type(uint128).max / 2;

        vm.startPrank(controller);
        grantedRewardStorage.grantReward(
            user1,
            STRATEGY_ID,
            STRATEGY_VERSION,
            largeAmount,
            EPOCH_ID
        );
        grantedRewardStorage.grantReward(
            user1,
            STRATEGY_ID,
            STRATEGY_VERSION,
            largeAmount,
            EPOCH_ID
        );
        vm.stopPrank();

        uint256 amount = grantedRewardStorage.getUserClaimableAmount(user1);
        assertEq(amount, largeAmount * 2);
    }

    // TC_GRS06: Claimable Rewards with Indices
    function test_TCR_GRS06_ClaimableRewardsForUserWithNoRewards() public view {
        (
            GrantedRewardStorage.GrantedReward[] memory rewards,
            uint256[] memory indices
        ) = grantedRewardStorage.getUserClaimableRewards(user1);

        assertEq(rewards.length, 0);
        assertEq(indices.length, 0);
    }

    function test_TCR_GRS06_ClaimableRewardsForUserWithAllRewardsClaimed()
        public
    {
        vm.startPrank(controller);
        grantedRewardStorage.grantReward(
            user1,
            STRATEGY_ID,
            STRATEGY_VERSION,
            100e18,
            EPOCH_ID
        );
        grantedRewardStorage.markRewardClaimed(user1, 0);
        vm.stopPrank();

        (
            GrantedRewardStorage.GrantedReward[] memory rewards,
            uint256[] memory indices
        ) = grantedRewardStorage.getUserClaimableRewards(user1);

        assertEq(rewards.length, 0);
        assertEq(indices.length, 0);
    }

    function test_TCR_GRS06_ClaimableRewardsWithMixedStatus() public {
        vm.startPrank(controller);
        grantedRewardStorage.grantReward(
            user1,
            STRATEGY_ID,
            STRATEGY_VERSION,
            100e18,
            EPOCH_ID
        ); // index 0 - will be claimed
        grantedRewardStorage.grantReward(
            user1,
            STRATEGY_ID,
            STRATEGY_VERSION,
            200e18,
            EPOCH_ID
        ); // index 1 - unclaimed
        grantedRewardStorage.grantReward(
            user1,
            STRATEGY_ID,
            STRATEGY_VERSION,
            300e18,
            EPOCH_ID
        ); // index 2 - will be claimed
        grantedRewardStorage.grantReward(
            user1,
            STRATEGY_ID,
            STRATEGY_VERSION,
            400e18,
            EPOCH_ID
        ); // index 3 - unclaimed

        grantedRewardStorage.markRewardClaimed(user1, 0);
        grantedRewardStorage.markRewardClaimed(user1, 2);
        vm.stopPrank();

        (
            GrantedRewardStorage.GrantedReward[] memory rewards,
            uint256[] memory indices
        ) = grantedRewardStorage.getUserClaimableRewards(user1);

        assertEq(rewards.length, 2);
        assertEq(indices.length, 2);

        // Should return rewards at indices 1 and 3
        assertEq(indices[0], 1);
        assertEq(indices[1], 3);
        assertEq(rewards[0].amount, 200e18);
        assertEq(rewards[1].amount, 400e18);
    }

    // TC_GRS07: Epoch-Specific Rewards
    function test_TCR_GRS07_EpochRewardsForEpochWithNoRewards() public view {
        GrantedRewardStorage.GrantedReward[]
            memory rewards = grantedRewardStorage.getUserEpochRewards(
                user1,
                999
            );

        assertEq(rewards.length, 0);
    }

    function test_TCR_GRS07_EpochRewardsForSpecificEpoch() public {
        vm.startPrank(controller);
        grantedRewardStorage.grantReward(
            user1,
            STRATEGY_ID,
            STRATEGY_VERSION,
            100e18,
            1
        ); // epoch 1
        grantedRewardStorage.grantReward(
            user1,
            STRATEGY_ID,
            STRATEGY_VERSION,
            200e18,
            2
        ); // epoch 2
        grantedRewardStorage.grantReward(
            user1,
            STRATEGY_ID,
            STRATEGY_VERSION,
            300e18,
            1
        ); // epoch 1
        grantedRewardStorage.grantReward(
            user1,
            STRATEGY_ID,
            STRATEGY_VERSION,
            400e18,
            3
        ); // epoch 3
        grantedRewardStorage.grantReward(
            user1,
            STRATEGY_ID,
            STRATEGY_VERSION,
            500e18,
            2
        ); // epoch 2
        vm.stopPrank();

        GrantedRewardStorage.GrantedReward[]
            memory rewards = grantedRewardStorage.getUserEpochRewards(user1, 2);

        assertEq(rewards.length, 2);
        assertEq(rewards[0].amount, 200e18);
        assertEq(rewards[1].amount, 500e18);
        assertEq(rewards[0].epochId, 2);
        assertEq(rewards[1].epochId, 2);
    }

    function test_TCR_GRS07_ImmediateRewards() public {
        vm.startPrank(controller);
        grantedRewardStorage.grantReward(
            user1,
            STRATEGY_ID,
            STRATEGY_VERSION,
            100e18,
            0
        ); // immediate
        grantedRewardStorage.grantReward(
            user1,
            STRATEGY_ID,
            STRATEGY_VERSION,
            200e18,
            1
        ); // epoch 1
        grantedRewardStorage.grantReward(
            user1,
            STRATEGY_ID,
            STRATEGY_VERSION,
            300e18,
            0
        ); // immediate
        vm.stopPrank();

        GrantedRewardStorage.GrantedReward[]
            memory rewards = grantedRewardStorage.getUserEpochRewards(user1, 0);

        assertEq(rewards.length, 2);
        assertEq(rewards[0].amount, 100e18);
        assertEq(rewards[1].amount, 300e18);
    }

    // TC_GRS08: Paginated Rewards
    function test_TCR_GRS08_PaginatedRewardsWithValidOffsetAndLimit() public {
        // Grant 10 rewards
        vm.startPrank(controller);
        for (uint256 i = 0; i < 10; i++) {
            grantedRewardStorage.grantReward(
                user1,
                STRATEGY_ID,
                STRATEGY_VERSION,
                (i + 1) * 100e18,
                EPOCH_ID
            );
        }
        vm.stopPrank();

        GrantedRewardStorage.GrantedReward[]
            memory rewards = grantedRewardStorage.getUserRewardsPaginated(
                user1,
                2,
                3
            );

        assertEq(rewards.length, 3);
        assertEq(rewards[0].amount, 300e18); // index 2
        assertEq(rewards[1].amount, 400e18); // index 3
        assertEq(rewards[2].amount, 500e18); // index 4
    }

    function test_TCR_GRS08_PaginatedRewardsWithOffsetBeyondLength() public {
        vm.prank(controller);
        grantedRewardStorage.grantReward(
            user1,
            STRATEGY_ID,
            STRATEGY_VERSION,
            100e18,
            EPOCH_ID
        );

        GrantedRewardStorage.GrantedReward[]
            memory rewards = grantedRewardStorage.getUserRewardsPaginated(
                user1,
                10,
                5
            );

        assertEq(rewards.length, 0);
    }

    function test_TCR_GRS08_PaginatedRewardsWithLimitExceedingRemaining()
        public
    {
        // Grant 5 rewards
        vm.startPrank(controller);
        for (uint256 i = 0; i < 5; i++) {
            grantedRewardStorage.grantReward(
                user1,
                STRATEGY_ID,
                STRATEGY_VERSION,
                (i + 1) * 100e18,
                EPOCH_ID
            );
        }
        vm.stopPrank();

        GrantedRewardStorage.GrantedReward[]
            memory rewards = grantedRewardStorage.getUserRewardsPaginated(
                user1,
                3,
                10
            );

        assertEq(rewards.length, 2); // Only 2 remaining from index 3
        assertEq(rewards[0].amount, 400e18); // index 3
        assertEq(rewards[1].amount, 500e18); // index 4
    }

    function test_TCR_GRS08_PaginatedRewardsWithZeroLimit() public {
        vm.prank(controller);
        grantedRewardStorage.grantReward(
            user1,
            STRATEGY_ID,
            STRATEGY_VERSION,
            100e18,
            EPOCH_ID
        );

        GrantedRewardStorage.GrantedReward[]
            memory rewards = grantedRewardStorage.getUserRewardsPaginated(
                user1,
                0,
                0
            );

        assertEq(rewards.length, 0);
    }

    function test_TCR_GRS08_PaginationBoundaryConditions() public {
        // Grant exactly 10 rewards
        vm.startPrank(controller);
        for (uint256 i = 0; i < 10; i++) {
            grantedRewardStorage.grantReward(
                user1,
                STRATEGY_ID,
                STRATEGY_VERSION,
                (i + 1) * 100e18,
                EPOCH_ID
            );
        }
        vm.stopPrank();

        // Get all rewards
        GrantedRewardStorage.GrantedReward[]
            memory rewards1 = grantedRewardStorage.getUserRewardsPaginated(
                user1,
                0,
                10
            );
        assertEq(rewards1.length, 10);

        // Get beyond end
        GrantedRewardStorage.GrantedReward[]
            memory rewards2 = grantedRewardStorage.getUserRewardsPaginated(
                user1,
                10,
                10
            );
        assertEq(rewards2.length, 0);
    }

    // TC_GRS09: Next Claimable Index Management
    function test_TCR_GRS09_UpdateIndexAfterClaimingFirstFewRewards() public {
        vm.startPrank(controller);
        grantedRewardStorage.grantReward(
            user1,
            STRATEGY_ID,
            STRATEGY_VERSION,
            100e18,
            EPOCH_ID
        ); // index 0
        grantedRewardStorage.grantReward(
            user1,
            STRATEGY_ID,
            STRATEGY_VERSION,
            200e18,
            EPOCH_ID
        ); // index 1
        grantedRewardStorage.grantReward(
            user1,
            STRATEGY_ID,
            STRATEGY_VERSION,
            300e18,
            EPOCH_ID
        ); // index 2
        grantedRewardStorage.grantReward(
            user1,
            STRATEGY_ID,
            STRATEGY_VERSION,
            400e18,
            EPOCH_ID
        ); // index 3

        // Claim first two rewards
        grantedRewardStorage.markRewardClaimed(user1, 0);
        grantedRewardStorage.markRewardClaimed(user1, 1);

        // Update index
        grantedRewardStorage.updateNextClaimableIndex(user1);
        vm.stopPrank();

        // Get claimable rewards - should start from index 2
        (
            GrantedRewardStorage.GrantedReward[] memory rewards,
            uint256[] memory indices
        ) = grantedRewardStorage.getUserClaimableRewards(user1);

        assertEq(rewards.length, 2);
        assertEq(indices[0], 2);
        assertEq(indices[1], 3);
    }

    function test_TCR_GRS09_UpdateIndexWhenAllRewardsClaimed() public {
        vm.startPrank(controller);
        grantedRewardStorage.grantReward(
            user1,
            STRATEGY_ID,
            STRATEGY_VERSION,
            100e18,
            EPOCH_ID
        );
        grantedRewardStorage.grantReward(
            user1,
            STRATEGY_ID,
            STRATEGY_VERSION,
            200e18,
            EPOCH_ID
        );

        // Claim all rewards
        grantedRewardStorage.markRewardClaimed(user1, 0);
        grantedRewardStorage.markRewardClaimed(user1, 1);

        // Update index
        grantedRewardStorage.updateNextClaimableIndex(user1);
        vm.stopPrank();

        // Should return empty arrays quickly
        (
            GrantedRewardStorage.GrantedReward[] memory rewards,
            uint256[] memory indices
        ) = grantedRewardStorage.getUserClaimableRewards(user1);

        assertEq(rewards.length, 0);
        assertEq(indices.length, 0);
    }

    function test_TCR_GRS09_UpdateIndexForUserWithNoRewards() public {
        vm.prank(controller);
        grantedRewardStorage.updateNextClaimableIndex(user1);

        // Should not revert and return empty
        (
            GrantedRewardStorage.GrantedReward[] memory rewards,
            uint256[] memory indices
        ) = grantedRewardStorage.getUserClaimableRewards(user1);

        assertEq(rewards.length, 0);
        assertEq(indices.length, 0);
    }

    function test_TCR_GRS09_UnauthorizedIndexUpdate() public {
        vm.prank(unauthorized);
        vm.expectRevert();
        grantedRewardStorage.updateNextClaimableIndex(user1);
    }
}
