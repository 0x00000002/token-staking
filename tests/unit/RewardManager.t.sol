// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console2} from "forge-std/Test.sol";
import {RewardManager} from "../../src/reward-system/RewardManager.sol";
import {StrategiesRegistry} from "../../src/reward-system/StrategiesRegistry.sol";
import {GrantedRewardStorage} from "../../src/reward-system/GrantedRewardStorage.sol";
import {EpochManager} from "../../src/reward-system/EpochManager.sol";
import {StakingStorage} from "../../src/StakingStorage.sol";
import {StakingVault} from "../../src/StakingVault.sol";
import {LinearAPRStrategy} from "../../src/reward-system/strategies/LinearAPRStrategy.sol";
import {EpochPoolStrategy} from "../../src/reward-system/strategies/EpochPoolStrategy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {MockERC20} from "../helpers/MockERC20.sol";
import {RewardErrors} from "../../src/interfaces/reward/RewardErrors.sol";
import {StrategyType, EpochState} from "../../src/interfaces/reward/RewardEnums.sol";
import {IBaseRewardStrategy} from "../../src/interfaces/reward/IBaseRewardStrategy.sol";

contract RewardManagerTest is Test {
    RewardManager public rewardManager;
    StrategiesRegistry public registry;
    GrantedRewardStorage public grantedRewardStorage;
    EpochManager public epochManager;
    StakingStorage public stakingStorage;
    StakingVault public vault;
    LinearAPRStrategy public linearStrategy;
    EpochPoolStrategy public epochStrategy;
    MockERC20 public stakingToken;
    MockERC20 public rewardToken;

    address public admin = address(0x1);
    address public manager = address(0x2);
    address public user1 = address(0x3);
    address public user2 = address(0x4);
    address public unauthorized = address(0x5);

    uint128 public constant STAKE_AMOUNT = 1000e18;
    uint16 public constant DAYS_LOCK = 30;

    uint256 public linearStrategyId;
    uint256 public epochStrategyId;

    function setUp() public {
        // Deploy tokens
        stakingToken = new MockERC20("Staking Token", "STAKE");
        rewardToken = new MockERC20("Reward Token", "REWARD");

        // Deploy core system
        stakingStorage = new StakingStorage(admin, manager, address(0));
        vault = new StakingVault(
            IERC20(stakingToken),
            address(stakingStorage),
            admin,
            manager
        );

        // Deploy reward system
        registry = new StrategiesRegistry(admin);
        grantedRewardStorage = new GrantedRewardStorage(admin);
        epochManager = new EpochManager(admin);
        rewardManager = new RewardManager(
            admin,
            address(registry),
            address(grantedRewardStorage),
            address(epochManager),
            address(stakingStorage),
            address(rewardToken)
        );

        // Setup roles
        vm.startPrank(admin);
        stakingStorage.grantRole(
            stakingStorage.CONTROLLER_ROLE(),
            address(vault)
        );
        grantedRewardStorage.grantRole(
            grantedRewardStorage.CONTROLLER_ROLE(),
            address(rewardManager)
        );
        vm.stopPrank();

        // Create strategies
        IBaseRewardStrategy.StrategyParameters
            memory params = IBaseRewardStrategy.StrategyParameters({
                name: "Test Linear Strategy",
                description: "Test strategy for linear rewards",
                startDay: 1,
                endDay: 365,
                strategyType: StrategyType.IMMEDIATE
            });

        linearStrategy = new LinearAPRStrategy(
            params,
            manager,
            1000, // 10% APR
            stakingStorage
        );

        IBaseRewardStrategy.StrategyParameters
            memory epochParams = IBaseRewardStrategy.StrategyParameters({
                name: "Test Epoch Strategy",
                description: "Test strategy for epoch rewards",
                startDay: 1,
                endDay: 365,
                strategyType: StrategyType.EPOCH_BASED
            });

        epochStrategy = new EpochPoolStrategy(
            epochParams,
            manager,
            30, // 30 day epochs
            stakingStorage
        );

        // Register strategies
        vm.startPrank(admin);
        linearStrategyId = registry.registerStrategy(address(linearStrategy));
        epochStrategyId = registry.registerStrategy(address(epochStrategy));
        registry.setStrategyStatus(linearStrategyId, true);
        registry.setStrategyStatus(epochStrategyId, true);
        vm.stopPrank();

        // Setup users with tokens
        stakingToken.mint(user1, 10_000e18);
        stakingToken.mint(user2, 10_000e18);
        rewardToken.mint(address(rewardManager), 1_000_000e18);

        vm.startPrank(user1);
        stakingToken.approve(address(vault), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(user2);
        stakingToken.approve(address(vault), type(uint256).max);
        vm.stopPrank();

        // Set reasonable timestamp
        vm.warp(30 days);
    }

    // ============================================================================
    // TC_R07: Immediate Reward Calculation (UC23)
    // ============================================================================

    function test_TCR07_CalculateImmediateRewardsForBatchOfUsers() public {
        // Users have stakes within time period
        vm.startPrank(user1);
        vault.stake(STAKE_AMOUNT, DAYS_LOCK);
        vm.stopPrank();

        vm.startPrank(user2);
        vault.stake(STAKE_AMOUNT * 2, DAYS_LOCK);
        vm.stopPrank();

        // Fast forward time
        vm.warp(block.timestamp + 10 days);

        vm.startPrank(admin);

        uint32 fromDay = uint32((block.timestamp - 10 days) / 1 days);
        uint32 toDay = uint32(block.timestamp / 1 days);

        // Calculate immediate rewards for batch of users
        rewardManager.calculateImmediateRewards(
            linearStrategyId,
            fromDay,
            toDay,
            0,
            10
        );

        vm.stopPrank();

        // System should fetch user stakes via pagination
        // Strategy should determine stake applicability
        // Rewards should be calculated for eligible stakes
        uint256 user1Rewards = rewardManager.getClaimableRewards(user1);
        uint256 user2Rewards = rewardManager.getClaimableRewards(user2);

        assertTrue(user1Rewards > 0, "User1 should have rewards");
        assertTrue(user2Rewards > 0, "User2 should have rewards");
        assertTrue(
            user2Rewards > user1Rewards,
            "User2 should have more rewards"
        );

        // Rewards should be granted to GrantedRewardStorage
        (uint256 totalGranted, , ) = rewardManager.getUserRewardSummary(user1);
        assertEq(totalGranted, user1Rewards);
    }

    function test_TCR07_CalculateRewardsWithInvalidStrategy() public {
        vm.startPrank(admin);

        // Strategy is not IMMEDIATE type (epochStrategy is EPOCH_BASED)
        vm.expectRevert(
            abi.encodeWithSelector(
                RewardErrors.InvalidStrategyType.selector,
                epochStrategyId
            )
        );
        rewardManager.calculateImmediateRewards(epochStrategyId, 1, 10, 0, 1);

        vm.stopPrank();
    }

    function test_TCR07_BatchSizeExceedsMaximum() public {
        vm.startPrank(admin);

        uint256 maxBatchSize = rewardManager.MAX_BATCH_SIZE();

        vm.expectRevert(
            abi.encodeWithSelector(
                RewardErrors.BatchSizeExceeded.selector,
                maxBatchSize + 1
            )
        );
        rewardManager.calculateImmediateRewards(
            linearStrategyId,
            1,
            10,
            0,
            maxBatchSize + 1
        );

        vm.stopPrank();
    }

    // ============================================================================
    // TC_R08: Epoch Reward Distribution (UC24)
    // ============================================================================

    function test_TCR08_CalculateEpochRewardsForParticipants() public {
        // Setup epoch
        vm.startPrank(admin);
        uint32 currentDay = uint32(block.timestamp / 1 days);
        uint32 epochId = epochManager.announceEpoch(
            currentDay,
            currentDay + 30,
            epochStrategyId,
            1000000e18
        );
        epochManager.updateEpochStates(); // Move to ACTIVE
        vm.stopPrank();

        // Users stake during epoch
        vm.startPrank(user1);
        vault.stake(STAKE_AMOUNT, DAYS_LOCK);
        vm.stopPrank();

        vm.startPrank(user2);
        vault.stake(STAKE_AMOUNT * 2, DAYS_LOCK);
        vm.stopPrank();

        // End epoch
        vm.warp((currentDay + 31) * 1 days);

        vm.startPrank(admin);
        epochManager.updateEpochStates(); // Move to ENDED
        // Set pool size BEFORE finalizing (since finalizeEpoch changes state to CALCULATED)
        epochManager.setEpochPoolSize(epochId, 900000e18);
        epochManager.finalizeEpoch(epochId, 2, STAKE_AMOUNT * 3 * 30); // totalWeight = amount * days

        // Calculate epoch rewards
        rewardManager.calculateEpochRewards(epochId, 0, 10);

        vm.stopPrank();

        // System should calculate user participation weights
        // Rewards should be distributed proportionally
        uint256 user1Rewards = rewardManager.getClaimableRewards(user1);
        uint256 user2Rewards = rewardManager.getClaimableRewards(user2);

        assertTrue(user1Rewards > 0, "User1 should have epoch rewards");
        assertTrue(user2Rewards > 0, "User2 should have epoch rewards");
        assertTrue(
            user2Rewards > user1Rewards,
            "User2 should have more rewards (2x stake)"
        );

        // Rewards should be granted with epoch ID
        GrantedRewardStorage.GrantedReward[]
            memory user1RewardList = grantedRewardStorage.getUserRewards(user1);
        assertTrue(
            user1RewardList.length > 0,
            "User1 should have reward entries"
        );
        assertEq(user1RewardList[0].epochId, epochId);
    }

    function test_TCR08_CalculateRewardsForNonCalculatedEpoch() public {
        vm.startPrank(admin);
        uint32 currentDay = uint32(block.timestamp / 1 days);
        uint32 epochId = epochManager.announceEpoch(
            currentDay,
            currentDay + 30,
            epochStrategyId,
            1000000e18
        );

        // Epoch is not in CALCULATED state
        vm.expectRevert(
            abi.encodeWithSelector(
                RewardErrors.EpochNotCalculated.selector,
                epochId
            )
        );
        rewardManager.calculateEpochRewards(epochId, 0, 10);

        vm.stopPrank();
    }

    function test_TCR08_EpochWithoutPoolSize() public {
        vm.startPrank(admin);
        uint32 currentDay = uint32(block.timestamp / 1 days);
        uint32 epochId = epochManager.announceEpoch(
            currentDay,
            currentDay + 30,
            epochStrategyId,
            1000000e18
        );

        // Move to ENDED and finalize but don't set pool size
        epochManager.updateEpochStates();
        vm.warp((currentDay + 31) * 1 days);
        epochManager.updateEpochStates();
        epochManager.finalizeEpoch(epochId, 1, 1000e18);
        // Don't set pool size (actualPoolSize = 0)

        vm.expectRevert(
            abi.encodeWithSelector(
                RewardErrors.EpochPoolSizeNotSet.selector,
                epochId
            )
        );
        rewardManager.calculateEpochRewards(epochId, 0, 10);

        vm.stopPrank();
    }

    // ============================================================================
    // TC_R10: Reward Claiming - All Rewards (UC25)
    // ============================================================================

    function test_TCR10_ClaimAllAvailableRewards() public {
        // Setup rewards for user
        vm.startPrank(user1);
        vault.stake(STAKE_AMOUNT, DAYS_LOCK);
        vm.stopPrank();

        vm.warp(block.timestamp + 10 days);

        vm.startPrank(admin);
        uint32 fromDay = uint32((block.timestamp - 10 days) / 1 days);
        uint32 toDay = uint32(block.timestamp / 1 days);
        rewardManager.calculateImmediateRewards(
            linearStrategyId,
            fromDay,
            toDay,
            0,
            10
        );
        vm.stopPrank();

        vm.startPrank(user1);

        uint256 claimableAmount = rewardManager.getClaimableRewards(user1);
        assertTrue(claimableAmount > 0, "Should have rewards to claim");

        uint256 balanceBefore = rewardToken.balanceOf(user1);

        // Claim all available rewards
        uint256 claimedAmount = rewardManager.claimAllRewards();

        // All unclaimed rewards should be identified and claimed
        assertEq(claimedAmount, claimableAmount);
        assertEq(rewardToken.balanceOf(user1), balanceBefore + claimedAmount);

        // Total amount should be calculated and tokens transferred
        uint256 remainingClaimable = rewardManager.getClaimableRewards(user1);
        assertEq(remainingClaimable, 0);

        // Rewards should be marked as claimed
        (, uint256 totalClaimed, ) = rewardManager.getUserRewardSummary(user1);
        assertEq(totalClaimed, claimedAmount);

        vm.stopPrank();
    }

    function test_TCR10_ClaimWhenNoRewardsAvailable() public {
        vm.startPrank(user1);

        // User has no unclaimed rewards
        uint256 claimableAmount = rewardManager.getClaimableRewards(user1);
        assertEq(claimableAmount, 0);

        vm.expectRevert(
            abi.encodeWithSelector(
                RewardErrors.NoRewardsToClaim.selector,
                user1
            )
        );
        rewardManager.claimAllRewards();

        vm.stopPrank();
    }

    // ============================================================================
    // TC_R11: Reward Claiming - Specific Rewards (UC25)
    // ============================================================================

    function test_TCR11_ClaimSpecificRewardIndices() public {
        // Setup multiple rewards for user
        vm.startPrank(user1);
        vault.stake(STAKE_AMOUNT, DAYS_LOCK);
        vm.stopPrank();

        // Create rewards from different time periods
        vm.warp(block.timestamp + 5 days);
        vm.startPrank(admin);
        uint32 fromDay1 = uint32((block.timestamp - 5 days) / 1 days);
        uint32 toDay1 = uint32(block.timestamp / 1 days);
        rewardManager.calculateImmediateRewards(
            linearStrategyId,
            fromDay1,
            toDay1,
            0,
            10
        );
        vm.stopPrank();

        vm.warp(block.timestamp + 5 days);
        vm.startPrank(admin);
        uint32 fromDay2 = uint32((block.timestamp - 5 days) / 1 days);
        uint32 toDay2 = uint32(block.timestamp / 1 days);
        rewardManager.calculateImmediateRewards(
            linearStrategyId,
            fromDay2,
            toDay2,
            0,
            10
        );
        vm.stopPrank();

        vm.startPrank(user1);

        // User should have multiple rewards
        GrantedRewardStorage.GrantedReward[]
            memory userRewards = grantedRewardStorage.getUserRewards(user1);
        assertTrue(userRewards.length >= 2, "Should have multiple rewards");

        // Claim specific reward indices
        uint256[] memory indicesToClaim = new uint256[](1);
        indicesToClaim[0] = 0; // Claim first reward only

        uint256 balanceBefore = rewardToken.balanceOf(user1);
        uint256 claimedAmount = rewardManager.claimSpecificRewards(
            indicesToClaim
        );

        // Only specified rewards should be claimed
        assertEq(claimedAmount, userRewards[0].amount);
        assertEq(rewardToken.balanceOf(user1), balanceBefore + claimedAmount);

        // Other rewards should remain unclaimed
        uint256 remainingClaimable = rewardManager.getClaimableRewards(user1);
        assertTrue(
            remainingClaimable > 0,
            "Should have remaining unclaimed rewards"
        );

        vm.stopPrank();
    }

    function test_TCR11_ClaimWithInvalidIndices() public {
        vm.startPrank(user1);

        uint256[] memory invalidIndices = new uint256[](1);
        invalidIndices[0] = 999; // Out of bounds

        vm.expectRevert(
            abi.encodeWithSelector(
                RewardErrors.InvalidRewardIndex.selector,
                999
            )
        );
        rewardManager.claimSpecificRewards(invalidIndices);

        vm.stopPrank();
    }

    // ============================================================================
    // TC_R12: Epoch-Specific Claiming (UC25)
    // ============================================================================

    function test_TCR12_ClaimRewardsFromSpecificEpoch() public {
        // Setup epoch rewards
        vm.startPrank(admin);
        uint32 currentDay = uint32(block.timestamp / 1 days);
        uint32 epochId = epochManager.announceEpoch(
            currentDay,
            currentDay + 30,
            epochStrategyId,
            1000000e18
        );
        epochManager.updateEpochStates();
        vm.stopPrank();

        vm.startPrank(user1);
        vault.stake(STAKE_AMOUNT, DAYS_LOCK);
        vm.stopPrank();

        // End epoch and calculate rewards
        vm.warp((currentDay + 31) * 1 days);
        vm.startPrank(admin);
        epochManager.updateEpochStates();
        // Set pool size BEFORE finalizing (since finalizeEpoch changes state to CALCULATED)
        epochManager.setEpochPoolSize(epochId, 500000e18);
        epochManager.finalizeEpoch(epochId, 1, STAKE_AMOUNT * 30);
        rewardManager.calculateEpochRewards(epochId, 0, 10);
        vm.stopPrank();

        // Also create some immediate rewards
        vm.startPrank(admin);
        uint32 fromDay = uint32((block.timestamp - 10 days) / 1 days);
        uint32 toDay = uint32(block.timestamp / 1 days);
        rewardManager.calculateImmediateRewards(
            linearStrategyId,
            fromDay,
            toDay,
            0,
            10
        );
        vm.stopPrank();

        vm.startPrank(user1);

        // User should have rewards from multiple sources
        uint256 totalClaimable = rewardManager.getClaimableRewards(user1);
        assertTrue(totalClaimable > 0, "Should have total rewards");

        uint256 balanceBefore = rewardToken.balanceOf(user1);

        // Claim rewards from specific epoch only
        uint256 epochClaimedAmount = rewardManager.claimEpochRewards(epochId);

        // Only rewards from specified epoch should be claimed
        assertTrue(epochClaimedAmount > 0, "Should have claimed epoch rewards");
        assertTrue(
            epochClaimedAmount < totalClaimable,
            "Should not claim all rewards"
        );
        assertEq(
            rewardToken.balanceOf(user1),
            balanceBefore + epochClaimedAmount
        );

        // Rewards from other epochs/strategies should remain unclaimed
        uint256 remainingClaimable = rewardManager.getClaimableRewards(user1);
        assertTrue(
            remainingClaimable > 0,
            "Should have remaining rewards from other sources"
        );

        vm.stopPrank();
    }

    function test_TCR12_ClaimFromEpochWithNoRewards() public {
        vm.startPrank(admin);
        uint32 currentDay = uint32(block.timestamp / 1 days);
        uint32 epochId = epochManager.announceEpoch(
            currentDay,
            currentDay + 30,
            epochStrategyId,
            1000000e18
        );
        vm.stopPrank();

        vm.startPrank(user1);

        // User has no rewards from specified epoch
        vm.expectRevert(
            abi.encodeWithSelector(
                RewardErrors.NoClaimableRewardsForEpoch.selector,
                epochId
            )
        );
        rewardManager.claimEpochRewards(epochId);

        vm.stopPrank();
    }

    // ============================================================================
    // TC_R18: Access Control - Reward System (UC21-UC26)
    // ============================================================================

    function test_TCR18_AdminFunctionsAccessControl() public {
        // Unauthorized user tries admin functions
        vm.startPrank(unauthorized);

        vm.expectRevert(); // AccessControl error
        rewardManager.calculateImmediateRewards(linearStrategyId, 1, 10, 0, 1);

        vm.expectRevert(); // AccessControl error
        rewardManager.calculateEpochRewards(1, 0, 1);

        vm.stopPrank();

        // Admin should succeed
        vm.startPrank(admin);

        // These should not revert (though they may fail for other reasons like no data)
        try
            rewardManager.calculateImmediateRewards(
                linearStrategyId,
                1,
                10,
                0,
                1
            )
        {} catch {
            // Expected to fail due to no stakes, but not access control
        }

        vm.stopPrank();
    }

    function test_TCR18_UserFunctionsPublicAccess() public view {
        // Any user should be able to call public query functions
        uint256 claimable1 = rewardManager.getClaimableRewards(user1);
        uint256 claimable2 = rewardManager.getClaimableRewards(user2);

        (
            uint256 totalGranted,
            uint256 totalClaimed,
            uint256 totalClaimable
        ) = rewardManager.getUserRewardSummary(user1);

        // No access control restrictions on these functions
        assertEq(claimable1, 0); // No rewards yet
        assertEq(claimable2, 0);
        assertEq(totalGranted, 0);
        assertEq(totalClaimed, 0);
        assertEq(totalClaimable, 0);
    }

    // ============================================================================
    // TC_R19: Emergency Controls (UC Security)
    // ============================================================================

    function test_TCR19_EmergencyPauseRewardSystem() public {
        vm.startPrank(admin);

        // Emergency pause reward system
        rewardManager.emergencyPause();
        assertTrue(rewardManager.paused());

        vm.stopPrank();

        vm.startPrank(user1);

        // Claiming should be blocked
        vm.expectRevert(); // Pausable error
        rewardManager.claimAllRewards();

        vm.stopPrank();

        vm.startPrank(admin);

        // Calculations should be blocked
        vm.expectRevert(); // Pausable error
        rewardManager.calculateImmediateRewards(linearStrategyId, 1, 10, 0, 1);

        vm.stopPrank();
    }

    function test_TCR19_ResumeFromEmergencyPause() public {
        vm.startPrank(admin);

        // Pause then resume
        rewardManager.emergencyPause();
        rewardManager.emergencyResume();
        assertFalse(rewardManager.paused());

        vm.stopPrank();

        // All functions should work again
        // Setup some rewards first
        vm.startPrank(user1);
        vault.stake(STAKE_AMOUNT, DAYS_LOCK);
        vm.stopPrank();

        vm.warp(block.timestamp + 5 days);

        vm.startPrank(admin);
        uint32 fromDay = uint32((block.timestamp - 5 days) / 1 days);
        uint32 toDay = uint32(block.timestamp / 1 days);

        // Should not revert
        rewardManager.calculateImmediateRewards(
            linearStrategyId,
            fromDay,
            toDay,
            0,
            10
        );
        vm.stopPrank();

        vm.startPrank(user1);
        // Should not revert
        rewardManager.claimAllRewards();
        vm.stopPrank();
    }

    // ============================================================================
    // Additional Helper Functions
    // ============================================================================

    function test_AddRewardFunds() public {
        uint256 additionalFunds = 500000e18;
        rewardToken.mint(user1, additionalFunds);

        vm.startPrank(user1);
        rewardToken.approve(address(rewardManager), additionalFunds);

        uint256 balanceBefore = rewardToken.balanceOf(address(rewardManager));
        rewardManager.addRewardFunds(additionalFunds);

        assertEq(
            rewardToken.balanceOf(address(rewardManager)),
            balanceBefore + additionalFunds
        );
        vm.stopPrank();
    }
}
